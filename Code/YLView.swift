import Cocoa
import CoreText
import CoreGraphics

@objc(YLView)
@objcMembers
public class YLView: NSView {
    // Custom lightweight Tab Item container (replacing NSTabView inheritance)
    public var tabViewItems: [NSTabViewItem] = []
    public var selectedTabViewItem: NSTabViewItem?
    public weak var delegate: AnyObject?
    // Properties matching YLView.h
    public var _fontWidth: CGFloat = 12.0
    public var _fontHeight: CGFloat = 24.0
    
    public var _bitmapContext: CGContext?
    public var _backedImageCG: CGImage?
    public var _timer: Timer?
    public var _x: Int32 = 0
    public var _y: Int32 = 0
    
    public var _markedText: NSAttributedString?
    public var _selectedRange = NSRange(location: NSNotFound, length: 0)
    public var _markedRange = NSRange(location: NSNotFound, length: 0)
    
    public var _textField: YLMarkedTextView?
    
    private let cursorLayer = CALayer()
    private let selectionLayer = CAShapeLayer()
    
    public var _selectionLocation: Int32 = 0 {
        didSet {
            updateSelectionLayer()
        }
    }
    public var _selectionLength: Int32 = 0 {
        didSet {
            updateSelectionLayer()
        }
    }
    
    public var _shouldOpenUrlInBackground: Bool = false
    public var _shouldUseImagePreviewer: Bool = true
    
    // Globals converted to static class variables or instance variables:
    private static var gLeftImage: NSImage?
    
    static let ANSIColorPBoardType = NSPasteboard.PasteboardType("ANSIColorPBoardType")
    
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
    
    static let initializeCursor: NSCursor = {
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
        self.wantsLayer = true
        self.layerContentsRedrawPolicy = .duringViewResize
        setupLayers()
        configure()
        _selectionLength = 0
        _selectionLocation = 0
    }
    
    // MARK: - Tab Item Container Management
    public var numberOfTabViewItems: Int {
        return tabViewItems.count
    }
    
    public func tabViewItem(at index: Int) -> NSTabViewItem {
        return tabViewItems[index]
    }
    
    public func indexOfTabViewItem(_ tabViewItem: NSTabViewItem) -> Int {
        return tabViewItems.firstIndex(of: tabViewItem) ?? NSNotFound
    }
    
    public func addTabViewItem(_ tabViewItem: NSTabViewItem) {
        tabViewItems.append(tabViewItem)
        if selectedTabViewItem == nil {
            selectTabViewItem(tabViewItem)
        }
        notifyDelegateTabCountChanged()
    }
    
    public func removeTabViewItem(_ tabViewItem: NSTabViewItem) {
        guard let index = tabViewItems.firstIndex(of: tabViewItem) else { return }
        notifyDelegateWillClose(tabViewItem)
        let wasSelected = (selectedTabViewItem == tabViewItem)
        tabViewItems.remove(at: index)
        if wasSelected {
            let nextIndex = min(index, tabViewItems.count - 1)
            let nextItem = nextIndex >= 0 ? tabViewItems[nextIndex] : nil
            selectTabViewItem(nextItem)
        } else {
            if let current = selectedTabViewItem, let conn = current.identifier as? YLConnection {
                conn.terminal?.setAllDirty()
                updateBackedImage()
                needsDisplay = true
            }
        }
        notifyDelegateDidClose(tabViewItem)
        notifyDelegateTabCountChanged()
    }
    
    public func moveTab(fromIndex: Int, toIndex: Int) {
        guard fromIndex >= 0 && fromIndex < tabViewItems.count,
              toIndex >= 0 && toIndex < tabViewItems.count,
              fromIndex != toIndex else { return }
        let item = tabViewItems.remove(at: fromIndex)
        tabViewItems.insert(item, at: toIndex)
        notifyDelegateTabCountChanged()
    }
    
    public func selectTabViewItem(_ tabViewItem: NSTabViewItem?) {
        guard let item = tabViewItem else {
            selectedTabViewItem = nil
            updateBackedImage()
            needsDisplay = true
            return
        }
        guard tabViewItems.contains(item) else { return }
        if let del = delegate as? YLController {
            if !del.tabView(self, shouldSelect: item) { return }
            del.tabView(self, willSelect: item)
            selectedTabViewItem = item
            del.tabView(self, didSelect: item)
        } else {
            selectedTabViewItem = item
        }
        (item.identifier as? YLConnection)?.terminal?.setAllDirty()
        updateBackedImage()
        needsDisplay = true
    }
    
    public func selectTabViewItem(at index: Int) {
        guard index >= 0 && index < tabViewItems.count else { return }
        selectTabViewItem(tabViewItems[index])
    }
    
    public func selectFirstTabViewItem(_ sender: Any?) {
        guard !tabViewItems.isEmpty else { return }
        selectTabViewItem(tabViewItems.first)
    }
    
    public func selectLastTabViewItem(_ sender: Any?) {
        guard !tabViewItems.isEmpty else { return }
        selectTabViewItem(tabViewItems.last)
    }
    
    public func selectNextTabViewItem(_ sender: Any?) {
        guard let current = selectedTabViewItem,
              let index = tabViewItems.firstIndex(of: current),
              index + 1 < tabViewItems.count else { return }
        selectTabViewItem(tabViewItems[index + 1])
    }
    
    public func selectPreviousTabViewItem(_ sender: Any?) {
        guard let current = selectedTabViewItem,
              let index = tabViewItems.firstIndex(of: current),
              index - 1 >= 0 else { return }
        selectTabViewItem(tabViewItems[index - 1])
    }
    
    private func notifyDelegateTabCountChanged() {
        if let del = delegate as? YLController {
            del.tabViewDidChangeNumberOfTabViewItems(self)
        }
    }
    
    private func notifyDelegateWillClose(_ item: NSTabViewItem) {
        if let del = delegate as? YLController {
            del.tabView(self, willClose: item)
        }
    }
    
    private func notifyDelegateDidClose(_ item: NSTabViewItem) {
        if let del = delegate as? YLController {
            del.tabView(self, didClose: item)
        }
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
        
        recreateBitmapContext(width: Int(frame.size.width), height: Int(frame.size.height))
        
        YLView.gLeftImage = NSImage(size: NSMakeSize(_fontWidth, _fontHeight))
        
        _markedText = nil
        _selectedRange = NSRange(location: NSNotFound, length: 0)
        _markedRange = NSRange(location: NSNotFound, length: 0)
        _textField?.isHidden = true
        
        setupLayers()
        selectionLayer.frame = bounds
        updateCursorLayer()
        updateSelectionLayer()
    }
    
    private func recreateBitmapContext(width: Int, height: Int) {
        guard width > 0 && height > 0 else { return }
        let scale = self.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
        let pixelWidth = Int(CGFloat(width) * scale)
        let pixelHeight = Int(CGFloat(height) * scale)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        
        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: pixelWidth * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return
        }
        
        context.scaleBy(x: scale, y: scale)
        
        let config = YLLGlobalConfig.sharedInstance()
        let bgColor = config.colorBG ?? NSColor.black
        context.setFillColor(bgColor.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        
        self._bitmapContext = context
        self._backedImageCG = context.makeImage()
    }
    
    // MARK: - Actions (See YLView+Actions.swift)
    
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
        
        let isImage = YLContextualMenuManager.sharedInstance.isImageURL(url)
        if isImage && _shouldUseImagePreviewer {
            let previewer = YLImagePreviewer(url: url)
            let style = UserDefaults.standard.string(forKey: "ImagePreviewStyle") ?? "popover"
            if style == "popover" {
                let centerRect = NSRect(x: bounds.midX, y: bounds.midY, width: 1, height: 1)
                previewer.showPopover(relativeTo: centerRect, of: self, preferredEdge: .minY)
            } else {
                previewer.showLoadingWindow()
            }
        } else {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = !_shouldOpenUrlInBackground
            NSWorkspace.shared.open(url, configuration: configuration, completionHandler: nil)
        }
    }
    
    func resolveShortUrl(_ urlString: String) {
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
    
    // MARK: - Drawing Helpers
    @objc public func displayCellAtRow(_ r: Int32, column c: Int32) {
        let config = YLLGlobalConfig.sharedInstance()
        let gRow = Int(config.row)
        setNeedsDisplay(NSMakeRect(CGFloat(c) * _fontWidth, CGFloat(gRow - 1 - Int(r)) * _fontHeight, _fontWidth, _fontHeight))
    }
    
    @objc public func tick() {
        autoreleasepool {
            updateBackedImage()
            updateCursorLayer()
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
            guard let context = NSGraphicsContext.current?.cgContext else { return }
            let config = YLLGlobalConfig.sharedInstance()
            let gRow = Int(config.row)
            let gColumn = Int(config.column)
            
            if connected() {
                if let img = _backedImageCG {
                    context.draw(img, in: bounds)
                }
                
                drawBlink(in: context)
                
                // Draw the url underline
                if let ds = frontMostTerminal() {
                    context.setStrokeColor(NSColor.orange.cgColor)
                    context.setLineWidth(1.0)
                    for r in 0..<gRow {
                        guard let currRow = ds.cells(ofRow: Int32(r)) else { continue }
                        var c = 0
                        while c < gColumn {
                            let start = c
                            while c < gColumn && currRow[c].attr.terminalAttribute.url {
                                c += 1
                            }
                            if c != start {
                                context.beginPath()
                                context.move(to: CGPoint(x: CGFloat(start) * _fontWidth, y: CGFloat(gRow - r - 1) * _fontHeight + 0.5))
                                context.addLine(to: CGPoint(x: CGFloat(c) * _fontWidth, y: CGFloat(gRow - r - 1) * _fontHeight + 0.5))
                                context.strokePath()
                            }
                            c += 1
                        }
                    }
                    
                    _x = ds.cursorColumn
                    _y = ds.cursorRow
                }
            } else {
                let bgColor = config.colorBG ?? NSColor.black
                context.setFillColor(bgColor.cgColor)
                context.fill(bounds)
            }
        }
    }
    
    public func drawBlink(in context: CGContext) {
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
                    
                    let color = config.colorAtIndex(Int32(bgColorIndex), hilite: bold)
                    context.setFillColor(color.cgColor)
                    let rect = CGRect(x: CGFloat(c) * _fontWidth, y: CGFloat(gRow - r - 1) * _fontHeight, width: _fontWidth, height: _fontHeight)
                    context.fill(rect)
                }
            }
        }
    }

    
    @objc(extendBottomFrom:to:)
    public func extendBottom(from start: Int32, to end: Int32) {
        let config = YLLGlobalConfig.sharedInstance()
        let gRow = Int(config.row)
        let gColumn = Int(config.column)
        
        guard let context = _bitmapContext, let data = context.data else { return }
        let scale = self.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
        let bytesPerRow = context.bytesPerRow
        
        let srcYPoints = CGFloat(gRow - Int(end) - 1) * _fontHeight
        let destYPoints = CGFloat(gRow - Int(end)) * _fontHeight
        let copyHeightPoints = CGFloat(end - start) * _fontHeight
        
        let srcY = Int(srcYPoints * scale)
        let destY = Int(destYPoints * scale)
        let copyHeight = Int(copyHeightPoints * scale)
        
        let srcOffset = srcY * bytesPerRow
        let destOffset = destY * bytesPerRow
        let count = copyHeight * bytesPerRow
        
        let totalBytes = context.height * bytesPerRow
        if srcOffset + count <= totalBytes && destOffset + count <= totalBytes {
            memmove(data.advanced(by: destOffset), data.advanced(by: srcOffset), count)
        }
        
        let color = config.colorAtIndex(config.bgColorIndex, hilite: false)
        context.setFillColor(color.cgColor)
        let cleanY = CGFloat(gRow - Int(end) - 1) * _fontHeight
        context.fill(CGRect(x: 0.0, y: cleanY, width: CGFloat(gColumn) * _fontWidth, height: _fontHeight))
        
        self._backedImageCG = context.makeImage()
        self.needsDisplay = true
    }
    
    @objc(extendTopFrom:to:)
    public func extendTop(from start: Int32, to end: Int32) {
        let config = YLLGlobalConfig.sharedInstance()
        let gRow = Int(config.row)
        let gColumn = Int(config.column)
        
        guard let context = _bitmapContext, let data = context.data else { return }
        let scale = self.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
        let bytesPerRow = context.bytesPerRow
        
        let srcYPoints = CGFloat(gRow - Int(end)) * _fontHeight
        let destYPoints = CGFloat(gRow - Int(end) - 1) * _fontHeight
        let copyHeightPoints = CGFloat(end - start) * _fontHeight
        
        let srcY = Int(srcYPoints * scale)
        let destY = Int(destYPoints * scale)
        let copyHeight = Int(copyHeightPoints * scale)
        
        let srcOffset = srcY * bytesPerRow
        let destOffset = destY * bytesPerRow
        let count = copyHeight * bytesPerRow
        
        let totalBytes = context.height * bytesPerRow
        if srcOffset + count <= totalBytes && destOffset + count <= totalBytes {
            memmove(data.advanced(by: destOffset), data.advanced(by: srcOffset), count)
        }
        
        let color = config.colorAtIndex(config.bgColorIndex, hilite: false)
        context.setFillColor(color.cgColor)
        let cleanY = CGFloat(gRow - Int(start) - 1) * _fontHeight
        context.fill(CGRect(x: 0.0, y: cleanY, width: CGFloat(gColumn) * _fontWidth, height: _fontHeight))
        
        self._backedImageCG = context.makeImage()
        self.needsDisplay = true
    }
    
    @objc public func updateBackedImage() {
        let config = YLLGlobalConfig.sharedInstance()
        let gRow = Int(config.row)
        let gColumn = Int(config.column)
        
        guard let context = _bitmapContext else { return }
        
        guard let ds = frontMostTerminal() else {
            context.setFillColor(NSColor.clear.cgColor)
            let rect = CGRect(x: 0, y: 0, width: CGFloat(gColumn) * _fontWidth, height: CGFloat(gRow) * _fontHeight)
            context.fill(rect)
            self._backedImageCG = context.makeImage()
            self.needsDisplay = true
            self.updateCursorLayer()
            self.updateSelectionLayer()
            return
        }
        

        let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.current = graphicsContext
        
        if let activeCtx = NSGraphicsContext.current?.cgContext {
            /* Draw Background */
            var y = 0
            while y < gRow {
                if ds.isRowDirty(Int32(y)) {
                    var x = 0
                    while x < gColumn {
                        if ds.isDirty(atRow: Int32(y), column: Int32(x)) {
                            let startx = x
                            while x < gColumn && ds.isDirty(atRow: Int32(y), column: Int32(x)) {
                                x += 1
                            }
                            updateBackground(forRow: Int32(y), from: Int32(startx), to: Int32(x), context: activeCtx)
                        }
                        x += 1
                    }
                }
                y += 1
            }
        }
        
        context.saveGState()
        context.setShouldSmoothFonts(config.shouldSmoothFonts)
        
        /* Draw String row by row ONLY for dirty rows */
        for r in 0..<gRow {
            if ds.isRowDirty(Int32(r)) {
                drawString(forRow: Int32(r), context: context)
            }
        }
        context.restoreGState()
        
        for r in 0..<gRow {
            if ds.isRowDirty(Int32(r)) {
                for c in 0..<gColumn {
                    ds.setDirty(false, atRow: Int32(r), column: Int32(c))
                }
                ds.clearRowDirty(Int32(r))
            }
        }
        
        self._backedImageCG = context.makeImage()
        self.needsDisplay = true
        self.updateCursorLayer()
        self.updateSelectionLayer()
    }
    
    // MARK: - Overrides
    public override var acceptsFirstResponder: Bool {
        return true
    }
    
    public override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        configure()
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
    
    // MARK: - Internal Helpers
    func isEnglishNumberAlphabet(_ c: UInt8) -> Bool {
        return (UInt8(ascii: "0") <= c && c <= UInt8(ascii: "9")) ||
               (UInt8(ascii: "A") <= c && c <= UInt8(ascii: "Z")) ||
               (UInt8(ascii: "a") <= c && c <= UInt8(ascii: "z")) ||
               (c == UInt8(ascii: "-")) ||
               (c == UInt8(ascii: "_")) ||
               (c == UInt8(ascii: "."))
    }
    
    // MARK: - Layer Optimization
    private func setupLayers() {
        guard let mainLayer = self.layer else { return }
        
        mainLayer.sublayers?.forEach {
            if $0 === cursorLayer || $0 === selectionLayer {
                $0.removeFromSuperlayer()
            }
        }
        
        // Disable actions (implicit animations) on these layers by default
        selectionLayer.actions = ["onOrderIn": NSNull(), "onOrderOut": NSNull(), "sublayers": NSNull(), "contents": NSNull(), "bounds": NSNull(), "position": NSNull(), "path": NSNull()]
        cursorLayer.actions = ["onOrderIn": NSNull(), "onOrderOut": NSNull(), "sublayers": NSNull(), "contents": NSNull(), "bounds": NSNull(), "position": NSNull()]
        
        // Selection layer
        selectionLayer.fillColor = NSColor(calibratedRed: 0.6, green: 0.9, blue: 0.6, alpha: 0.4).cgColor
        selectionLayer.strokeColor = nil
        selectionLayer.frame = mainLayer.bounds
        selectionLayer.isHidden = true
        mainLayer.addSublayer(selectionLayer)
        
        // Cursor layer
        cursorLayer.backgroundColor = NSColor.white.cgColor
        cursorLayer.frame = .zero
        cursorLayer.isHidden = true
        mainLayer.addSublayer(cursorLayer)
    }
    
    public func updateCursorLayer() {
        if Thread.isMainThread {
            self.performUpdateCursorLayer()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.performUpdateCursorLayer()
            }
        }
    }
    
    private func performUpdateCursorLayer() {
        guard let ds = frontMostTerminal() else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            cursorLayer.isHidden = true
            CATransaction.commit()
            return
        }
        let config = YLLGlobalConfig.sharedInstance()
        let gRow = Int(config.row)
        
        let cursorX = CGFloat(ds.cursorColumn) * _fontWidth
        let cursorY = CGFloat(gRow - 1 - Int(ds.cursorRow)) * _fontHeight + 1
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        cursorLayer.frame = CGRect(x: cursorX, y: cursorY, width: _fontWidth, height: 2.0)
        cursorLayer.isHidden = false
        _x = ds.cursorColumn
        _y = ds.cursorRow
        CATransaction.commit()
    }
    
    public func updateSelectionLayer() {
        if Thread.isMainThread {
            self.performUpdateSelectionLayer()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.performUpdateSelectionLayer()
            }
        }
    }
    
    private func performUpdateSelectionLayer() {
        guard frontMostTerminal() != nil, _selectionLength != 0 else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            selectionLayer.path = nil
            selectionLayer.isHidden = true
            CATransaction.commit()
            return
        }
        let config = YLLGlobalConfig.sharedInstance()
        let gRow = Int(config.row)
        let gColumn = Int(config.column)
        
        var location = Int(_selectionLocation)
        var length = Int(_selectionLength)
        
        if length < 0 {
            location += length
            length = -length
        }
        var x = location % gColumn
        var y = location / gColumn
        
        let path = CGMutablePath()
        while length > 0 {
            if x + length <= gColumn {
                let rect = CGRect(x: CGFloat(x) * _fontWidth, y: CGFloat(gRow - y - 1) * _fontHeight, width: _fontWidth * CGFloat(length), height: _fontHeight)
                path.addRect(rect)
                length = 0
            } else {
                let rect = CGRect(x: CGFloat(x) * _fontWidth, y: CGFloat(gRow - y - 1) * _fontHeight, width: _fontWidth * CGFloat(gColumn - x), height: _fontHeight)
                path.addRect(rect)
                length -= (gColumn - x)
            }
            x = 0
            y += 1
        }
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        selectionLayer.path = path
        selectionLayer.isHidden = false
        CATransaction.commit()
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
