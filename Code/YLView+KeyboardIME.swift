import Cocoa
import CoreText

extension YLView: NSTextInputClient {
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
