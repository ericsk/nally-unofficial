//
//  YLTelnet.swift
//  Nally
//
//  Created by Yung-Luen Lan on 2006/9/10.
//  Copyright 2006 yllan.org. All rights reserved.
//

import Cocoa
import Network

@objc(YLTelnet)
public class YLTelnet: YLConnection {
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "org.yllan.nally.telnet")
    private var readTask: Task<Void, Never>?
    
    private var port: Int = 0
    private var hostName: String = ""
    
    private var echoing: Bool = false
    private var editing: Bool = false
    private var activated: Bool = false
    private var synch: Bool = false

    private var typeOfOperation: UInt8 = 0
    private var sbOption: UInt8 = 0
    private var sbBuffer: NSMutableData?
    
    private enum TelnetState {
        case topLevel
        case seenIAC
        case seenWILL
        case seenWONT
        case seenDO
        case seenDONT
        case seenSB
        case subnegotiation
        case subnegotiationIAC
        case seenCR
    }
    private var state: TelnetState = .topLevel
    
    private let IAC: UInt8 = 255
    private let DONT: UInt8 = 254
    private let DO: UInt8 = 253
    private let WONT: UInt8 = 252
    private let WILL: UInt8 = 251
    private let SB: UInt8 = 250
    private let SE: UInt8 = 240
    private let DM: UInt8 = 242
    private let NUL: UInt8 = 0
    private let CR: UInt8 = 13

    private let TELOPT_BINARY: UInt8 = 0
    private let TELOPT_ECHO: UInt8 = 1
    private let TELOPT_SGA: UInt8 = 3
    private let TELOPT_TTYPE: UInt8 = 24
    private let TELOPT_NAWS: UInt8 = 31

    private let TELQUAL_IS: UInt8 = 0
    private let TELQUAL_SEND: UInt8 = 1

    deinit {
        close()
    }
    
    @objc public override func close() {
        NSLog("YLTelnet: close connection called")
        isProcessing = false
        readTask?.cancel()
        readTask = nil
        
        if let conn = connection {
            conn.stateUpdateHandler = nil
            conn.cancel()
        }
        connection = nil
        connected = false
        terminal?.closeConnection()
    }
    
    @objc public override func reconnect() {
        close()
        _ = connect(toAddress: hostName, port: UInt32(port))
    }
    
    @objc(connectToAddress:)
    public override func connect(toAddress addr: String) -> Bool {
        let parts = addr.components(separatedBy: CharacterSet(charactersIn: ": "))
        if parts.count == 2 {
            if let p = Int(parts[1]), p > 0 {
                return connect(toAddress: parts[0], port: UInt32(p))
            } else {
                return connect(toAddress: parts[0], port: 23)
            }
        } else if parts.count == 1 {
            return connect(toAddress: addr, port: 23)
        }
        return false
    }
    
    @objc(connectToAddress:port:)
    public override func connect(toAddress addr: String, port: UInt32) -> Bool {
        NSLog("YLTelnet: connectToAddress: \(addr) port: \(port)")
        isProcessing = true
        if port == 23 {
            connectionAddress = addr
        } else {
            connectionAddress = "\(addr):\(port)"
        }
        self.port = Int(port)
        self.hostName = addr
        
        self.terminal?.clearAll()
        
        let nwHost = NWEndpoint.Host(addr)
        let nwPort = NWEndpoint.Port(integerLiteral: UInt16(port))
        
        let conn = NWConnection(host: nwHost, port: nwPort, using: .tcp)
        self.connection = conn
        
        conn.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                NSLog("YLTelnet: NWConnection connected (ready)")
                DispatchQueue.main.async {
                    self.connected = true
                    self.isProcessing = false
                    self.terminal?.startConnection()
                }
                self.startReceiveStream()
            case .failed(let error):
                NSLog("YLTelnet: NWConnection failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.close()
                }
            case .cancelled:
                NSLog("YLTelnet: NWConnection cancelled")
                DispatchQueue.main.async {
                    self.close()
                }
            case .waiting(let error):
                NSLog("YLTelnet: NWConnection waiting: \(error.localizedDescription)")
            default:
                break
            }
        }
        
        conn.start(queue: queue)
        return true
    }
    
    private func startReceiveStream() {
        guard let conn = connection else { return }
        
        let dataStream = AsyncStream<Data> { continuation in
            func receiveNext() {
                conn.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, isComplete, error in
                    if let data = data, !data.isEmpty {
                        continuation.yield(data)
                    }
                    if isComplete || error != nil {
                        continuation.finish()
                    } else {
                        receiveNext()
                    }
                }
            }
            receiveNext()
            
            continuation.onTermination = { _ in
                conn.cancel()
            }
        }
        
        readTask = Task { [weak self] in
            for await chunk in dataStream {
                guard let self = self, !Task.isCancelled else { break }
                let count = chunk.count
                var mutableBytes = Array(chunk)
                await MainActor.run {
                    guard self.connection != nil else { return }
                    mutableBytes.withUnsafeMutableBufferPointer { bufferPtr in
                        if let mutableBase = bufferPtr.baseAddress {
                            self.receiveBytes(mutableBase, length: count)
                        }
                    }
                }
            }
            await MainActor.run { [weak self] in
                self?.close()
            }
        }
    }
    
    private func sendCommand(_ command: UInt8, option: UInt8) {
        let b: [UInt8] = [IAC, command, option]
        sendData(Data(b))
    }
    
    @objc(receiveBytes:length:)
    public override func receiveBytes(_ bytes: UnsafeMutablePointer<UInt8>, length: Int) {
        var terminalBuf = [UInt8]()
        
        for i in 0..<length {
            let c = bytes[i]
            switch state {
            case .topLevel, .seenCR:
                if c == NUL && state == .seenCR {
                    state = .topLevel
                } else if c == IAC {
                    state = .seenIAC
                } else {
                    if !synch {
                        terminalBuf.append(c)
                    } else if c == DM {
                        synch = false
                    }
                    
                    if c == CR {
                        state = .seenCR
                    } else {
                        state = .topLevel
                    }
                }
                
            case .seenIAC:
                if c == DO || c == DONT || c == WILL || c == WONT {
                    typeOfOperation = c
                    if c == DO { state = .seenDO }
                    else if c == DONT { state = .seenDONT }
                    else if c == WILL { state = .seenWILL }
                    else if c == WONT { state = .seenWONT }
                } else if c == SB {
                    state = .seenSB
                } else if c == DM {
                    synch = false
                    state = .topLevel
                } else {
                    state = .topLevel
                }
                
            case .seenWILL:
                if c == TELOPT_ECHO || c == TELOPT_SGA {
                    sendCommand(DO, option: c)
                } else if c == TELOPT_BINARY {
                    sendCommand(DO, option: c)
                } else {
                    sendCommand(DONT, option: c)
                }
                state = .topLevel
                
            case .seenWONT:
                sendCommand(DONT, option: c)
                state = .topLevel
                
            case .seenDO:
                if c == TELOPT_TTYPE {
                    sendCommand(WILL, option: TELOPT_TTYPE)
                } else if c == TELOPT_NAWS {
                    let b: [UInt8] = [IAC, SB, TELOPT_NAWS, 0, 80, 0, 24, IAC, SE]
                    sendCommand(WILL, option: TELOPT_NAWS)
                    sendData(Data(b))
                } else if c == TELOPT_BINARY {
                    sendCommand(WILL, option: c)
                } else {
                    sendCommand(WONT, option: c)
                }
                state = .topLevel
                
            case .seenDONT:
                sendCommand(WONT, option: c)
                state = .topLevel
                
            case .seenSB:
                sbOption = c
                sbBuffer = NSMutableData()
                state = .subnegotiation
                
            case .subnegotiation:
                if c == IAC {
                    state = .subnegotiationIAC
                } else {
                    var byte = c
                    sbBuffer?.append(&byte, length: 1)
                }
                
            case .subnegotiationIAC:
                if c != SE {
                    var byte = c
                    sbBuffer?.append(&byte, length: 1)
                    state = .subnegotiation
                } else {
                    if let buffer = sbBuffer, buffer.length > 0 {
                        let buf = buffer.bytes.assumingMemoryBound(to: UInt8.self)
                        if sbOption == TELOPT_TTYPE && buffer.length == 1 && buf[0] == TELQUAL_SEND {
                            let b: [UInt8] = [IAC, SB, TELOPT_TTYPE, TELQUAL_IS, UInt8(ascii: "v"), UInt8(ascii: "t"), UInt8(ascii: "1"), UInt8(ascii: "0"), UInt8(ascii: "0"), IAC, SE]
                            sendData(Data(b))
                        }
                    }
                    state = .topLevel
                    sbBuffer = nil
                }
            }
        }
        
        if !terminalBuf.isEmpty {
            terminalBuf.withUnsafeBufferPointer { bufferPtr in
                if let baseAddress = bufferPtr.baseAddress {
                    self.terminal?.feedBytes(baseAddress, length: Int32(terminalBuf.count), connection: self)
                }
            }
        }
    }
    
    @objc(sendBytes:length:)
    public override func sendBytes(_ msg: UnsafePointer<UInt8>, length: Int) {
        guard length > 0, let connection = connection else { return }
        lastTouchDateValue = Date()
        let data = Data(bytes: msg, count: length)
        connection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                NSLog("YLTelnet: NWConnection send error: \(error.localizedDescription)")
            }
        })
    }
    
    @objc(sendData:)
    public override func sendData(_ msg: Data) {
        guard let connection = connection else { return }
        lastTouchDateValue = Date()
        connection.send(content: msg, completion: .contentProcessed { error in
            if let error = error {
                NSLog("YLTelnet: NWConnection send error: \(error.localizedDescription)")
            }
        })
    }
}
