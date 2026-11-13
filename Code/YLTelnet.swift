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
    private var reusableReadBuffer = [UInt8]()
    
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
        readTask?.cancel()
        if let conn = connection {
            conn.stateUpdateHandler = nil
            conn.cancel()
        }
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
        guard !hostName.isEmpty, port > 0, port <= 65535 else { return }
        let savedHost = hostName
        let savedPort = UInt32(port)
        close()
        _ = connect(toAddress: savedHost, port: savedPort)
    }
    
    static func parseTelnetAddress(_ addr: String) -> (host: String, port: UInt32)? {
        var clean = addr.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        if clean.lowercased().hasPrefix("telnet://") {
            clean = String(clean.dropFirst(9))
        } else if clean.lowercased().hasPrefix("bbs://") {
            clean = String(clean.dropFirst(6))
        }
        if let slashIdx = clean.firstIndex(of: "/") {
            clean = String(clean[..<slashIdx])
        }
        guard !clean.isEmpty else { return nil }
        
        if clean.hasPrefix("[") {
            guard let closeIdx = clean.firstIndex(of: "]") else { return nil }
            let host = String(clean[clean.index(after: clean.startIndex)..<closeIdx])
            guard !host.isEmpty else { return nil }
            let remainder = clean[clean.index(after: closeIdx)...].trimmingCharacters(in: .whitespaces)
            if remainder.isEmpty {
                return (host, 23)
            } else if remainder.hasPrefix(":") {
                let portStr = String(remainder.dropFirst())
                if portStr.isEmpty { return (host, 23) }
                guard let p = UInt16(portStr), p > 0 else { return nil }
                return (host, UInt32(p))
            } else if let p = UInt16(remainder), p > 0 {
                return (host, UInt32(p))
            }
            return nil
        }
        
        if clean.contains(" ") {
            let spaceParts = clean.split(separator: " ", omittingEmptySubsequences: true)
            guard spaceParts.count == 2 else { return nil }
            let host = String(spaceParts[0])
            guard !host.isEmpty, let p = UInt16(spaceParts[1]), p > 0 else { return nil }
            return (host, UInt32(p))
        }
        
        let colonParts = clean.components(separatedBy: ":")
        if colonParts.count == 1 {
            return (clean, 23)
        } else if colonParts.count == 2 {
            let host = colonParts[0]
            guard !host.isEmpty else { return nil }
            if colonParts[1].isEmpty {
                return (host, 23)
            }
            guard let p = UInt16(colonParts[1]), p > 0 else { return nil }
            return (host, UInt32(p))
        } else {
            // Unbracketed IPv6 address (e.g. 2001:db8::1)
            return (clean, 23)
        }
    }
    
    @objc(connectToAddress:)
    public override func connect(toAddress addr: String) -> Bool {
        guard let parsed = Self.parseTelnetAddress(addr) else {
            return false
        }
        return connect(toAddress: parsed.host, port: parsed.port)
    }
    
    @objc(connectToAddress:port:)
    public override func connect(toAddress addr: String, port: UInt32) -> Bool {
        NSLog("YLTelnet: connectToAddress: \(addr) port: \(port)")
        let trimmedHost = addr.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHost.isEmpty,
              let validPort = UInt16(exactly: port),
              validPort > 0,
              let nwPort = NWEndpoint.Port(rawValue: validPort) else {
            isProcessing = false
            return false
        }
        
        isProcessing = true
        let displayHost = trimmedHost.contains(":") ? "[\(trimmedHost)]" : trimmedHost
        if validPort == 23 {
            connectionAddress = displayHost
        } else {
            connectionAddress = "\(displayHost):\(validPort)"
        }
        self.port = Int(validPort)
        self.hostName = trimmedHost
        
        self.terminal?.clearAll()
        
        let nwHost = NWEndpoint.Host(trimmedHost)
        
        let conn = NWConnection(host: nwHost, port: nwPort, using: .tcp)
        self.connection = conn
        
        conn.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                NSLog("YLTelnet: NWConnection connected (ready)")
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.connected = true
                    self.isProcessing = false
                    self.terminal?.startConnection()
                    self.startReceiveStream()
                }
            case .failed(let error):
                NSLog("YLTelnet: NWConnection failed: \(error.localizedDescription)")
                Task { @MainActor [weak self] in
                    self?.close()
                }
            case .cancelled:
                NSLog("YLTelnet: NWConnection cancelled")
                Task { @MainActor [weak self] in
                    self?.close()
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
            @Sendable func receiveNext() {
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
    public override func receiveBytes(_ bytes: UnsafePointer<UInt8>, length: Int) {
        reusableReadBuffer.removeAll(keepingCapacity: true)
        reusableReadBuffer.reserveCapacity(length)
        
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
                        reusableReadBuffer.append(c)
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
        
        if !reusableReadBuffer.isEmpty {
            reusableReadBuffer.withUnsafeBufferPointer { bufferPtr in
                if let baseAddress = bufferPtr.baseAddress {
                    self.terminal?.feedBytes(baseAddress, length: Int32(reusableReadBuffer.count), connection: self)
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
