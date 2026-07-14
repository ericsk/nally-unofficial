import Cocoa
import CoreText
import CoreGraphics

extension YLView {
    
    private func isSpecialSymbol(_ ch: unichar) -> Bool {
        if ch == 0x25FC { return true } // ◼ BLACK SQUARE
        if ch >= 0x2581 && ch <= 0x2588 { return true } // BLOCK ▁▂▃▄▅▆▇█
        if ch >= 0x2589 && ch <= 0x258F { return true } // BLOCK ▉▊▋▌▍▎▏
        if ch >= 0x25E2 && ch <= 0x25E5 { return true } // TRIANGLE ◢◣◤◥
        return false
    }
    
    private func getTrianglePath(index: Int) -> NSBezierPath {
        let pts = [
            NSPoint(x: fontWidth, y: 0.0),
            NSPoint(x: 0.0, y: 0.0),
            NSPoint(x: 0.0, y: fontHeight),
            NSPoint(x: fontWidth, y: fontHeight),
            NSPoint(x: fontWidth * 2, y: fontHeight),
            NSPoint(x: fontWidth * 2, y: 0.0),
        ]
        let triangleIndex = [ [1, 4, 5], [1, 2, 5], [1, 2, 4], [2, 4, 5] ]
        let path = NSBezierPath()
        path.move(to: pts[triangleIndex[index][0]])
        path.line(to: pts[triangleIndex[index][1]])
        path.line(to: pts[triangleIndex[index][2]])
        path.close()
        return path
    }
    
    private func getTrianglePathsDoubleColor(index: Int) -> (NSBezierPath, NSBezierPath) {
        let pts = [
            NSPoint(x: fontWidth, y: 0.0),
            NSPoint(x: 0.0, y: 0.0),
            NSPoint(x: 0.0, y: fontHeight),
            NSPoint(x: fontWidth, y: fontHeight),
            NSPoint(x: fontWidth * 2, y: fontHeight),
            NSPoint(x: fontWidth * 2, y: 0.0),
        ]
        let triangleIndex1 = [ [0, 1, -1], [0, 1, 2], [1, 2, 3], [2, 3, -1] ]
        let triangleIndex2 = [ [4, 5, 0], [5, 0, -1], [3, 4, -1], [3, 4, 5] ]
        
        let path1 = NSBezierPath()
        path1.move(to: NSPoint(x: fontWidth, y: fontHeight / 2.0))
        for i in 0..<3 {
            let idx = triangleIndex1[index][i]
            if idx >= 0 {
                path1.line(to: pts[idx])
            }
        }
        path1.close()
        
        let path2 = NSBezierPath()
        path2.move(to: NSPoint(x: fontWidth, y: fontHeight / 2.0))
        for i in 0..<3 {
            let idx = triangleIndex2[index][i]
            if idx >= 0 {
                path2.line(to: pts[idx])
            }
        }
        path2.close()
        
        return (path1, path2)
    }

    @objc(drawStringForRow:context:)
    public func drawString(forRow r: Int32, context myCGContext: CGContext) {
        guard let ds = self.frontMostTerminal() else { return }
        let config = YLLGlobalConfig.sharedInstance()
        let gRow = Int(config.row)
        let gColumn = Int(config.column)
        
        let ePaddingLeft = config.englishFontPaddingLeft
        let ePaddingBottom = config.englishFontPaddingBottom
        let cPaddingLeft = config.chineseFontPaddingLeft
        let cPaddingBottom = config.chineseFontPaddingBottom
        
        let termEncoding = ds.encoding
        ds.updateDoubleByteState(forRow: r)
        
        guard let currRow = ds.cells(ofRow: r) else { return }
        
        // Find the first dirty position in this row
        var x = 0
        while x < gColumn && !ds.isDirty(atRow: r, column: Int32(x)) {
            x += 1
        }
        if x == gColumn { return }
        
        let start = x
        var end = x
        
        var textBuf = [unichar](repeating: 0, count: gColumn)
        var isDoubleByte = [Bool](repeating: false, count: gColumn)
        var isDoubleColor = [Bool](repeating: false, count: gColumn)
        var bufIndex = [Int](repeating: 0, count: gColumn)
        var position = [CGPoint](repeating: .zero, count: gColumn)
        var bufLength = 0
        
        // Update the information array
        x = start
        while x < gColumn {
            if !ds.isDirty(atRow: r, column: Int32(x)) {
                x += 1
                continue
            }
            end = x
            let db = doubleByteOfAttribute(currRow[x].attr)
            
            if db == 0 {
                isDoubleByte[bufLength] = false
                let b = currRow[x].byte
                textBuf[bufLength] = UInt16(b == 0 ? UInt8(ascii: " ") : b)
                bufIndex[bufLength] = x
                position[bufLength] = CGPoint(
                    x: CGFloat(x) * fontWidth + ePaddingLeft,
                    y: CGFloat(gRow - 1 - Int(r)) * fontHeight + CTFontGetDescent(config.englishCTFont!) + ePaddingBottom
                )
                isDoubleColor[bufLength] = false
                bufLength += 1
            } else if db == 1 {
                // Continue
            } else if db == 2 {
                let leftByte = UInt16(currRow[x - 1].byte)
                let rightByte = UInt16(currRow[x].byte)
                let code = (leftByte << 8) + rightByte - 0x8000
                let ch = (termEncoding == .YLBig5Encoding) ? lookupBig5(code) : lookupGBK(code)
                
                if isSpecialSymbol(ch) {
                    self.drawSpecialSymbol(ch, forRow: r, column: Int32(x - 1), leftAttribute: currRow[x - 1].attr, rightAttribute: currRow[x].attr)
                } else {
                    let attrLeft = currRow[x - 1].attr
                    let attrRight = currRow[x].attr
                    isDoubleColor[bufLength] = (fgColorIndexOfAttribute(attrLeft) != fgColorIndexOfAttribute(attrRight) ||
                                                fgBoldOfAttribute(attrLeft) != fgBoldOfAttribute(attrRight))
                    isDoubleByte[bufLength] = true
                    textBuf[bufLength] = ch
                    bufIndex[bufLength] = x
                    position[bufLength] = CGPoint(
                        x: CGFloat(x - 1) * fontWidth + cPaddingLeft,
                        y: CGFloat(gRow - 1 - Int(r)) * fontHeight + CTFontGetDescent(config.chineseCTFont!) + cPaddingBottom
                    )
                    bufLength += 1
                }
                
                if x == start {
                    self.setNeedsDisplay(CGRect(
                        x: CGFloat(x - 1) * fontWidth,
                        y: CGFloat(gRow - 1 - Int(r)) * fontHeight,
                        width: fontWidth,
                        height: fontHeight
                    ))
                }
            }
            x += 1
        }
        
        if bufLength == 0 { return }
        
        guard let str = CFStringCreateWithCharacters(kCFAllocatorDefault, textBuf, bufLength),
              let attributedString = CFAttributedStringCreate(kCFAllocatorDefault, str, nil),
              let mutableAttributedString = CFAttributedStringCreateMutableCopy(kCFAllocatorDefault, 0, attributedString) else {
            return
        }
        
        // Run-length of the style
        var c = 0
        while c < bufLength {
            let location = c
            let db = isDoubleByte[c]
            let lastAttr = currRow[bufIndex[c]].attr
            
            while c < bufLength {
                let currAttr = currRow[bufIndex[c]].attr
                if currAttr.v != lastAttr.v || isDoubleByte[c] != db {
                    break
                }
                c += 1
            }
            let length = c - location
            
            let attr: CFDictionary
            if db {
                attr = config.chineseAttribute(withHilite: Int(fgBoldOfAttribute(lastAttr)), index: Int(fgColorIndexOfAttribute(lastAttr)))!
            } else {
                attr = config.englishAttribute(withHilite: Int(fgBoldOfAttribute(lastAttr)), index: Int(fgColorIndexOfAttribute(lastAttr)))!
            }
            CFAttributedStringSetAttributes(mutableAttributedString, CFRangeMake(location, length), attr, true)
        }
        
        let line = CTLineCreateWithAttributedString(mutableAttributedString)
        let glyphCount = CTLineGetGlyphCount(line)
        if glyphCount == 0 {
            return
        }
        
        let runArray = CTLineGetGlyphRuns(line)
        let runCount = CFArrayGetCount(runArray)
        var glyphOffset = 0
        
        var runIndex = 0
        while runIndex < runCount {
            let run = unsafeBitCast(CFArrayGetValueAtIndex(runArray, runIndex), to: CTRun.self)
            let runGlyphCount = CTRunGetGlyphCount(run)
            
            let attrDict = CTRunGetAttributes(run)
            let runFont = unsafeBitCast(CFDictionaryGetValue(attrDict, Unmanaged.passUnretained(kCTFontAttributeName).toOpaque()), to: CTFont.self)
            let cgFont = CTFontCopyGraphicsFont(runFont, nil)
            let runColor = unsafeBitCast(CFDictionaryGetValue(attrDict, Unmanaged.passUnretained(kCTForegroundColorAttributeName).toOpaque()), to: NSColor.self)
            
            myCGContext.setFont(cgFont)
            myCGContext.setFontSize(CTFontGetSize(runFont))
            myCGContext.setFillColor(red: runColor.redComponent, green: runColor.greenComponent, blue: runColor.blueComponent, alpha: 1.0)
            myCGContext.setStrokeColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            myCGContext.setLineWidth(1.0)
            
            var location = 0
            var lastIndex = bufIndex[glyphOffset]
            var hidden = isHiddenAttribute(currRow[lastIndex].attr) != 0
            var lastDoubleByte = isDoubleByte[glyphOffset]
            
            var runGlyphIndex = 0
            while runGlyphIndex <= runGlyphCount {
                let index = (runGlyphIndex == runGlyphCount) ? lastIndex : bufIndex[glyphOffset + runGlyphIndex]
                
                let isAtEnd = (runGlyphIndex == runGlyphCount)
                let showHiddenText = config.showHiddenText
                let isHiddenAtIdx = !isAtEnd && isHiddenAttribute(currRow[index].attr) != 0
                
                let cond1 = isAtEnd
                let cond2 = showHiddenText && (isHiddenAtIdx != hidden)
                let cond3 = !isAtEnd && isDoubleByte[runGlyphIndex + glyphOffset] && (index != lastIndex + 2)
                let cond4 = !isAtEnd && !isDoubleByte[runGlyphIndex + glyphOffset] && (index != lastIndex + 1)
                let cond5 = !isAtEnd && (isDoubleByte[runGlyphIndex + glyphOffset] != lastDoubleByte)
                
                if cond1 || cond2 || cond3 || cond4 || cond5 {
                    if !isAtEnd {
                        lastDoubleByte = isDoubleByte[runGlyphIndex + glyphOffset]
                    }
                    let len = runGlyphIndex - location
                    
                    myCGContext.setTextDrawingMode((showHiddenText && hidden) ? .stroke : .fill)
                    
                    var glyphs = [CGGlyph](repeating: 0, count: len)
                    CTRunGetGlyphs(run, CFRangeMake(location, len), &glyphs)
                    
                    var textMatrix = CTRunGetTextMatrix(run)
                    textMatrix.tx = 0
                    textMatrix.ty = 0
                    myCGContext.textMatrix = textMatrix
                    
                    let glyphPositions = Array(position[(glyphOffset + location)..<(glyphOffset + location + len)])
                    myCGContext.showGlyphs(glyphs, at: glyphPositions)
                    
                    location = runGlyphIndex
                    if !isAtEnd {
                        hidden = isHiddenAttribute(currRow[index].attr) != 0
                    }
                }
                lastIndex = index
                runGlyphIndex += 1
            }
            
            // Double Color
            for runGlyphIndex in 0..<runGlyphCount {
                if isDoubleColor[glyphOffset + runGlyphIndex] {
                    var glyph = CGGlyph()
                    CTRunGetGlyphs(run, CFRangeMake(runGlyphIndex, 1), &glyph)
                    
                    let index = bufIndex[glyphOffset + runGlyphIndex] - 1
                    let attr = currRow[index].attr
                    let bgColor = UInt32(bgColorIndexOfAttribute(attr))
                    let fgColor = UInt32(fgColorIndexOfAttribute(attr))
                    
                    myCGContext.saveGState()
                    
                    // 1. Clip to the left cell bounds
                    let cellRect = CGRect(
                        x: CGFloat(index) * fontWidth,
                        y: CGFloat(gRow - 1 - Int(r)) * fontHeight,
                        width: fontWidth,
                        height: fontHeight
                    )
                    myCGContext.clip(to: cellRect)
                    
                    // 2. Fill background color
                    let bgNSColor = config.colorAtIndex(Int32(bgColor), hilite: bgBoldOfAttribute(attr) != 0)
                    myCGContext.setFillColor(bgNSColor.cgColor)
                    myCGContext.fill(cellRect)
                    
                    // 3. Set foreground color and font
                    let fgNSColor = config.colorAtIndex(Int32(fgColor), hilite: fgBoldOfAttribute(attr) != 0)
                    myCGContext.setFillColor(fgNSColor.cgColor)
                    myCGContext.setFont(cgFont)
                    myCGContext.setFontSize(CTFontGetSize(runFont))
                    myCGContext.setShouldSmoothFonts(config.shouldSmoothFonts)
                    
                    // 4. Set text matrix and draw the glyph at the double-byte character's origin
                    var textMatrix = CTRunGetTextMatrix(run)
                    textMatrix.tx = 0
                    textMatrix.ty = 0
                    myCGContext.textMatrix = textMatrix
                    
                    let originPoint = CGPoint(
                        x: CGFloat(index) * fontWidth + cPaddingLeft,
                        y: CGFloat(gRow - 1 - Int(r)) * fontHeight + CTFontGetDescent(config.chineseCTFont!) + cPaddingBottom
                    )
                    myCGContext.showGlyphs([glyph], at: [originPoint])
                    
                    myCGContext.restoreGState()
                }
            }
            
            glyphOffset += runGlyphCount
            runIndex += 1
        }
        
        // Underline
        var underlineX = start
        while underlineX <= end {
            if underlineOfAttribute(currRow[underlineX].attr) != 0 {
                let beginColor = fgColorIndexOfAttribute(currRow[underlineX].attr)
                let beginBold = fgBoldOfAttribute(currRow[underlineX].attr) != 0
                let begin = underlineX
                
                underlineX += 1
                while underlineX <= end {
                    let currColor = fgColorIndexOfAttribute(currRow[underlineX].attr)
                    let currBold = fgBoldOfAttribute(currRow[underlineX].attr) != 0
                    if underlineOfAttribute(currRow[underlineX].attr) == 0 || currColor != beginColor || currBold != beginBold {
                        break
                    }
                    underlineX += 1
                }
                
                let color = config.colorAtIndex(Int32(beginColor), hilite: beginBold)
                color.set()
                let path = NSBezierPath()
                path.lineWidth = 1.0
                path.move(to: NSPoint(x: CGFloat(begin) * fontWidth, y: CGFloat(gRow - 1 - Int(r)) * fontHeight + 0.5))
                path.line(to: NSPoint(x: CGFloat(underlineX) * fontWidth, y: CGFloat(gRow - 1 - Int(r)) * fontHeight + 0.5))
                path.stroke()
                
                underlineX -= 1
            }
            underlineX += 1
        }
    }
    
    @objc(updateBackgroundForRow:from:to:)
    public func updateBackground(forRow r: Int32, from start: Int32, to end: Int32) {
        guard let ds = self.frontMostTerminal() else { return }
        guard let currRow = ds.cells(ofRow: r) else { return }
        let config = YLLGlobalConfig.sharedInstance()
        let gRow = Int(config.row)
        let rowRect = NSRect(
            x: CGFloat(start) * fontWidth,
            y: CGFloat(gRow - 1 - Int(r)) * fontHeight,
            width: CGFloat(end - start) * fontWidth,
            height: fontHeight
        )
        
        var lastAttr = currRow[Int(start)].attr
        var length: Int32 = 0
        var lastBackgroundColor = bgColorIndexOfAttribute(lastAttr)
        var lastBold = bgBoldOfAttribute(lastAttr) != 0
        
        var c = start
        while c <= end {
            let currAttr = currRow[Int(c)].attr
            let currentBackgroundColor = bgColorIndexOfAttribute(currAttr)
            let currentBold = bgBoldOfAttribute(currAttr) != 0
            
            if currentBackgroundColor != lastBackgroundColor || currentBold != lastBold || c == end {
                let rect = NSRect(
                    x: CGFloat(c - length) * fontWidth,
                    y: CGFloat(gRow - 1 - Int(r)) * fontHeight,
                    width: fontWidth * CGFloat(length),
                    height: fontHeight
                )
                let color = config.colorAtIndex(Int32(lastBackgroundColor), hilite: lastBold)
                color.set()
                rect.fill()
                
                length = 1
                lastAttr = currAttr
                lastBackgroundColor = currentBackgroundColor
                lastBold = currentBold
            } else {
                length += 1
            }
            c += 1
        }
        
        self.setNeedsDisplay(rowRect)
    }
    
    @objc(drawSpecialSymbol:forRow:column:leftAttribute:rightAttribute:)
    public func drawSpecialSymbol(_ ch: unichar, forRow r: Int32, column c: Int32, leftAttribute attr1: attribute, rightAttribute attr2: attribute) {
        let config = YLLGlobalConfig.sharedInstance()
        let gRow = Int(config.row)
        let colorIndex1 = fgColorIndexOfAttribute(attr1)
        let colorIndex2 = fgColorIndexOfAttribute(attr2)
        
        let origin = NSPoint(x: CGFloat(c) * fontWidth, y: CGFloat(gRow - 1 - Int(r)) * fontHeight)
        
        let xform = NSAffineTransform()
        xform.translateX(by: origin.x, yBy: origin.y)
        xform.concat()
        
        if colorIndex1 == colorIndex2 && fgBoldOfAttribute(attr1) == fgBoldOfAttribute(attr2) {
            let color = config.colorAtIndex(Int32(colorIndex1), hilite: fgBoldOfAttribute(attr1) != 0)
            color.set()
            
            if ch == 0x25FC { // ◼ BLACK SQUARE
                let gSymbolBlackSquareRect = NSRect(x: 1.0, y: 1.0, width: fontWidth * 2 - 2, height: fontHeight - 2)
                gSymbolBlackSquareRect.fill()
            } else if ch >= 0x2581 && ch <= 0x2588 { // BLOCK ▁▂▃▄▅▆▇█
                let idx = Int(ch - 0x2581)
                let rect = NSRect(x: 0.0, y: 0.0, width: fontWidth * 2, height: fontHeight * CGFloat(idx + 1) / 8.0)
                rect.fill()
            } else if ch >= 0x2589 && ch <= 0x258F { // BLOCK ▉▊▋▌▍▎▏
                let idx = Int(ch - 0x2589)
                let rect = NSRect(x: 0.0, y: 0.0, width: fontWidth * CGFloat(7 - idx) / 4.0, height: fontHeight)
                rect.fill()
            } else if ch >= 0x25E2 && ch <= 0x25E5 { // TRIANGLE ◢◣◤◥
                let idx = Int(ch - 0x25E2)
                let path = getTrianglePath(index: idx)
                path.fill()
            }
        } else { // double color
            let color1 = config.colorAtIndex(Int32(colorIndex1), hilite: fgBoldOfAttribute(attr1) != 0)
            let color2 = config.colorAtIndex(Int32(colorIndex2), hilite: fgBoldOfAttribute(attr2) != 0)
            
            if ch == 0x25FC { // ◼ BLACK SQUARE
                let rect1 = NSRect(x: 1.0, y: 1.0, width: fontWidth - 1, height: fontHeight - 2)
                let rect2 = NSRect(x: fontWidth, y: 1.0, width: fontWidth - 1, height: fontHeight - 2)
                color1.set()
                rect1.fill()
                color2.set()
                rect2.fill()
            } else if ch >= 0x2581 && ch <= 0x2588 { // BLOCK ▁▂▃▄▅▆▇█
                let idx = Int(ch - 0x2581)
                let rect1 = NSRect(x: 0.0, y: 0.0, width: fontWidth, height: fontHeight * CGFloat(idx + 1) / 8.0)
                let rect2 = NSRect(x: fontWidth, y: 0.0, width: fontWidth, height: fontHeight * CGFloat(idx + 1) / 8.0)
                color1.set()
                rect1.fill()
                color2.set()
                rect2.fill()
            } else if ch >= 0x2589 && ch <= 0x258F { // BLOCK ▉▊▋▌▍▎▏
                let idx = Int(ch - 0x2589)
                let rect1 = NSRect(x: 0.0, y: 0.0, width: (7 - idx >= 4) ? fontWidth : (fontWidth * CGFloat(7 - idx) / 4.0), height: fontHeight)
                let rect2 = NSRect(x: fontWidth, y: 0.0, width: (7 - idx <= 4) ? 0.0 : (fontWidth * CGFloat(3 - idx) / 4.0), height: fontHeight)
                color1.set()
                rect1.fill()
                if rect2.width > 0 {
                    color2.set()
                    rect2.fill()
                }
            } else if ch >= 0x25E2 && ch <= 0x25E5 { // TRIANGLE ◢◣◤◥
                let idx = Int(ch - 0x25E2)
                let (path1, path2) = getTrianglePathsDoubleColor(index: idx)
                color1.set()
                path1.fill()
                color2.set()
                path2.fill()
            }
        }
        
        xform.invert()
        xform.concat()
    }
}
