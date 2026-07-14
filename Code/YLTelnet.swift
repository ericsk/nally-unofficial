//
//  YLTelnet.swift
//  Nally
//
//  Created by Yung-Luen Lan on 2006/9/10.
//  Copyright 2006 yllan.org. All rights reserved.
//

import Cocoa

@objc(YLTelnet)
public class YLTelnet: YLConnection, StreamDelegate {
    private var host: Host?
    private var port: Int = 0
    private var inputStream: InputStream?
    private var outputStream: OutputStream?
    
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
        if let inputStream = inputStream {
            inputStream.close()
            inputStream.remove(from: .main, forMode: .default)
        }
        inputStream = nil
        if let outputStream = outputStream {
            outputStream.close()
            outputStream.remove(from: .main, forMode: .default)
        }
        outputStream = nil
        connected = false
        terminal?.closeConnection()
    }
    
    @objc public override func reconnect() {
        if let host = host {
            close()
            let dict: NSDictionary = ["host": host, "port": port]
            connectWithDictionary(dict)
        }
    }
    
    @objc private func lookUpDomainName(_ dict: NSDictionary) {
        autoreleasepool {
            guard let addr = dict["addr"] as? String,
                  let port = dict["port"] as? Int else { return }
            
            NSLog("YLTelnet: lookUpDomainName: resolving \(addr)")
            let host = Host(name: addr)
            if host.address != nil {
                NSLog("YLTelnet: lookUpDomainName: resolved \(addr) to \(host.address ?? "nil")")
                let resultDict: NSDictionary = ["host": host, "port": port, "addr": addr]
                self.performSelector(onMainThread: #selector(connectWithDictionary(_:)), with: resultDict, waitUntilDone: false)
            } else {
                NSLog("YLTelnet: lookUpDomainName: failed to resolve \(addr)")
                DispatchQueue.main.async {
                    self.isProcessing = false
                }
            }
        }
    }
    
    @objc private func connectWithDictionary(_ dict: NSDictionary) {
        guard let host = dict["host"] as? Host,
              let port = dict["port"] as? Int,
              let addr = dict["addr"] as? String else { return }
        
        self.host = host
        self.terminal?.clearAll()
        
        var inStream: InputStream?
        var outStream: OutputStream?
        
        // Pass original hostname string 'addr' to let OS handle Happy Eyeballs DNS resolution
        NSLog("YLTelnet: connectWithDictionary: getStreamsToHost with name: \(addr) port: \(port)")
        Stream.getStreamsToHost(withName: addr, port: port, inputStream: &inStream, outputStream: &outStream)
        
        self.inputStream = inStream
        self.outputStream = outStream
        
        if let inputStream = self.inputStream, let outputStream = self.outputStream {
            inputStream.delegate = self
            outputStream.delegate = self
            inputStream.schedule(in: .main, forMode: .default)
            outputStream.schedule(in: .main, forMode: .default)
            inputStream.open()
            outputStream.open()
            NSLog("YLTelnet: connectWithDictionary: streams opened")
        } else {
            NSLog("YLTelnet: connectWithDictionary: failed to get streams")
        }
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
        
        let dict: NSDictionary = ["addr": addr, "port": Int(port)]
        self.performSelector(inBackground: #selector(lookUpDomainName(_:)), with: dict)
        return true
    }
    
    @objc(stream:handleEvent:)
    public func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        let streamName = aStream === inputStream ? "InputStream" : "OutputStream"
        switch eventCode {
        case .openCompleted:
            NSLog("YLTelnet: stream \(streamName) openCompleted")
            connected = true
            isProcessing = false
            terminal?.startConnection()
            
        case .hasBytesAvailable:
            if let inputStream = aStream as? InputStream {
                var buf = [UInt8](repeating: 0, count: 4096)
                while inputStream.hasBytesAvailable {
                    let len = inputStream.read(&buf, maxLength: 4096)
                    if len > 0 {
                        buf.withUnsafeMutableBufferPointer { bufferPtr in
                            if let baseAddress = bufferPtr.baseAddress {
                                self.receiveBytes(baseAddress, length: len)
                            }
                        }
                    }
                }
            }
            
        case .hasSpaceAvailable:
            break
            
        case .errorOccurred:
            let err = aStream.streamError?.localizedDescription ?? "unknown error"
            NSLog("YLTelnet: stream \(streamName) errorOccurred: \(err)")
            isProcessing = false
            close()
            
        case .endEncountered:
            NSLog("YLTelnet: stream \(streamName) endEncountered")
            isProcessing = false
            close()
            
        default:
            break
        }
    }
    
    private func sendCommand(_ command: UInt8, option: UInt8) {
        let b: [UInt8] = [IAC, command, option]
        let data = Data(b) as NSData
        self.perform(#selector(sendData(_:)), with: data, afterDelay: 0.001)
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
                    self.perform(#selector(sendData(_:)), with: Data(b) as NSData, afterDelay: 0.001)
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
                            self.perform(#selector(sendData(_:)), with: Data(b) as NSData, afterDelay: 0.001)
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
        guard length > 0, let outputStream = outputStream else { return }
        lastTouchDateValue = Date()
        
        let status = outputStream.streamStatus
        if status == .notOpen || status == .error || status == .closed || status == .atEnd {
            return
        }
        
        let result = outputStream.write(msg, maxLength: length)
        if result == length { return }
        if result <= 0 {
            let data = Data(bytes: msg, count: length) as NSData
            self.perform(#selector(sendData(_:)), with: data, afterDelay: 0.001)
        } else {
            let data = Data(bytes: msg + result, count: length - result) as NSData
            self.perform(#selector(sendData(_:)), with: data, afterDelay: 0.001)
        }
    }
    
    @objc(sendData:)
    public override func sendData(_ msg: Data) {
        guard outputStream != nil else { return }
        msg.withUnsafeBytes { rawBuffer in
            if let baseAddress = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) {
                self.sendBytes(baseAddress, length: msg.count)
            }
        }
    }
}
