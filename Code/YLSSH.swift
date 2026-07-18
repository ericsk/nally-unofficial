//
//  YLSSH.swift
//  Nally
//
//  Created by Lan Yung-Luen on 12/7/07.
//  Copyright 2007-2026 yllan.org. All rights reserved.
//

import Cocoa
import Combine

@objc(YLSSH)
public class YLSSH: YLConnection {
    private var pid: pid_t = 0
    private var fileDescriptor: Int32 = -1
    private var loginAsBBS: Bool = false
    private var usePacketMode: Bool = true
    
    // Modern Dispatch Queue and Source
    private let queue = DispatchQueue(label: "org.yllan.nally.ssh")
    private var readSource: DispatchSourceRead?
    
    deinit {
        close()
    }
    
    @objc public override func close() {
        NSLog("YLSSH: close called")
        
        if let source = readSource {
            source.cancel()
            readSource = nil
        }
        
        if pid > 0 {
            kill(pid, SIGKILL)
            var status: Int32 = 0
            waitpid(pid, &status, WNOHANG)
            pid = 0
        }
        
        if fileDescriptor >= 0 {
            Darwin.close(fileDescriptor)
            fileDescriptor = -1
        }
        connected = false
    }
    
    @objc public override func reconnect() {
        close()
        if let address = connectionAddress {
            self.perform(#selector(connectToAddressBridge(_:)), with: address, afterDelay: 0.01)
        }
    }
    
    @objc private func connectToAddressBridge(_ addr: String) {
        let _ = connect(toAddress: addr)
    }
    
    @objc(connectToAddress:)
    public override func connect(toAddress addr: String) -> Bool {
        var cleanAddr = addr
        if cleanAddr.hasPrefix("ssh://bbs") {
            cleanAddr = String(cleanAddr.dropFirst(6)) // Keeps "bbs@..."
            loginAsBBS = true
        } else if cleanAddr.hasPrefix("ssh://") {
            cleanAddr = String(cleanAddr.dropFirst(6))
            loginAsBBS = false
        }
        
        let parts = cleanAddr.components(separatedBy: ":")
        if parts.count == 2 {
            if let p = UInt32(parts[1]), p > 0 {
                return connect(toAddress: parts[0], port: p)
            } else {
                return connect(toAddress: parts[0], port: 22)
            }
        } else if parts.count == 1 {
            return connect(toAddress: cleanAddr, port: 22)
        }
        return false
    }
    
    @objc(connectToAddress:port:)
    public override func connect(toAddress addr: String, port: UInt32) -> Bool {
        NSLog("YLSSH: connectToAddress: \(addr) port: \(port)")
        terminal?.clearAll()
        
        var slaveName = [CChar](repeating: 0, count: Int(PATH_MAX))
        var term = termios()
        var size = winsize()
        
        term.c_iflag = tcflag_t(ICRNL | IXON | IXANY | IMAXBEL | BRKINT)
        term.c_oflag = tcflag_t(OPOST | ONLCR)
        term.c_cflag = tcflag_t(CREAD | CS8 | HUPCL)
        term.c_lflag = tcflag_t(ICANON | ISIG | IEXTEN | ECHO | ECHOE | ECHOK | ECHOKE | ECHOCTL)
        
        let ctrlKey = { (c: Unicode.Scalar) -> Int32 in
            return Int32(c.value) - Int32(Unicode.Scalar("A").value) + 1
        }
        
        // Setup term.c_cc controls
        withUnsafeMutableBytes(of: &term.c_cc) { bytes in
            guard let cc = bytes.baseAddress?.assumingMemoryBound(to: cc_t.self) else { return }
            cc[Int(VEOF)] = cc_t(ctrlKey("D"))
            cc[Int(VEOL)] = cc_t(exactly: -1) ?? 255
            cc[Int(VEOL2)] = cc_t(exactly: -1) ?? 255
            cc[Int(VERASE)] = 0x7f
            cc[Int(VWERASE)] = cc_t(ctrlKey("W"))
            cc[Int(VKILL)] = cc_t(ctrlKey("U"))
            cc[Int(VREPRINT)] = cc_t(ctrlKey("R"))
            cc[Int(VINTR)] = cc_t(ctrlKey("C"))
            cc[Int(VQUIT)] = 0x1c
            cc[Int(VSUSP)] = cc_t(ctrlKey("Z"))
            cc[Int(VDSUSP)] = cc_t(ctrlKey("Y"))
            cc[Int(VSTART)] = cc_t(ctrlKey("Q"))
            cc[Int(VSTOP)] = cc_t(ctrlKey("S"))
            cc[Int(VLNEXT)] = cc_t(exactly: -1) ?? 255
            cc[Int(VDISCARD)] = cc_t(exactly: -1) ?? 255
            cc[Int(VMIN)] = 1
            cc[Int(VTIME)] = 0
            cc[Int(VSTATUS)] = cc_t(exactly: -1) ?? 255
        }
        
        term.c_ispeed = speed_t(B38400)
        term.c_ospeed = speed_t(B38400)
        
        let config = YLLGlobalConfig.sharedInstance()
        size.ws_col = UInt16(config.column)
        size.ws_row = UInt16(config.row)
        size.ws_xpixel = 0
        size.ws_ypixel = 0
        
        var fd: Int32 = -1
        NSLog("YLSSH: calling forkpty")
        let forkPid = forkpty(&fd, &slaveName, &term, &size)
        
        if forkPid == 0 { // Child
            let portStr = String(port)
            if loginAsBBS {
                let args = ["ssh", "-e", "none", "-x", "-p", portStr, addr]
                let cArgs = args.map { strdup($0) } + [nil]
                cArgs.withUnsafeBufferPointer { bufferPtr in
                    execvp("/usr/bin/ssh", bufferPtr.baseAddress!)
                }
                perror("fork error")
                exit(1)
            } else {
                let args = ["ssh", "-e", "none", "-p", portStr, addr]
                let env = ["TERM=vt102"]
                let cArgs = args.map { strdup($0) } + [nil]
                let cEnv = env.map { strdup($0) } + [nil]
                cArgs.withUnsafeBufferPointer { argsPtr in
                    cEnv.withUnsafeBufferPointer { envPtr in
                        execve("/usr/bin/ssh", argsPtr.baseAddress!, envPtr.baseAddress!)
                    }
                }
                perror("fork error")
                exit(1)
            }
        } else if forkPid > 0 { // Parent
            self.pid = forkPid
            self.fileDescriptor = fd
            NSLog("YLSSH: forkpty succeeded, pid: \(pid), fd: \(fileDescriptor)")
            
            var one: Int32 = 1
            let ioctlRet = ioctl(self.fileDescriptor, UInt(TIOCPKT), &one)
            if ioctlRet < 0 {
                usePacketMode = false
            } else {
                usePacketMode = true
            }
            
            // Set fd to non-blocking
            let flags = fcntl(self.fileDescriptor, F_GETFL, 0)
            _ = fcntl(self.fileDescriptor, F_SETFL, flags | O_NONBLOCK)
            
            // Setup DispatchSourceRead
            let source = DispatchSource.makeReadSource(fileDescriptor: self.fileDescriptor, queue: queue)
            source.setEventHandler { [weak self] in
                self?.handleRead()
            }
            source.setCancelHandler { [weak self] in
                guard let self = self else { return }
                if self.fileDescriptor >= 0 {
                    Darwin.close(self.fileDescriptor)
                    self.fileDescriptor = -1
                }
            }
            self.readSource = source
            source.resume()
            
            self.connected = true
            return true
        } else {
            perror("forkpty failed")
            return false
        }
    }
    
    private func handleRead() {
        guard fileDescriptor >= 0 else { return }
        var buf = [UInt8](repeating: 0, count: 4096)
        let readRes = Darwin.read(fileDescriptor, &buf, buf.count)
        
        if readRes > 0 {
            let data: Data
            if usePacketMode {
                if readRes > 1 {
                    data = Data(buf[1..<readRes])
                } else {
                    return
                }
            } else {
                data = Data(buf[0..<readRes])
            }
            DispatchQueue.main.async { [weak self] in
                self?.receiveData(data)
            }
        } else if readRes < 0 {
            let err = errno
            if err == EAGAIN || err == EWOULDBLOCK {
                return
            }
            NSLog("YLSSH: read error: \(err), closing")
            DispatchQueue.main.async { [weak self] in
                self?.close()
            }
        } else {
            NSLog("YLSSH: read returned 0 (EOF), closing")
            DispatchQueue.main.async { [weak self] in
                self?.close()
            }
        }
    }
    
    @objc private func receiveData(_ data: Data) {
        data.withUnsafeBytes { rawBuffer in
            if let baseAddress = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) {
                self.terminal?.feedBytes(baseAddress, length: Int32(data.count), connection: self)
            }
        }
    }
    
    @objc(receiveBytes:length:)
    public override func receiveBytes(_ bytes: UnsafeMutablePointer<UInt8>, length: Int) {
        terminal?.feedBytes(bytes, length: Int32(length), connection: self)
    }
    
    @objc(sendBytes:length:)
    public override func sendBytes(_ msg: UnsafePointer<UInt8>, length: Int) {
        guard fileDescriptor >= 0, length > 0 else { return }
        lastTouchDateValue = Date()
        
        let data = Data(bytes: msg, count: length)
        queue.async { [weak self] in
            self?.writeAsync(data)
        }
    }
    
    private func writeAsync(_ data: Data) {
        guard fileDescriptor >= 0 else { return }
        var remaining = data.count
        var offset = 0
        
        data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            
            while remaining > 0 {
                let chunkPtr = baseAddress + offset
                let size = Darwin.write(fileDescriptor, chunkPtr, remaining)
                
                if size > 0 {
                    offset += size
                    remaining -= size
                } else if size < 0 {
                    let err = errno
                    if err == EAGAIN || err == EWOULDBLOCK {
                        usleep(10000) // 10ms
                        continue
                    } else {
                        NSLog("YLSSH: write error: \(err), closing")
                        DispatchQueue.main.async { [weak self] in
                            self?.close()
                        }
                        break
                    }
                } else {
                    NSLog("YLSSH: write returned 0, closing")
                    DispatchQueue.main.async { [weak self] in
                        self?.close()
                    }
                    break
                }
            }
        }
    }
    
    @objc(sendData:)
    public override func sendData(_ msg: Data) {
        guard fileDescriptor >= 0, !msg.isEmpty else { return }
        lastTouchDateValue = Date()
        queue.async { [weak self] in
            self?.writeAsync(msg)
        }
    }
}
