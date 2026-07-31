import Cocoa
import CoreText

extension YLView {
    // MARK: - Event Handling (Mouse & Menu)
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
}
