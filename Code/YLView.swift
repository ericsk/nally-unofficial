import Cocoa
import CoreText
import CoreGraphics

@objc(YLView)
@objcMembers
public class YLView: NSTabView, NSTextInputClient {
    // Properties matching YLView.h
    public var _fontWidth: CGFloat = 12.0
    public var _fontHeight: CGFloat = 24.0
    
    public var _backedImage: NSImage?
    public var _timer: Timer?
    public var _x: Int32 = 0
    public var _y: Int32 = 0
    
    public var _markedText: NSAttributedString?
    public var _selectedRange = NSRange(location: NSNotFound, length: 0)
    public var _markedRange = NSRange(location: NSNotFound, length: 0)
    
    public var _textField: YLMarkedTextView?
    
    public var _selectionLocation: Int32 = 0
    public var _selectionLength: Int32 = 0
    
    public var _shouldOpenUrlInBackground: Bool = false
    public var _shouldUseImagePreviewer: Bool = true
    
    // Globals converted to static class variables or instance variables:
    private static var gLeftImage: NSImage?
    private static var gSingleAdvance: UnsafeMutablePointer<CGSize>?
    private static var gDoubleAdvance: UnsafeMutablePointer<CGSize>?
    
    private static let ANSIColorPBoardType = NSPasteboard.PasteboardType("ANSIColorPBoardType")
    
    // Symbol paths used in drawing
    public var gSymbolBlackSquareRect = NSRect.zero
    public var gSymbolBlackSquareRect1 = NSRect.zero
    public var gSymbolBlackSquareRect2 = NSRect.zero
    public var gSymbolLowerBlockRect = [NSRect](repeating: .zero, count: 8)
    public var gSymbolLowerBlockRect1 = [NSRect](repeating: .zero, count: 8)
    public var gSymbolLowerBlockRect2 = [NSRect](repeating: .zero, count: 8)
    public var gSymbolLeftBlockRect = [NSRect](repeating: .zero, count: 7)
    public var gSymbolLeftBlockRect1 = [NSRect](repeating: .zero, count: 7)
    public var gSymbolLeftBlockRect2 = [NSRect](repeating: .zero, count: 7)
    public var gSymbolTrianglePath = [NSBezierPath?](repeating: nil, count: 4)
    public var gSymbolTrianglePath1 = [NSBezierPath?](repeating: nil, count: 4)
    public var gSymbolTrianglePath2 = [NSBezierPath?](repeating: nil, count: 4)
    
    public var fontWidth: CGFloat { return _fontWidth }
    public var fontHeight: CGFloat { return _fontHeight }
    public var x: Int32 {
        get { return _x }
        set { _x = newValue }
    }
    public var y: Int32 {
        get { return _y }
        set { _y = newValue }
    }
    
    private static let initializeCursor: NSCursor = {
        let cursorImage = NSImage(size: NSMakeSize(11.0, 20.0))
        cursorImage.lockFocus()
        NSColor.clear.set()
        NSMakeRect(0, 0, 11, 20).fill()
        NSColor.white.set()
        let path = NSBezierPath()
        path.lineCapStyle = .round
        path.move(to: NSMakePoint(1.5, 1.5))
        path.line(to: NSMakePoint(2.5, 1.5))
        path.line(to: NSMakePoint(5.5, 4.5))
        path.line(to: NSMakePoint(8.5, 1.5))
        path.line(to: NSMakePoint(9.5, 1.5))
        path.move(to: NSMakePoint(5.5, 4.5))
        path.line(to: NSMakePoint(5.5, 15.5))
        path.line(to: NSMakePoint(2.5, 18.5))
        path.line(to: NSMakePoint(1.5, 18.5))
        path.move(to: NSMakePoint(5.5, 15.5))
        path.line(to: NSMakePoint(8.5, 18.5))
        path.line(to: NSMakePoint(9.5, 18.5))
        path.move(to: NSMakePoint(3.5, 9.5))
        path.line(to: NSMakePoint(7.5, 9.5))
        path.lineWidth = 3
        path.stroke()
        path.lineWidth = 1
        NSColor.black.set()
        path.stroke()
        cursorImage.unlockFocus()
        return NSCursor(image: cursorImage, hotSpot: NSMakePoint(5.5, 9.5))
    }()
    
    // MARK: - Initializers
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        configure()
        _selectionLength = 0
        _selectionLocation = 0
        tabViewType = .noTabsNoBorder
    }
    
    deinit {
        _timer?.invalidate()
    }
    
    // MARK: - Configuration
    private func createSymbolPath() {
        gSymbolBlackSquareRect = NSMakeRect(1.0, 1.0, _fontWidth * 2 - 2, _fontHeight - 2)
        gSymbolBlackSquareRect1 = NSMakeRect(1.0, 1.0, _fontWidth - 1, _fontHeight - 2)
        gSymbolBlackSquareRect2 = NSMakeRect(_fontWidth, 1.0, _fontWidth - 1, _fontHeight - 2)
        
        for i in 0..<8 {
            gSymbolLowerBlockRect[i] = NSMakeRect(0.0, 0.0, _fontWidth * 2, _fontHeight * CGFloat(i + 1) / 8.0)
            gSymbolLowerBlockRect1[i] = NSMakeRect(0.0, 0.0, _fontWidth, _fontHeight * CGFloat(i + 1) / 8.0)
            gSymbolLowerBlockRect2[i] = NSMakeRect(_fontWidth, 0.0, _fontWidth, _fontHeight * CGFloat(i + 1) / 8.0)
        }
        
        for i in 0..<7 {
            gSymbolLeftBlockRect[i] = NSMakeRect(0.0, 0.0, _fontWidth * CGFloat(7 - i) / 4.0, _fontHeight)
            gSymbolLeftBlockRect1[i] = NSMakeRect(0.0, 0.0, (7 - i >= 4) ? _fontWidth : (_fontWidth * CGFloat(7 - i) / 4.0), _fontHeight)
            gSymbolLeftBlockRect2[i] = NSMakeRect(_fontWidth, 0.0, (7 - i <= 4) ? 0.0 : (_fontWidth * CGFloat(3 - i) / 4.0), _fontHeight)
        }
        
        let pts = [
            NSMakePoint(_fontWidth, 0.0),
            NSMakePoint(0.0, 0.0),
            NSMakePoint(0.0, _fontHeight),
            NSMakePoint(_fontWidth, _fontHeight),
            NSMakePoint(_fontWidth * 2, _fontHeight),
            NSMakePoint(_fontWidth * 2, 0.0)
        ]
        
        let triangleIndex = [ [1, 4, 5], [1, 2, 5], [1, 2, 4], [2, 4, 5] ]
        let triangleIndex1 = [ [0, 1, -1], [0, 1, 2], [1, 2, 3], [2, 3, -1] ]
        let triangleIndex2 = [ [4, 5, 0], [5, 0, -1], [3, 4, -1], [3, 4, 5] ]
        
        for base in 0..<4 {
            let path = NSBezierPath()
            path.move(to: pts[triangleIndex[base][0]])
            for i in 1..<3 {
                path.line(to: pts[triangleIndex[base][i]])
            }
            path.close()
            gSymbolTrianglePath[base] = path
            
            let path1 = NSBezierPath()
            path1.move(to: NSMakePoint(_fontWidth, _fontHeight / 2))
            for i in 0..<3 {
                let idx = triangleIndex1[base][i]
                if idx >= 0 {
                    path1.line(to: pts[idx])
                }
            }
            path1.close()
            gSymbolTrianglePath1[base] = path1
            
            let path2 = NSBezierPath()
            path2.move(to: NSMakePoint(_fontWidth, _fontHeight / 2))
            for i in 0..<3 {
                let idx = triangleIndex2[base][i]
                if idx >= 0 {
                    path2.line(to: pts[idx])
                }
            }
            path2.close()
            gSymbolTrianglePath2[base] = path2
        }
    }
    
    public func configure() {
        let config = YLLGlobalConfig.sharedInstance()
        let gColumn = Int(config.column)
        let gRow = Int(config.row)
        _fontWidth = config.cellWidth
        _fontHeight = config.cellHeight
        
        var frame = self.frame
        frame.size = NSMakeSize(_fontWidth * CGFloat(gColumn), _fontHeight * CGFloat(gRow))
        frame.origin = NSZeroPoint
        self.frame = frame
        
        createSymbolPath()
        
        _backedImage = NSImage(size: frame.size)
        
        YLView.gLeftImage = NSImage(size: NSMakeSize(_fontWidth, _fontHeight))
        
        if YLView.gSingleAdvance == nil {
            YLView.gSingleAdvance = UnsafeMutablePointer<CGSize>.allocate(capacity: gColumn)
        }
        if YLView.gDoubleAdvance == nil {
            YLView.gDoubleAdvance = UnsafeMutablePointer<CGSize>.allocate(capacity: gColumn)
        }
        
        for i in 0..<gColumn {
            YLView.gSingleAdvance?[i] = CGSize(width: _fontWidth * 1.0, height: 0.0)
            YLView.gDoubleAdvance?[i] = CGSize(width: _fontWidth * 2.0, height: 0.0)
        }
        
        _markedText = nil
        _selectedRange = NSRange(location: NSNotFound, length: 0)
        _markedRange = NSRange(location: NSNotFound, length: 0)
        _textField?.isHidden = true
    }
    
    // MARK: - Actions
    @IBAction public func copy(_ sender: Any?) {
        guard connected() else { return }
        if _selectionLength == 0 { return }
        
        let config = YLLGlobalConfig.sharedInstance()
        let gRow = Int(config.row)
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
                
                // Unchanged
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
    
    public func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        let action = menuItem.action
        if action == #selector(copy(_:)) && (!connected() || _selectionLength == 0) {
            return false
        } else if (action == #selector(paste(_:)) ||
                    action == #selector(pasteWrap(_:)) ||
                    action == #selector(pasteColor(_:))) && !connected() {
            return false
        } else if action == #selector(selectAll(_:)) && !connected() {
            return false
        }
        return true
    }
    
    @objc public func refreshHiddenRegion() {
        guard connected() else { return }
        let config = YLLGlobalConfig.sharedInstance()
        let gRow = Int(config.row)
        let gColumn = Int(config.column)
        
        guard let ds = frontMostTerminal() else { return }
        
        for r in 0..<gRow {
            guard let currRow = ds.cells(ofRow: Int32(r)) else { continue }
            for c in 0..<gColumn {
                if currRow[c].attr.terminalAttribute.isHidden {
                    ds.setDirty(true, atRow: Int32(r), column: Int32(c))
                }
            }
        }
    }
    
    @objc(loadUrlOfString:)
    public func loadUrl(of urlString: String) {
        guard let url = URL(string: urlString) else { return }
        let pathExtension = url.pathExtension.lowercased()
        
        let isImageExtension = ["png", "jpg", "jpeg", "gif", "tiff", "bmp", "webp"].contains(pathExtension)
        let isImage = _shouldUseImagePreviewer && !urlString.hasSuffix("/") && isImageExtension && pathExtension != "pdf"
        
        if isImage {
            _ = YLImagePreviewer(url: url)
        } else {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = !_shouldOpenUrlInBackground
            NSWorkspace.shared.open(url, configuration: configuration, completionHandler: nil)
        }
    }
    
    private func resolveShortUrl(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        let session = URLSession(configuration: .default, delegate: URLSessionRedirectDelegate(owner: self), delegateQueue: .main)
        let task = session.dataTask(with: url)
        task.resume()
    }
    
    // MARK: - Conversion
    @objc(convertIndexFromPoint:)
    public func convertIndex(from p: NSPoint) -> Int {
        let config = YLLGlobalConfig.sharedInstance()
        let gRow = Int(config.row)
        let gColumn = Int(config.column)
        
        var pt = p
        if pt.x >= CGFloat(gColumn) * _fontWidth { pt.x = CGFloat(gColumn) * _fontWidth - 0.001 }
        if pt.y >= CGFloat(gRow) * _fontHeight { pt.y = CGFloat(gRow) * _fontHeight - 0.001 }
        if pt.x < 0 { pt.x = 0 }
        if pt.y < 0 { pt.y = 0 }
        
        let cx = Int(pt.x / _fontWidth)
        let cy = gRow - Int(pt.y / _fontHeight) - 1
        return cy * gColumn + cx
    }
    
    // MARK: - Event Handling
    public override func mouseDown(with event: NSEvent) {
        frontMostTerminal()?.hasMessage = false
        window?.makeFirstResponder(self)
        guard connected() else { return }
        
        var p = event.locationInWindow
        p = convert(p, from: nil)
        _selectionLocation = Int32(convertIndex(from: p))
        _selectionLength = 0
        
        let modifierFlags = event.modifierFlags
        let isCmdPressed = modifierFlags.contains(.command)
        
        if !isCmdPressed && event.clickCount == 3 {
            let config = YLLGlobalConfig.sharedInstance()
            let gColumn = Int(config.column)
            _selectionLocation = _selectionLocation - (_selectionLocation % Int32(gColumn))
            _selectionLength = Int32(gColumn)
        } else if !isCmdPressed && event.clickCount == 2 {
            let config = YLLGlobalConfig.sharedInstance()
            let gColumn = Int(config.column)
            let r = Int(_selectionLocation) / gColumn
            let c = Int(_selectionLocation) % gColumn
            
            guard let ds = frontMostTerminal() else { return }
            ds.updateDoubleByteState(forRow: Int32(r))
            guard let currRow = ds.cells(ofRow: Int32(r)) else { return }
            
            let doubleByte = Int(currRow[c].attr.terminalAttribute.doubleByte)
            if doubleByte == 1 {
                _selectionLength = 2
            } else if doubleByte == 2 {
                _selectionLocation -= 1
                _selectionLength = 2
            } else if isEnglishNumberAlphabet(currRow[c].byte) {
                var col = c
                while col >= 0 {
                    let cellItem = currRow[col]
                    if isEnglishNumberAlphabet(cellItem.byte) && cellItem.attr.terminalAttribute.doubleByte == 0 {
                        _selectionLocation = Int32(r * gColumn + col)
                    } else {
                        break
                    }
                    col -= 1
                }
                col = c + 1
                while col < gColumn {
                    let cellItem = currRow[col]
                    if isEnglishNumberAlphabet(cellItem.byte) && cellItem.attr.terminalAttribute.doubleByte == 0 {
                        _selectionLength += 1
                    } else {
                        break
                    }
                    col += 1
                }
            } else {
                _selectionLength = 1
            }
        }
        
        needsDisplay = true
        
        // Click to move cursor
        if isCmdPressed {
            let config = YLLGlobalConfig.sharedInstance()
            let gRow = Int(config.row)
            let gColumn = Int(config.column)
            var cmd = [UInt8]()
            let moveToRow = Int(_selectionLocation) / gColumn
            let moveToCol = Int(_selectionLocation) % gColumn
            guard let ds = frontMostTerminal() else { return }
            var home = false
            
            let cursorRow = Int(ds.cursorRow)
            let cursorColumn = Int(ds.cursorColumn)
            
            if moveToRow > cursorRow {
                cmd.append(0x01)
                home = true
                for _ in cursorRow..<moveToRow {
                    cmd.append(contentsOf: [0x1B, 0x4F, 0x42]) // Down arrow 'B'
                }
            } else if moveToRow < cursorRow {
                cmd.append(0x01)
                home = true
                for _ in moveToRow..<cursorRow {
                    cmd.append(contentsOf: [0x1B, 0x4F, 0x41]) // Up arrow 'A'
                }
            }
            
            guard let currRow = ds.cells(ofRow: Int32(moveToRow)) else { return }
            let detectDoubleByte = frontMostConnection()?.site?.detectDoubleByte ?? true
            
            let sendRight = {
                cmd.append(contentsOf: [0x1B, 0x4F, 0x43]) // Right arrow 'C'
            }
            let sendLeft = {
                cmd.append(contentsOf: [0x1B, 0x4F, 0x44]) // Left arrow 'D'
            }
            
            if home {
                for i in 0..<moveToCol {
                    if currRow[i].attr.terminalAttribute.doubleByte != 2 || detectDoubleByte {
                        sendRight()
                    }
                }
            } else if moveToCol > cursorColumn {
                for i in cursorColumn..<moveToCol {
                    if currRow[i].attr.terminalAttribute.doubleByte != 2 || detectDoubleByte {
                        sendRight()
                    }
                }
            } else if moveToCol < cursorColumn {
                for i in moveToCol..<cursorColumn {
                    if currRow[i].attr.terminalAttribute.doubleByte != 2 || detectDoubleByte {
                        sendLeft()
                    }
                }
            }
            
            if !cmd.isEmpty, let conn = frontMostConnection() {
                var bytes = cmd
                conn.sendBytes(&bytes, length: bytes.count)
            }
        }
    }
    
    public override func mouseDragged(with event: NSEvent) {
        guard connected() else { return }
        var p = event.locationInWindow
        p = convert(p, from: nil)
        let index = convertIndex(from: p)
        let oldValue = _selectionLength
        _selectionLength = Int32(index) - _selectionLocation + 1
        if _selectionLength <= 0 {
            _selectionLength -= 1
        }
        if oldValue != _selectionLength {
            needsDisplay = true
        }
    }
    
    public override func mouseUp(with event: NSEvent) {
        guard connected() else { return }
        if _selectionLength == 0 {
            var p = event.locationInWindow
            p = convert(p, from: nil)
            let index = convertIndex(from: p)
            
            let config = YLLGlobalConfig.sharedInstance()
            let gColumn = Int(config.column)
            
            if let ds = frontMostTerminal(),
               let url = ds.urlString(atRow: Int32(index / gColumn), column: Int32(index % gColumn)) {
                
                let modifierFlags = event.modifierFlags
                if !modifierFlags.contains(.command) {
                    _shouldOpenUrlInBackground = modifierFlags.contains(.option)
                    _shouldUseImagePreviewer = config.shouldPreferImagePreviewer
                    if modifierFlags.contains(.shift) {
                        _shouldUseImagePreviewer = !_shouldUseImagePreviewer
                    }
                    
                    if url.count < 25 && url.hasPrefix("http://") {
                        resolveShortUrl(url)
                    } else {
                        loadUrl(of: url)
                    }
                }
            }
        }
    }
    
    public override func keyDown(with event: NSEvent) {
        clearSelection()
        
        guard let characters = event.characters, !characters.isEmpty else {
            super.keyDown(with: event)
            return
        }
        
        let c = characters.utf16.first!
        var buf = [UInt8](repeating: 0, count: 10)
        
        frontMostTerminal()?.hasMessage = false
        
        let modifierFlags = event.modifierFlags
        
        if modifierFlags.contains(.control) {
            buf[0] = UInt8(c & 0xFF)
            frontMostConnection()?.sendBytes(&buf, length: 1)
            return
        } else if modifierFlags.contains(.command) {
            buf[0] = 0x1b
            buf[1] = 0x5b
            buf[2] = 0x00
            buf[3] = 0x7e
            
            switch c {
            case UInt16(NSUpArrowFunctionKey):
                buf[2] = 0x35
            case UInt16(NSDownArrowFunctionKey):
                buf[2] = 0x36
            case UInt16(NSLeftArrowFunctionKey):
                buf[2] = 0x31
            case UInt16(NSRightArrowFunctionKey):
                buf[2] = 0x34
            default:
                break
            }
            
            if buf[2] != 0x00 {
                frontMostConnection()?.sendBytes(&buf, length: 4)
            } else {
                super.keyDown(with: event)
            }
            return
        }
        
        var arrow: [UInt8] = [0x1B, 0x4F, 0x00, 0x1B, 0x4F, 0x00]
        
        let isArrow = c == NSUpArrowFunctionKey ||
                      c == NSDownArrowFunctionKey ||
                      c == NSRightArrowFunctionKey ||
                      c == NSLeftArrowFunctionKey
                      
        if isArrow {
            let arrowChar: UInt8
            switch c {
            case UInt16(NSUpArrowFunctionKey):
                arrowChar = UInt8(ascii: "A")
            case UInt16(NSDownArrowFunctionKey):
                arrowChar = UInt8(ascii: "B")
            case UInt16(NSRightArrowFunctionKey):
                arrowChar = UInt8(ascii: "C")
            case UInt16(NSLeftArrowFunctionKey):
                arrowChar = UInt8(ascii: "D")
            default:
                arrowChar = 0
            }
            arrow[2] = arrowChar
            arrow[5] = arrowChar
            
            guard let ds = frontMostTerminal() else { return }
            
            if !hasMarkedText() {
                ds.updateDoubleByteState(forRow: ds.cursorRow)
                
                let isRightDoubleByte = c == NSRightArrowFunctionKey &&
                    ds.cells(ofRow: ds.cursorRow)?[Int(ds.cursorColumn)].attr.terminalAttribute.doubleByte == 1
                    
                let isLeftDoubleByte = c == NSLeftArrowFunctionKey &&
                    ds.cursorColumn > 0 &&
                    ds.cells(ofRow: ds.cursorRow)?[Int(ds.cursorColumn) - 1].attr.terminalAttribute.doubleByte == 2
                    
                let detectDoubleByte = frontMostConnection()?.site?.detectDoubleByte ?? true
                
                if (isRightDoubleByte || isLeftDoubleByte) && detectDoubleByte {
                    frontMostConnection()?.sendBytes(&arrow, length: 6)
                    return
                }
                
                var threeBytes = Array(arrow[0..<3])
                frontMostConnection()?.sendBytes(&threeBytes, length: 3)
                return
            }
        }
        
        if !hasMarkedText() && c == 0x7F {
            buf[0] = 0x08
            buf[1] = 0x08
            
            guard let ds = frontMostTerminal() else { return }
            let detectDoubleByte = frontMostConnection()?.site?.detectDoubleByte ?? true
            
            let isDeleteDoubleByte = detectDoubleByte &&
                ds.cursorColumn > 0 &&
                ds.cells(ofRow: ds.cursorRow)?[Int(ds.cursorColumn) - 1].attr.terminalAttribute.doubleByte == 2
                
            if isDeleteDoubleByte {
                frontMostConnection()?.sendBytes(&buf, length: 2)
            } else {
                frontMostConnection()?.sendBytes(&buf, length: 1)
            }
            return
        }
        
        interpretKeyEvents([event])
    }
    
    public override func flagsChanged(with event: NSEvent) {
        let currentFlags = event.modifierFlags
        let viewCursor: NSCursor
        if currentFlags.contains(.command) {
            viewCursor = YLView.initializeCursor
        } else {
            viewCursor = NSCursor.arrow
        }
        viewCursor.set()
        super.flagsChanged(with: event)
    }
    
    @objc public func clearSelection() {
        if _selectionLength != 0 {
            _selectionLength = 0
            needsDisplay = true
        }
    }
    
    // MARK: - Drawing Helpers
    @objc public func displayCellAtRow(_ r: Int32, column c: Int32) {
        let config = YLLGlobalConfig.sharedInstance()
        let gRow = Int(config.row)
        setNeedsDisplay(NSMakeRect(CGFloat(c) * _fontWidth, CGFloat(gRow - 1 - Int(r)) * _fontHeight, _fontWidth, _fontHeight))
    }
    
    @objc public func tick() {
        autoreleasepool {
            updateBackedImage()
            guard let ds = frontMostTerminal() else { return }
            
            let config = YLLGlobalConfig.sharedInstance()
            let gRow = Int(config.row)
            
            if _x != ds.cursorColumn || _y != ds.cursorRow {
                setNeedsDisplay(NSMakeRect(CGFloat(_x) * _fontWidth, CGFloat(gRow - 1 - Int(_y)) * _fontHeight, _fontWidth, _fontHeight))
                setNeedsDisplay(NSMakeRect(CGFloat(ds.cursorColumn) * _fontWidth, CGFloat(gRow - 1 - Int(ds.cursorRow)) * _fontHeight, _fontWidth, _fontHeight))
                _x = ds.cursorColumn
                _y = ds.cursorRow
            }
        }
    }
    
    private func cellRect(for rect: NSRect) -> NSRect {
        let originx = Int(rect.origin.x / _fontWidth)
        let originy = Int(rect.origin.y / _fontHeight)
        let width = Int((rect.size.width + rect.origin.x) / _fontWidth) - originx + 1
        let height = Int((rect.size.height + rect.origin.y) / _fontHeight) - originy + 1
        return NSMakeRect(CGFloat(originx), CGFloat(originy), CGFloat(width), CGFloat(height))
    }
    
    public override func draw(_ rect: NSRect) {
        autoreleasepool {
            let config = YLLGlobalConfig.sharedInstance()
            let gRow = Int(config.row)
            let gColumn = Int(config.column)
            
            if connected() {
                // Draw the backed image
                if let backedImage = _backedImage {
                    backedImage.draw(at: rect.origin, from: rect, operation: .copy, fraction: 1.0)
                }
                
                drawBlink()
                
                // Draw the url underline
                if let ds = frontMostTerminal() {
                    NSColor.orange.set()
                    NSBezierPath.defaultLineWidth = 1.0
                    for r in 0..<gRow {
                        guard let currRow = ds.cells(ofRow: Int32(r)) else { continue }
                        var c = 0
                        while c < gColumn {
                            let start = c
                            while c < gColumn && currRow[c].attr.terminalAttribute.url {
                                c += 1
                            }
                            if c != start {
                                NSBezierPath.strokeLine(
                                    from: NSMakePoint(CGFloat(start) * _fontWidth, CGFloat(gRow - r - 1) * _fontHeight + 0.5),
                                    to: NSMakePoint(CGFloat(c) * _fontWidth, CGFloat(gRow - r - 1) * _fontHeight + 0.5)
                                )
                            }
                            c += 1
                        }
                    }
                    
                    // Draw the cursor
                    NSColor.white.set()
                    NSBezierPath.defaultLineWidth = 2.0
                    NSBezierPath.strokeLine(
                        from: NSMakePoint(CGFloat(ds.cursorColumn) * _fontWidth, CGFloat(gRow - 1 - Int(ds.cursorRow)) * _fontHeight + 1),
                        to: NSMakePoint(CGFloat(ds.cursorColumn + 1) * _fontWidth, CGFloat(gRow - 1 - Int(ds.cursorRow)) * _fontHeight + 1)
                    )
                    NSBezierPath.defaultLineWidth = 1.0
                    _x = ds.cursorColumn
                    _y = ds.cursorRow
                }
                
                // Draw the selection
                if _selectionLength != 0 {
                    drawSelection()
                }
            } else {
                (config.colorBG ?? NSColor.black).set()
                bounds.fill()
            }
        }
    }
    
    @objc public func drawBlink() {
        let config = YLLGlobalConfig.sharedInstance()
        guard config.blinkTicker else { return }
        guard let ds = frontMostTerminal() else { return }
        
        let gRow = Int(config.row)
        let gColumn = Int(config.column)
        
        for r in 0..<gRow {
            guard let currRow = ds.cells(ofRow: Int32(r)) else { continue }
            for c in 0..<gColumn {
                if currRow[c].terminalCell.isBlink {
                    let attr = currRow[c].attr.terminalAttribute
                    let bgColorIndex = attr.reverse ? attr.fgColor : attr.bgColor
                    let bold = attr.reverse ? attr.bold : false
                    
                    config.colorAtIndex(Int32(bgColorIndex), hilite: bold).set()
                    NSMakeRect(CGFloat(c) * _fontWidth, CGFloat(gRow - r - 1) * _fontHeight, _fontWidth, _fontHeight).fill()
                }
            }
        }
    }
    
    @objc public func drawSelection() {
        let config = YLLGlobalConfig.sharedInstance()
        let gRow = Int(config.row)
        let gColumn = Int(config.column)
        
        var location: Int
        var length: Int
        if _selectionLength >= 0 {
            location = Int(_selectionLocation)
            length = Int(_selectionLength)
        } else {
            location = Int(_selectionLocation + _selectionLength)
            length = 0 - Int(_selectionLength)
        }
        var x = location % gColumn
        var y = location / gColumn
        NSColor(calibratedRed: 0.6, green: 0.9, blue: 0.6, alpha: 0.4).set()
        
        while length > 0 {
            if x + length <= gColumn {
                NSMakeRect(CGFloat(x) * _fontWidth, CGFloat(gRow - y - 1) * _fontHeight, _fontWidth * CGFloat(length), _fontHeight).fill()
                length = 0
            } else {
                NSMakeRect(CGFloat(x) * _fontWidth, CGFloat(gRow - y - 1) * _fontHeight, _fontWidth * CGFloat(gColumn - x), _fontHeight).fill()
                length -= (gColumn - x)
            }
            x = 0
            y += 1
        }
    }
    
    @objc(extendBottomFrom:to:)
    public func extendBottom(from start: Int32, to end: Int32) {
        let config = YLLGlobalConfig.sharedInstance()
        let gRow = Int(config.row)
        let gColumn = Int(config.column)
        
        _backedImage?.lockFocus()
        _backedImage?.draw(
            at: NSMakePoint(0.0, CGFloat(gRow - Int(end)) * _fontHeight),
            from: NSMakeRect(0.0, CGFloat(gRow - Int(end) - 1) * _fontHeight, CGFloat(gColumn) * _fontWidth, CGFloat(end - start) * _fontHeight),
            operation: .copy,
            fraction: 1.0
        )
        
        config.colorAtIndex(config.bgColorIndex, hilite: false).set()
        NSMakeRect(0.0, CGFloat(gRow - Int(end) - 1) * _fontHeight, CGFloat(gColumn) * _fontWidth, _fontHeight).fill()
        _backedImage?.unlockFocus()
    }
    
    @objc(extendTopFrom:to:)
    public func extendTop(from start: Int32, to end: Int32) {
        let config = YLLGlobalConfig.sharedInstance()
        let gRow = Int(config.row)
        let gColumn = Int(config.column)
        
        _backedImage?.lockFocus()
        _backedImage?.draw(
            at: NSMakePoint(0.0, CGFloat(gRow - Int(end) - 1) * _fontHeight),
            from: NSMakeRect(0.0, CGFloat(gRow - Int(end)) * _fontHeight, CGFloat(gColumn) * _fontWidth, CGFloat(end - start) * _fontHeight),
            operation: .copy,
            fraction: 1.0
        )
        
        config.colorAtIndex(config.bgColorIndex, hilite: false).set()
        NSMakeRect(0.0, CGFloat(gRow - Int(start) - 1) * _fontHeight, CGFloat(gColumn) * _fontWidth, _fontHeight).fill()
        _backedImage?.unlockFocus()
    }
    
    @objc public func updateBackedImage() {
        let config = YLLGlobalConfig.sharedInstance()
        let gRow = Int(config.row)
        let gColumn = Int(config.column)
        guard let ds = frontMostTerminal() else {
            _backedImage?.lockFocus()
            if let ctx = NSGraphicsContext.current?.cgContext {
                NSColor.clear.set()
                ctx.fill(CGRect(x: 0, y: 0, width: CGFloat(gColumn) * _fontWidth, height: CGFloat(gRow) * _fontHeight))
            }
            _backedImage?.unlockFocus()
            return
        }
        
        _backedImage?.lockFocus()
        if let ctx = NSGraphicsContext.current?.cgContext {
            /* Draw Background */
            var y = 0
            while y < gRow {
                var x = 0
                while x < gColumn {
                    if ds.isDirty(atRow: Int32(y), column: Int32(x)) {
                        let startx = x
                        while x < gColumn && ds.isDirty(atRow: Int32(y), column: Int32(x)) {
                            x += 1
                        }
                        updateBackground(forRow: Int32(y), from: Int32(startx), to: Int32(x))
                    }
                    x += 1
                }
                y += 1
            }
            
            ctx.saveGState()
            ctx.setShouldSmoothFonts(config.shouldSmoothFonts)
            
            /* Draw String row by row */
            for r in 0..<gRow {
                drawString(forRow: Int32(r), context: ctx)
            }
            ctx.restoreGState()
            
            for r in 0..<gRow {
                for c in 0..<gColumn {
                    ds.setDirty(false, atRow: Int32(r), column: Int32(c))
                }
            }
        }
        _backedImage?.unlockFocus()
    }
    
    // MARK: - Overrides
    public override var acceptsFirstResponder: Bool {
        return true
    }
    
    public override var canBecomeKeyView: Bool {
        return true
    }
    
    public override var isFlipped: Bool {
        return false
    }
    
    public override var isOpaque: Bool {
        return true
    }
    
    public override func hitTest(_ point: NSPoint) -> NSView? {
        return self
    }
    
    public override var mouseDownCanMoveWindow: Bool {
        return false
    }
    
    public override class var defaultMenu: NSMenu? {
        return NSMenu()
    }
    
    public override func menu(for event: NSEvent) -> NSMenu? {
        let menu = YLView.defaultMenu ?? NSMenu()
        guard connected() else { return menu }
        
        if let s = selectedPlainString() {
            let a = YLContextualMenuManager.sharedInstance.availableMenuItemForSelectionString(s)
            for item in a {
                menu.addItem(item)
            }
        }
        return menu
    }
    
    // MARK: - Accessors & Helpers
    @objc public func connected() -> Bool {
        return frontMostConnection()?.connected ?? false
    }
    
    @objc public func frontMostTerminal() -> YLTerminal? {
        return frontMostConnection()?.terminal
    }
    
    @objc public func frontMostConnection() -> YLConnection? {
        guard let item = selectedTabViewItem else { return nil }
        return item.identifier as? YLConnection
    }
    
    @objc public func selectedPlainString() -> String? {
        if _selectionLength == 0 { return nil }
        let config = YLLGlobalConfig.sharedInstance()
        let gColumn = Int(config.column)
        
        var location: Int
        var length: Int
        if _selectionLength >= 0 {
            location = Int(_selectionLocation)
            length = Int(_selectionLength)
        } else {
            location = Int(_selectionLocation + _selectionLength)
            length = 0 - Int(_selectionLength)
        }
        return frontMostTerminal()?.stringFromIndex(Int32(location), length: Int32(length))
    }
    
    @objc public func hasBlinkCell() -> Bool {
        guard let ds = frontMostTerminal() else { return false }
        let config = YLLGlobalConfig.sharedInstance()
        let gRow = Int(config.row)
        let gColumn = Int(config.column)
        
        for r in 0..<gRow {
            ds.updateDoubleByteState(forRow: Int32(r))
            guard let currRow = ds.cells(ofRow: Int32(r)) else { continue }
            for c in 0..<gColumn {
                if currRow[c].terminalCell.isBlink {
                    return true
                }
            }
        }
        return false
    }
    
    // MARK: - SwiftBridge Compatibility
    @objc public func swiftFrontMostTerminal() -> YLTerminal? {
        return frontMostTerminal()
    }
    
    // MARK: - Private Helpers
    private func isEnglishNumberAlphabet(_ c: UInt8) -> Bool {
        return (UInt8(ascii: "0") <= c && c <= UInt8(ascii: "9")) ||
               (UInt8(ascii: "A") <= c && c <= UInt8(ascii: "Z")) ||
               (UInt8(ascii: "a") <= c && c <= UInt8(ascii: "z")) ||
               (c == UInt8(ascii: "-")) ||
               (c == UInt8(ascii: "_")) ||
               (c == UInt8(ascii: "."))
    }
    
    // MARK: - NSTextInputClient Protocol
    public func insertText(_ string: Any, replacementRange: NSRange) {
        insertText(string, withDelay: 0)
    }
    
    @objc(insertText:withDelay:)
    public func insertText(_ string: Any, withDelay microsecond: Int32) {
        _textField?.isHidden = true
        _markedText = nil
        
        let str: String
        if let nsStr = string as? NSAttributedString {
            str = nsStr.string
        } else if let s = string as? String {
            str = s
        } else {
            return
        }
        
        let mStr = NSMutableString(string: str)
        mStr.replaceOccurrences(of: "\n", with: "\r", options: .literal, range: NSRange(location: 0, length: mStr.length))
        
        var data = Data()
        guard let conn = frontMostConnection(), let site = conn.site else { return }
        
        for i in 0..<mStr.length {
            let ch = mStr.character(at: i)
            var buf = [UInt8](repeating: 0, count: 2)
            if ch < 0x007F {
                buf[0] = UInt8(ch)
                data.append(&buf, count: 1)
            } else {
                let code: UInt16
                if site.encoding == .YLBig5Encoding {
                    code = lookupU2B(ch)
                } else {
                    code = lookupU2G(ch)
                }
                buf[0] = UInt8(code >> 8)
                buf[1] = UInt8(code & 0xFF)
                data.append(&buf, count: 2)
            }
        }
        
        if microsecond == 0 {
            conn.sendData(data)
        } else {
            let dataBytes = [UInt8](data)
            for byte in dataBytes {
                var b = byte
                conn.sendBytes(&b, length: 1)
                usleep(useconds_t(microsecond))
            }
        }
    }
    
    public override func doCommand(by aSelector: Selector) {
        var ch = [UInt8](repeating: 0, count: 10)
        
        if aSelector == #selector(NSResponder.insertNewline(_:)) {
            ch[0] = 0x0D
            frontMostConnection()?.sendBytes(&ch, length: 1)
        } else if aSelector == #selector(NSResponder.cancelOperation(_:)) {
            ch[0] = 0x1B
            frontMostConnection()?.sendBytes(&ch, length: 1)
        } else if aSelector == #selector(NSResponder.scrollToBeginningOfDocument(_:)) {
            ch[0] = 0x1B; ch[1] = 0x5B; ch[2] = 0x31; ch[3] = 0x7E
            frontMostConnection()?.sendBytes(&ch, length: 4)
        } else if aSelector == #selector(NSResponder.scrollToEndOfDocument(_:)) {
            ch[0] = 0x1B; ch[1] = 0x5B; ch[2] = 0x34; ch[3] = 0x7E
            frontMostConnection()?.sendBytes(&ch, length: 4)
        } else if aSelector == #selector(NSResponder.scrollPageUp(_:)) {
            ch[0] = 0x1B; ch[1] = 0x5B; ch[2] = 0x35; ch[3] = 0x7E
            frontMostConnection()?.sendBytes(&ch, length: 4)
        } else if aSelector == #selector(NSResponder.scrollPageDown(_:)) {
            ch[0] = 0x1B; ch[1] = 0x5B; ch[2] = 0x36; ch[3] = 0x7E
            frontMostConnection()?.sendBytes(&ch, length: 4)
        } else if aSelector == #selector(NSResponder.insertTab(_:)) {
            ch[0] = 0x09
            frontMostConnection()?.sendBytes(&ch, length: 1)
        } else if aSelector == #selector(NSResponder.deleteForward(_:)) {
            ch[0] = 0x1B; ch[1] = 0x5B; ch[2] = 0x33; ch[3] = 0x7E
            ch[4] = 0x1B; ch[5] = 0x5B; ch[6] = 0x33; ch[7] = 0x7E
            var len = 4
            if let ds = frontMostTerminal(),
               let site = frontMostConnection()?.site, site.detectDoubleByte,
               ds.cursorColumn < (Int32(YLLGlobalConfig.sharedInstance().column) - 1),
               ds.cells(ofRow: ds.cursorRow)?[Int(ds.cursorColumn) + 1].attr.terminalAttribute.doubleByte == 2 {
                len += 4
            }
            frontMostConnection()?.sendBytes(&ch, length: len)
        } else {
            NSLog("Unprocessed selector: %@", NSStringFromSelector(aSelector))
        }
    }
    
    @objc(setMarkedText:selectedRange:)
    public func setMarkedText(_ string: Any, selectedRange: NSRange) {
        guard let ds = frontMostTerminal() else { return }
        
        let attrString: NSAttributedString
        if let str = string as? NSAttributedString {
            attrString = str
        } else if let str = string as? String {
            attrString = NSAttributedString(string: str)
        } else {
            return
        }
        
        if attrString.length == 0 {
            unmarkText()
            return
        }
        
        _markedText = attrString
        _selectedRange = selectedRange
        _markedRange = NSRange(location: 0, length: attrString.length)
        
        _textField?.string = attrString
        _textField?.selectedRange = selectedRange
        _textField?.markedRange = _markedRange
        
        let config = YLLGlobalConfig.sharedInstance()
        let gRow = Int(config.row)
        
        var o = NSMakePoint(CGFloat(ds.cursorColumn) * _fontWidth, CGFloat(gRow - 1 - Int(ds.cursorRow)) * _fontHeight + 5.0)
        let dy: CGFloat
        if let tf = _textField {
            if o.x + tf.frame.size.width > CGFloat(config.column) * _fontWidth {
                o.x = CGFloat(config.column) * _fontWidth - tf.frame.size.width
            }
            if o.y + tf.frame.size.height > CGFloat(gRow) * _fontHeight {
                o.y = CGFloat(gRow - Int(ds.cursorRow)) * _fontHeight - 5.0 - tf.frame.size.height
                dy = o.y + tf.frame.size.height
            } else {
                dy = o.y
            }
            tf.setFrameOrigin(o)
            tf.destination = tf.convert(NSMakePoint((CGFloat(ds.cursorColumn) + 0.5) * _fontWidth, dy), from: self)
            tf.isHidden = false
        }
    }
    
    public func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        setMarkedText(string, selectedRange: selectedRange)
    }
    
    public func unmarkText() {
        _textField?.isHidden = true
        _markedText = nil
    }
    
    public func selectedRange() -> NSRange {
        return _selectedRange
    }
    
    public func markedRange() -> NSRange {
        return _markedRange
    }
    
    public func hasMarkedText() -> Bool {
        return _markedText != nil
    }
    
    public func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        guard let markedText = _markedText else { return nil }
        var theRange = range
        if theRange.location >= markedText.length { return nil }
        if theRange.location + theRange.length > markedText.length {
            theRange.length = markedText.length - theRange.location
        }
        return markedText.attributedSubstring(from: theRange)
    }
    
    public func validAttributesForMarkedText() -> [NSAttributedString.Key] {
        return []
    }
    
    public func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        guard let textField = _textField, let window = textField.window else { return .zero }
        let rectInWindow = textField.frame
        let rectInScreen = window.convertToScreen(rectInWindow)
        return rectInScreen
    }
    
    public func characterIndex(for point: NSPoint) -> Int {
        return 0
    }
    
    public func attributedString() -> NSAttributedString {
        return NSAttributedString()
    }
    
    public func fractionOfDistanceThroughGlyph(for point: NSPoint) -> CGFloat {
        return 0
    }
    
    public func baselineDeltaForCharacter(at index: Int) -> CGFloat {
        return 0
    }
}

// MARK: - URLSessionRedirectDelegate
private class URLSessionRedirectDelegate: NSObject, URLSessionTaskDelegate {
    private weak var owner: YLView?
    
    init(owner: YLView) {
        self.owner = owner
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        if let newUrl = request.url {
            owner?.loadUrl(of: newUrl.absoluteString)
        }
        completionHandler(nil) // Cancel redirection since we only want the final URL
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if error == nil, let finalUrl = task.response?.url {
            owner?.loadUrl(of: finalUrl.absoluteString)
        }
    }
}
