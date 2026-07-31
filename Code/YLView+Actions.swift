import Cocoa
import CoreText

extension YLView {
    // MARK: - Actions (Copy, Paste, Select)
    @IBAction public func copy(_ sender: Any?) {
        guard connected() else { return }
        if _selectionLength == 0 { return }
        
        let config = YLLGlobalConfig.sharedInstance()
        let gColumn = Int(config.column)
        
        let s = selectedPlainString()
        
        var location: Int
        var length: Int
        if _selectionLength >= 0 {
            location = Int(_selectionLocation)
            length = Int(_selectionLength)
        } else {
            location = Int(_selectionLocation + _selectionLength)
            length = 0 - Int(_selectionLength)
        }
        
        var buffer = [cell]()
        guard let ds = frontMostTerminal() else { return }
        var emptyCount = 0
        
        for i in 0..<length {
            let index = location + i
            guard let currentRow = ds.cells(ofRow: Int32(index / gColumn)) else { continue }
            
            if (index % gColumn == 0) && (index != location) {
                var cCell = cell()
                cCell.byte = UInt8(ascii: "\n")
                if !buffer.isEmpty {
                    cCell.attr = buffer[buffer.count - 1].attr
                } else {
                    cCell.attr = attribute(v: 0)
                }
                buffer.append(cCell)
                emptyCount = 0
            }
            
            let colIndex = index % gColumn
            if currentRow[colIndex].byte != 0 {
                for _ in 0..<emptyCount {
                    var spaceCell = currentRow[colIndex]
                    spaceCell.byte = UInt8(ascii: " ")
                    var termAttr = spaceCell.attr.terminalAttribute
                    termAttr.doubleByte = 0
                    termAttr.url = false
                    spaceCell.attr = attribute(termAttr)
                    buffer.append(spaceCell)
                }
                
                var charCell = currentRow[colIndex]
                var termAttr = charCell.attr.terminalAttribute
                termAttr.doubleByte = 0
                termAttr.url = false
                charCell.attr = attribute(termAttr)
                buffer.append(charCell)
                emptyCount = 0
            } else {
                emptyCount += 1
            }
        }
        
        let pb = NSPasteboard.general
        let pbTypes = [NSPasteboard.PasteboardType.string, YLView.ANSIColorPBoardType]
        pb.declareTypes(pbTypes, owner: self)
        if let s = s {
            pb.setString(s, forType: .string)
        } else {
            pb.setString("", forType: .string)
        }
        
        let rawData = buffer.withUnsafeBufferPointer { bufPtr in
            Data(bytes: bufPtr.baseAddress!, count: bufPtr.count * MemoryLayout<cell>.size)
        }
        pb.setData(rawData, forType: YLView.ANSIColorPBoardType)
    }
    
    @IBAction public func pasteColor(_ sender: Any?) {
        guard connected() else { return }
        let pb = NSPasteboard.general
        guard let types = pb.types, types.contains(YLView.ANSIColorPBoardType) else {
            paste(sender)
            return
        }
        
        guard let data = pb.data(forType: YLView.ANSIColorPBoardType) else { return }
        let cellCount = data.count / MemoryLayout<cell>.size
        guard cellCount > 0 else { return }
        
        var escBytes = Data()
        if let s = frontMostConnection()?.site {
            switch s.ansiColorKey {
            case .YLCtrlUANSIColorKey:
                escBytes.append(0x15)
            case .YLEscEscEscANSIColorKey:
                escBytes.append(contentsOf: [0x1B, 0x1B])
            @unknown default:
                escBytes.append(0x1B)
            }
        } else {
            escBytes.append(0x1B)
        }
        
        let config = YLLGlobalConfig.sharedInstance()
        let defaultANSI = TerminalAttribute(
            fgColor: Int(config.fgColorIndex),
            bgColor: Int(config.bgColorIndex),
            bold: false,
            underline: false,
            blink: false,
            reverse: false,
            doubleByte: 0,
            url: false
        )
        
        var previousANSI = defaultANSI
        var writeBuffer = Data()
        
        data.withUnsafeBytes { rawBuffer in
            let cells = rawBuffer.bindMemory(to: cell.self)
            
            for i in 0..<cellCount {
                let cellItem = cells[i]
                if cellItem.byte == UInt8(ascii: "\n") {
                    previousANSI = defaultANSI
                    writeBuffer.append(escBytes)
                    writeBuffer.append(contentsOf: "[m\r".utf8)
                    continue
                }
                
                let currentANSI = cellItem.attr.terminalAttribute
                
                if currentANSI.blink == previousANSI.blink &&
                    currentANSI.bold == previousANSI.bold &&
                    currentANSI.underline == previousANSI.underline &&
                    currentANSI.reverse == previousANSI.reverse &&
                    currentANSI.bgColor == previousANSI.bgColor &&
                    currentANSI.fgColor == previousANSI.fgColor {
                    writeBuffer.append(cellItem.byte)
                    continue
                }
                
                var tmp = ""
                // Clear / Reset
                if (currentANSI.blink == false && previousANSI.blink == true) ||
                    (currentANSI.bold == false && previousANSI.bold == true) ||
                    (currentANSI.underline == false && previousANSI.underline == true) ||
                    (currentANSI.reverse == false && previousANSI.reverse == true) ||
                    (currentANSI.bgColor == Int(config.bgColorIndex) && (previousANSI.reverse ? 1 : 0) != Int(config.bgColorIndex)) {
                    
                    tmp += "[0"
                    if currentANSI.blink { tmp += ";5" }
                    if currentANSI.bold { tmp += ";1" }
                    if currentANSI.underline { tmp += ";4" }
                    if currentANSI.reverse { tmp += ";7" }
                    if currentANSI.fgColor != Int(config.fgColorIndex) {
                        tmp += ";\(currentANSI.fgColor + 30)"
                    }
                    if currentANSI.bgColor != Int(config.bgColorIndex) {
                        tmp += ";\(currentANSI.bgColor + 40)"
                    }
                    tmp += "m"
                    writeBuffer.append(escBytes)
                    writeBuffer.append(contentsOf: tmp.utf8)
                    writeBuffer.append(cellItem.byte)
                    previousANSI = currentANSI
                    continue
                }
                
                // Add attribute
                tmp += "["
                if currentANSI.blink && !previousANSI.blink { tmp += "5;" }
                if currentANSI.bold && !previousANSI.bold { tmp += "1;" }
                if currentANSI.underline && !previousANSI.underline { tmp += "4;" }
                if currentANSI.reverse && !previousANSI.reverse { tmp += "7;" }
                if currentANSI.fgColor != previousANSI.fgColor {
                    tmp += "\(currentANSI.fgColor + 30);"
                }
                if currentANSI.bgColor != previousANSI.bgColor {
                    tmp += "\(currentANSI.bgColor + 40);"
                }
                if tmp.hasSuffix(";") {
                    tmp.removeLast()
                }
                tmp += "m"
                writeBuffer.append(escBytes)
                writeBuffer.append(contentsOf: tmp.utf8)
                writeBuffer.append(cellItem.byte)
                previousANSI = currentANSI
            }
        }
        
        writeBuffer.append(escBytes)
        writeBuffer.append(contentsOf: "[m".utf8)
        
        if let conn = frontMostConnection() {
            let writeBufferBytes = [UInt8](writeBuffer)
            for byte in writeBufferBytes {
                var b = byte
                conn.sendBytes(&b, length: 1)
                usleep(100)
            }
        }
    }
    
    @IBAction public func paste(_ sender: Any?) {
        guard connected() else { return }
        let pb = NSPasteboard.general
        if let str = pb.string(forType: .string) {
            insertText(str, withDelay: 100)
        }
    }
    
    @objc public func pasteWrap(_ sender: Any?) {
        guard connected() else { return }
        let pb = NSPasteboard.general
        guard let text = pb.string(forType: .string) else { return }
        
        let lineWidth: Int32 = 66
        let lPadding: Int32 = 4
        let textSuite = YLTextSuite()
        
        guard let conn = frontMostConnection(), let site = conn.site else { return }
        
        let wrappedText = textSuite.wrapText(text, withLength: lineWidth, encoding: site.encoding)
        let paddedText = textSuite.paddingText(wrappedText, withLeftPadding: lPadding)
        
        insertText(paddedText, withDelay: 50)
    }
    
    @IBAction public override func selectAll(_ sender: Any?) {
        guard connected() else { return }
        let config = YLLGlobalConfig.sharedInstance()
        let gRow = Int(config.row)
        let gColumn = Int(config.column)
        
        _selectionLocation = 0
        _selectionLength = Int32(gRow * gColumn)
        needsDisplay = true
    }
}
