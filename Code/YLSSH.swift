import Cocoa
import Combine

@objc(YLSSH)
public class YLSSH: YLConnection {
    private var process: Process?
    private var masterFd: Int32 = -1
    private var loginAsBBS: Bool = false
    private var usePacketMode: Bool = true
    private var ioTask: Task<Void, Never>?
    
    deinit {
        close()
    }
    
    @objc public override func close() {
        NSLog("YLSSH: close called")
        
        if let task = ioTask {
            task.cancel()
            ioTask = nil
        }
        
        if let proc = process {
            if proc.isRunning {
                proc.terminate()
            }
            process = nil
        }
        
        if masterFd >= 0 {
            Darwin.close(masterFd)
            masterFd = -1
        }
        
        connected = false
    }
    
    @objc public override func reconnect() {
        close()
        if let address = connectionAddress {
            DispatchQueue.main.async { [weak self] in
                _ = self?.connect(toAddress: address)
            }
        }
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
        
        // 1. Open master PTY
        let fd = posix_openpt(O_RDWR | O_NOCTTY)
        guard fd >= 0 else {
            NSLog("YLSSH: posix_openpt failed")
            return false
        }
        
        guard grantpt(fd) == 0 else {
            NSLog("YLSSH: grantpt failed")
            Darwin.close(fd)
            return false
        }
        
        guard unlockpt(fd) == 0 else {
            NSLog("YLSSH: unlockpt failed")
            Darwin.close(fd)
            return false
        }
        
        guard let slavePathC = ptsname(fd) else {
            NSLog("YLSSH: ptsname failed")
            Darwin.close(fd)
            return false
        }
        
        let slavePath = String(cString: slavePathC)
        let slaveFd = Darwin.open(slavePath, O_RDWR | O_NOCTTY)
        guard slaveFd >= 0 else {
            NSLog("YLSSH: failed to open slave PTY at \(slavePath)")
            Darwin.close(fd)
            return false
        }
        
        // 2. Set slave PTY terminal settings
        var term = termios()
        tcgetattr(slaveFd, &term)
        
        term.c_iflag = tcflag_t(ICRNL | IXON | IXANY | IMAXBEL | BRKINT)
        term.c_oflag = tcflag_t(OPOST | ONLCR)
        term.c_cflag = tcflag_t(CREAD | CS8 | HUPCL)
        term.c_lflag = tcflag_t(ICANON | ISIG | IEXTEN | ECHO | ECHOE | ECHOK | ECHOKE | ECHOCTL)
        
        let ctrlKey = { (c: Unicode.Scalar) -> Int32 in
            return Int32(c.value) - Int32(Unicode.Scalar("A").value) + 1
        }
        
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
        tcsetattr(slaveFd, TCSANOW, &term)
        
        var size = winsize()
        let config = YLLGlobalConfig.sharedInstance()
        size.ws_col = UInt16(config.column)
        size.ws_row = UInt16(config.row)
        size.ws_xpixel = 0
        size.ws_ypixel = 0
        ioctl(slaveFd, TIOCSWINSZ, &size)
        
        // 3. Enable Packet Mode
        var one: Int32 = 1
        let ioctlRet = ioctl(fd, UInt(TIOCPKT), &one)
        if ioctlRet < 0 {
            usePacketMode = false
        } else {
            usePacketMode = true
        }
        
        // 4. Spawn ssh Process
        let slaveHandle = FileHandle(fileDescriptor: slaveFd, closeOnDealloc: false)
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        
        let portStr = String(port)
        if loginAsBBS {
            proc.arguments = ["-e", "none", "-x", "-p", portStr, addr]
        } else {
            proc.arguments = ["-e", "none", "-p", portStr, addr]
        }
        
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "vt102"
        proc.environment = env
        
        proc.standardInput = slaveHandle
        proc.standardOutput = slaveHandle
        proc.standardError = slaveHandle
        
        do {
            try proc.run()
        } catch {
            NSLog("YLSSH: failed to run ssh: \(error.localizedDescription)")
            Darwin.close(fd)
            return false
        }
        
        // Close slaveFd in parent
        Darwin.close(slaveFd)
        
        self.masterFd = fd
        self.process = proc
        
        // Set masterFd to non-blocking
        let flags = fcntl(fd, F_GETFL, 0)
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)
        
        // 5. Read loop using Swift Concurrency and AsyncStream
        let packetMode = usePacketMode
        let dataStream = AsyncStream<Data> { continuation in
            let readQueue = DispatchQueue(label: "org.yllan.nally.ssh.read")
            let readSource = DispatchSource.makeReadSource(fileDescriptor: fd, queue: readQueue)
            readSource.setEventHandler {
                var buf = [UInt8](repeating: 0, count: 4096)
                let readRes = Darwin.read(fd, &buf, buf.count)
                if readRes > 0 {
                    let data: Data
                    if packetMode {
                        if readRes > 1 {
                            if buf[0] == 0 { // TIOCPKT_DATA
                                data = Data(buf[1..<readRes])
                                continuation.yield(data)
                            }
                        }
                    } else {
                        data = Data(buf[0..<readRes])
                        continuation.yield(data)
                    }
                } else if readRes == 0 {
                    readSource.cancel()
                } else {
                    let err = errno
                    if err != EAGAIN && err != EWOULDBLOCK {
                        readSource.cancel()
                    }
                }
            }
            
            readSource.setCancelHandler {
                continuation.finish()
            }
            
            readSource.resume()
            
            continuation.onTermination = { @Sendable _ in
                readSource.cancel()
            }
        }
        
        ioTask = Task { [weak self] in
            for await data in dataStream {
                guard let self = self else { break }
                await MainActor.run {
                    self.receiveData(data)
                }
            }
            // Reading completed (EOF or cancelled)
            await MainActor.run {
                self?.close()
            }
        }
        
        self.connected = true
        return true
    }
    
    @objc private func receiveData(_ data: Data) {
        data.withUnsafeBytes { rawBuffer in
            if let baseAddress = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) {
                self.terminal?.feedBytes(baseAddress, length: Int32(data.count), connection: self)
            }
        }
    }
    
    @objc(receiveBytes:length:)
    public override func receiveBytes(_ bytes: UnsafePointer<UInt8>, length: Int) {
        terminal?.feedBytes(bytes, length: Int32(length), connection: self)
    }
    
    @objc(sendBytes:length:)
    public override func sendBytes(_ msg: UnsafePointer<UInt8>, length: Int) {
        guard masterFd >= 0, length > 0 else { return }
        lastTouchDateValue = Date()
        
        let data = Data(bytes: msg, count: length)
        Task {
            await writeAsync(data)
        }
    }
    
    private func writeAsync(_ data: Data) async {
        guard masterFd >= 0 else { return }
        var remaining = data.count
        var offset = 0
        
        while remaining > 0 && masterFd >= 0 {
            let written = data.withUnsafeBytes { rawBuffer -> Int in
                guard let baseAddress = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return -1 }
                let chunkPtr = baseAddress + offset
                return Darwin.write(masterFd, chunkPtr, remaining)
            }
            
            if written > 0 {
                offset += written
                remaining -= written
            } else if written < 0 {
                let err = errno
                if err == EAGAIN || err == EWOULDBLOCK {
                    // Yield thread control
                    await Task.yield()
                    continue
                } else {
                    NSLog("YLSSH: write error: \(err), closing")
                    Task { @MainActor in
                        self.close()
                    }
                    break
                }
            } else {
                NSLog("YLSSH: write returned 0, closing")
                Task { @MainActor in
                    self.close()
                }
                break
            }
        }
    }
    
    @objc(sendData:)
    public override func sendData(_ msg: Data) {
        guard masterFd >= 0, !msg.isEmpty else { return }
        lastTouchDateValue = Date()
        Task {
            await writeAsync(msg)
        }
    }
}
