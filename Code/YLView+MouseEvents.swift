import Cocoa
import CoreText

extension YLView {
    // MARK: - Event Handling (Mouse & Menu)
    public override func mouseDown(with event: NSEvent) {
        cancelPendingHoverPreview()
        frontMostTerminal()?.hasMessage = false
        window?.makeFirstResponder(self)
        guard frontMostTerminal() != nil else { return }
        
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
                var startCol = c
                while startCol > 0 {
                    let prevCell = currRow[startCol - 1]
                    if isEnglishNumberAlphabet(prevCell.byte) && prevCell.attr.terminalAttribute.doubleByte == 0 {
                        startCol -= 1
                    } else {
                        break
                    }
                }
                var endCol = c
                while endCol + 1 < gColumn {
                    let nextCell = currRow[endCol + 1]
                    if isEnglishNumberAlphabet(nextCell.byte) && nextCell.attr.terminalAttribute.doubleByte == 0 {
                        endCol += 1
                    } else {
                        break
                    }
                }
                _selectionLocation = Int32(r * gColumn + startCol)
                _selectionLength = Int32(endCol - startCol + 1)
            } else {
                _selectionLength = 1
            }
        }
        
        needsDisplay = true
        
        // Click to move cursor
        if isCmdPressed && connected() {
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
            let detectDoubleByte = frontMostConnection()?.site?.detectDoubleByte ?? YLLGlobalConfig.sharedInstance().detectDoubleByte
            let shouldDoubleStep = (ds.encoding != .YLUTF8Encoding) && detectDoubleByte
            
            let sendRight = {
                cmd.append(contentsOf: [0x1B, 0x4F, 0x43]) // Right arrow 'C'
            }
            let sendLeft = {
                cmd.append(contentsOf: [0x1B, 0x4F, 0x44]) // Left arrow 'D'
            }
            
            if home {
                for i in 0..<moveToCol {
                    if currRow[i].attr.terminalAttribute.doubleByte != 2 || shouldDoubleStep {
                        sendRight()
                    }
                }
            } else if moveToCol > cursorColumn {
                for i in cursorColumn..<moveToCol {
                    if currRow[i].attr.terminalAttribute.doubleByte != 2 || shouldDoubleStep {
                        sendRight()
                    }
                }
            } else if moveToCol < cursorColumn {
                for i in moveToCol..<cursorColumn {
                    if currRow[i].attr.terminalAttribute.doubleByte != 2 || shouldDoubleStep {
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
        guard frontMostTerminal() != nil else { return }
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
        guard frontMostTerminal() != nil else { return }
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
                    
                    let isDirectImage = URL(string: url).map { YLContextualMenuManager.sharedInstance.isImageURL($0) } ?? false
                    if url.count < 30 && url.lowercased().hasPrefix("https://") && !isDirectImage {
                        resolveShortUrl(url)
                    } else {
                        loadUrl(of: url)
                    }
                }
            }
        }
    }
    
    // MARK: - Cmd + Hover Quick URL Preview
    public override func mouseMoved(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        evaluateCmdHoverPreview(at: pt, modifierFlags: event.modifierFlags)
        super.mouseMoved(with: event)
    }
    
    public override func mouseExited(with event: NSEvent) {
        cancelPendingHoverPreview()
        super.mouseExited(with: event)
    }
    
    public override func scrollWheel(with event: NSEvent) {
        guard YLLGlobalConfig.sharedInstance().enableMouseWheelScroll,
              connected(),
              let conn = frontMostConnection() else {
            super.scrollWheel(with: event)
            return
        }
        
        if event.phase == .began || event.phase == .ended || event.phase == .cancelled {
            scrollDeltaAccumulator = 0.0
        }
        
        let steps: Int
        if event.hasPreciseScrollingDeltas {
            guard event.momentumPhase.isEmpty else { return }
            scrollDeltaAccumulator += event.scrollingDeltaY
            let threshold = max(16.0, _fontHeight)
            let rawSteps = Int(scrollDeltaAccumulator / threshold)
            guard rawSteps != 0 else { return }
            scrollDeltaAccumulator -= CGFloat(rawSteps) * threshold
            steps = max(-5, min(5, rawSteps))
        } else {
            if event.scrollingDeltaY > 0 {
                steps = 1
            } else if event.scrollingDeltaY < 0 {
                steps = -1
            } else {
                return
            }
        }
        
        handleScrollSteps(steps, on: conn)
    }
    
    func handleScrollSteps(_ steps: Int, on connection: YLConnection) {
        guard steps != 0 else { return }
        let arrowSeq: [UInt8] = steps > 0 ? [0x1B, 0x4F, 0x41] : [0x1B, 0x4F, 0x42]
        let count = min(5, abs(steps))
        var payload = [UInt8]()
        payload.reserveCapacity(count * 3)
        for _ in 0..<count {
            payload.append(contentsOf: arrowSeq)
        }
        connection.sendBytes(&payload, length: payload.count)
    }
    
    func evaluateCmdHoverPreview(at pointInView: NSPoint, modifierFlags: NSEvent.ModifierFlags) {
        let config = YLLGlobalConfig.sharedInstance()
        let hoverEnabled = (UserDefaults.standard.object(forKey: "EnableCmdHoverPreview") as? Bool) ?? true
        guard config.shouldPreferImagePreviewer,
              hoverEnabled,
              modifierFlags.contains(.command),
              bounds.contains(pointInView),
              let ds = frontMostTerminal() else {
            cancelPendingHoverPreview()
            return
        }
        
        let gColumn = Int(config.column)
        let gRow = Int(config.row)
        guard gColumn > 0 && gRow > 0 else { return }
        
        let index = convertIndex(from: pointInView)
        let row = index / gColumn
        let col = index % gColumn
        
        guard let urlStr = ds.urlString(atRow: Int32(row), column: Int32(col)),
              let url = URL(string: urlStr),
              url.scheme?.lowercased() == "https",
              YLContextualMenuManager.sharedInstance.isImageURL(url) else {
            cancelPendingHoverPreview()
            return
        }
        
        if hoveredPreviewURL == urlStr,
           hoverPreviewTask != nil || (hoverPreviewer?.isPresented ?? false) {
            return
        }
        
        hoverPreviewTask?.cancel()
        hoveredPreviewURL = urlStr
        
        let anchorRect = NSRect(
            x: CGFloat(col) * _fontWidth,
            y: CGFloat(gRow - 1 - row) * _fontHeight,
            width: _fontWidth,
            height: _fontHeight
        )
        
        hoverPreviewTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard let self = self,
                  !Task.isCancelled,
                  self.hoveredPreviewURL == urlStr else {
                return
            }
            self.hoverPreviewTask = nil
            self.presentHoverPreview(for: url, anchorRect: anchorRect)
        }
    }
    
    func presentHoverPreview(for url: URL, anchorRect: NSRect) {
        let previewer = YLImagePreviewer(url: url, allowBrowserFallback: false)
        self.hoverPreviewer = previewer
        let style = UserDefaults.standard.string(forKey: "ImagePreviewStyle") ?? "popover"
        if style == "window" {
            previewer.showLoadingWindow()
        } else {
            previewer.showPopover(relativeTo: anchorRect, of: self, preferredEdge: .minY)
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
        guard frontMostTerminal() != nil else { return menu }
        
        let selected = selectedPlainString() ?? ""
        let contextualItems = YLContextualMenuManager.sharedInstance.availableMenuItemForSelectionString(selected)
        for item in contextualItems {
            menu.addItem(item)
        }
        
        if selected.isEmpty && connected(), NSPasteboard.general.string(forType: .string) != nil {
            if !menu.items.isEmpty {
                menu.addItem(NSMenuItem.separator())
            }
            let pasteItem = NSMenuItem(title: NSLocalizedString("Paste", comment: "Menu"), action: #selector(paste(_:)), keyEquivalent: "")
            pasteItem.target = self
            menu.addItem(pasteItem)
            
            let pasteWrapItem = NSMenuItem(title: NSLocalizedString("Paste Wrap", comment: "Menu"), action: #selector(pasteWrap(_:)), keyEquivalent: "")
            pasteWrapItem.target = self
            menu.addItem(pasteWrapItem)
        }
        
        return menu
    }
}
