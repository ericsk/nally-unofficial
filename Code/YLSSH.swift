//
//  YLSSH.swift
//  Nally
//
//  Created by Lan Yung-Luen on 12/7/07.
//  Copyright 2007 yllan.org. All rights reserved.
//

import Cocoa

@objc(YLSSH)
public class YLSSH: YLConnection {
    private var pid: pid_t = 0
    private var fileDescriptor: Int32 = -1
    private var loginAsBBS: Bool = false
    private var usePacketMode: Bool = true
    
    deinit {
        close()
    }
    
    @objc public override func close() {
        NSLog("YLSSH: close called")
        if pid > 0 {
            kill(pid, SIGKILL)
        }
        if fileDescriptor >= 0 {
            Darwin.close(fileDescriptor)
        }
        fileDescriptor = -1
        pid = 0
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
                // Correct argv[0] to be "ssh" command name instead of executable path
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
            NSLog("YLSSH: ioctl(TIOCPKT) returned \(ioctlRet), errno: \(errno)")
            NSLog("YLSSH: TIOCPKT constant value in Swift: \(String(format: "0x%X", TIOCPKT))")
            if ioctlRet < 0 {
                usePacketMode = false
            } else {
                usePacketMode = true
            }
            
            Thread.detachNewThreadSelector(#selector(readLoop), toTarget: self, with: nil)
            self.connected = true
            return true
        } else {
            perror("forkpty failed")
            return false
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
        guard fileDescriptor >= 0, fileDescriptor < 1024 else { return }
        lastTouchDateValue = Date()
        
        var remaining = length
        var ptr = msg
        
        while remaining > 0 {
            var writeFileDescriptorSet = fd_set()
            var errorFileDescriptorSet = fd_set()
            
            let fd = fileDescriptor
            __darwin_fd_set(fd, &writeFileDescriptorSet)
            __darwin_fd_set(fd, &errorFileDescriptorSet)
            
            var timeout = timeval(tv_sec: 0, tv_usec: 100000)
            
            let result = select(fd + 1, nil, &writeFileDescriptorSet, &errorFileDescriptorSet, &timeout)
            
            if result == 0 {
                NSLog("timeout!")
                break
            } else if result < 0 {
                close()
                break
            }
            
            let chunkSize = min(remaining, 4096)
            let size = Darwin.write(fileDescriptor, ptr, chunkSize)
            if size <= 0 {
                close()
                break
            }
            
            ptr += size
            remaining -= size
        }
    }
    
    @objc(sendData:)
    public override func sendData(_ msg: Data) {
        msg.withUnsafeBytes { rawBuffer in
            if let baseAddress = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) {
                self.sendBytes(baseAddress, length: msg.count)
            }
        }
    }
    
    @objc private func readLoop() {
        NSLog("YLSSH: readLoop started")
        autoreleasepool {
            var exitLoop = false
            var buf = [UInt8](repeating: 0, count: 4096)
            var iterationCount = 0
            
            while !exitLoop {
                iterationCount += 1
                
                let fd = fileDescriptor
                guard fd >= 0 && fd < 1024 else { break }
                
                var readFileDescriptorSet = fd_set()
                var errorFileDescriptorSet = fd_set()
                
                __darwin_fd_set(fd, &readFileDescriptorSet)
                __darwin_fd_set(fd, &errorFileDescriptorSet)
                
                let result = select(fd + 1, &readFileDescriptorSet, nil, &errorFileDescriptorSet, nil)
                
                if result < 0 {
                    NSLog("YLSSH: select error: \(errno)")
                    break
                }
                
                let isErrorSet = __darwin_fd_isset(fd, &errorFileDescriptorSet) != 0
                let isReadSet = __darwin_fd_isset(fd, &readFileDescriptorSet) != 0
                
                if isErrorSet {
                    var c: UInt8 = 0
                    let readRes = Darwin.read(fd, &c, 1)
                    if readRes <= 0 {
                        exitLoop = true
                    }
                } else if isReadSet {
                    let readRes = Darwin.read(fd, &buf, buf.count)
                    if readRes > 0 {
                        if self.usePacketMode {
                            if readRes > 1 {
                                let data = Data(buf[1..<readRes])
                                DispatchQueue.main.async {
                                    self.receiveData(data)
                                }
                            }
                        } else {
                            let data = Data(buf[0..<readRes])
                            DispatchQueue.main.async {
                                self.receiveData(data)
                            }
                        }
                    }
                    if readRes <= 0 {
                        NSLog("YLSSH: read returned 0 or error, exiting loop")
                        exitLoop = true
                    }
                }
                
                if iterationCount % 5000 == 0 {
                    iterationCount = 1
                }
            }
            
            NSLog("YLSSH: readLoop exiting, closing connection")
            self.performSelector(onMainThread: #selector(close), with: nil, waitUntilDone: false)
        }
    }
}
