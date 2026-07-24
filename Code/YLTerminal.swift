//
//  YLTerminal.swift
//  Nally
//
//  Created by Yung-Luen Lan on 2006/9/10.
//  Copyright 2006 yllan.org. All rights reserved.
//

import Cocoa

@objc(YLTerminal)
public class YLTerminal: NSObject {
    @objc public var row: Int32 = 0
    @objc public var column: Int32 = 0
    
    @objc public var _cursorX: Int32 = 0
    @objc public var _cursorY: Int32 = 0
    
    private var _savedCursorX: Int32 = -1
    private var _savedCursorY: Int32 = -1
    
    private var _fgColor: Int = 7
    private var _bgColor: Int = 9
    private var _bold: Bool = false
    private var _underline: Bool = false
    private var _blink: Bool = false
    private var _reverse: Bool = false
    
    private var grid: [[cell]] = []
    private var dirty: [Bool] = []
    private var dirtyRows: [Bool] = []
    
    private enum ParserState {
        case normal
        case escape
        case control
        case scs
    }
    private var parserState: ParserState = .normal
    
    private enum EmulatorStandard {
        case vt100
        case vt102
    }
    private var emustd: EmulatorStandard = .vt102
    
    private var csBuf: [UInt8] = []
    private var csArg: [Int] = []
    private var csTemp: Int = 0
    
    private var _delegate: YLView?
    private var _scrollBeginRow: Int32 = 0
    private var _scrollEndRow: Int32 = 0
    
    private var _hasMessage: Bool = false
    private var _gotWrapped: Bool = false
    
    private var _modeScreenReverse: Bool = false
    private var _modeOriginRelative: Bool = false
    private var _modeWraptext: Bool = true
    private var _modeLNM: Bool = true
    private var _modeIRM: Bool = false
    
    private var _connection: YLConnection?
    private var _pluginLoader: YLPluginLoader?
    
    private var gEmptyAttr: UInt16 = 0
    
    // Constants
    private let ASC_NUL: UInt8 = 0x00
    private let ASC_ETX: UInt8 = 0x03
    private let ASC_EQT: UInt8 = 0x04
    private let ASC_ENQ: UInt8 = 0x05
    private let ASC_ACK: UInt8 = 0x06
    private let ASC_BEL: UInt8 = 0x07
    private let ASC_BS: UInt8  = 0x08
    private let ASC_HT: UInt8  = 0x09
    private let ASC_LF: UInt8  = 0x0A
    private let ASC_VT: UInt8  = 0x0B
    private let ASC_FF: UInt8  = 0x0C
    private let ASC_CR: UInt8  = 0x0D
    private let ASC_LS1: UInt8 = 0x0E
    private let ASC_LS0: UInt8 = 0x0F
    private let ASC_DLE: UInt8 = 0x10
    private let ASC_DC1: UInt8 = 0x11
    private let ASC_DC2: UInt8 = 0x12
    private let ASC_DC3: UInt8 = 0x13
    private let ASC_DC4: UInt8 = 0x14
    private let ASC_NAK: UInt8 = 0x15
    private let ASC_SYN: UInt8 = 0x16
    private let ASC_ETB: UInt8 = 0x17
    private let ASC_CAN: UInt8 = 0x18
    private let ASC_EM: UInt8  = 0x19
    private let ASC_SUB: UInt8 = 0x1A
    private let ASC_ESC: UInt8 = 0x1B
    private let ASC_FS: UInt8  = 0x1C
    private let ASC_GS: UInt8  = 0x1D
    private let ASC_RS: UInt8  = 0x1E
    private let ASC_US: UInt8  = 0x1F
    private let ASC_DEL: UInt8 = 0x7F
    
    private let ESC_HASH: UInt8  = 0x23
    private let ESC_sG0: UInt8   = 0x28
    private let ESC_sG1: UInt8   = 0x29
    private let ESC_APPK: UInt8  = 0x3D
    private let ESC_NUMK: UInt8  = 0x3E
    private let ESC_DECSC: UInt8 = 0x37
    private let ESC_DECRC: UInt8 = 0x38
    private let ESC_IND: UInt8   = 0x44
    private let ESC_NEL: UInt8   = 0x45
    private let ESC_RI: UInt8    = 0x4D
    private let ESC_RIS: UInt8   = 0x63
    private let ESC_CSI: UInt8   = 0x5B
    
    private let CSI_ICH: UInt8     = 0x40
    private let CSI_CUU: UInt8     = 0x41
    private let CSI_CUD: UInt8     = 0x42
    private let CSI_CUF: UInt8     = 0x43
    private let CSI_CUB: UInt8     = 0x44
    private let CSI_CNL: UInt8     = 0x45
    private let CSI_CPL: UInt8     = 0x46
    private let CSI_CHA: UInt8     = 0x47
    private let CSI_CUP: UInt8     = 0x48
    private let CSI_ED: UInt8      = 0x4A
    private let CSI_EL: UInt8      = 0x4B
    private let CSI_IL: UInt8      = 0x4C
    private let CSI_DL: UInt8      = 0x4D
    private let CSI_DCH: UInt8     = 0x50
    private let CSI_HPA: UInt8     = 0x60
    private let CSI_HPR: UInt8     = 0x61
    private let CSI_DA: UInt8      = 0x63
    private let CSI_VPA: UInt8     = 0x64
    private let CSI_VPR: UInt8     = 0x65
    private let CSI_HVP: UInt8     = 0x66
    private let CSI_TBC: UInt8     = 0x67
    private let CSI_SM: UInt8      = 0x68
    private let CSI_HPB: UInt8     = 0x6A
    private let CSI_VPB: UInt8     = 0x6B
    private let CSI_RM: UInt8      = 0x6C
    private let CSI_SGR: UInt8     = 0x6D
    private let CSI_DSR: UInt8     = 0x6E
    private let CSI_DECSTBM: UInt8 = 0x72
    private let CSI_SCP: UInt8     = 0x73
    private let CSI_RCP: UInt8     = 0x75
    private let CSI_CPR: UInt8     = 0x52
    
    public override init() {
        let config = YLLGlobalConfig.sharedInstance()
        self.row = Int32(config.row)
        self.column = Int32(config.column)
        self._scrollBeginRow = 0
        self._scrollEndRow = self.row - 1
        
        let emptyCell = cell(byte: 0, attr: attribute(v: 0))
        self.grid = Array(repeating: Array(repeating: emptyCell, count: Int(self.column + 1)), count: Int(self.row))
        self.dirty = Array(repeating: false, count: Int(self.row * self.column))
        self.dirtyRows = Array(repeating: false, count: Int(self.row))
        
        super.init()
        self.clearAll()
    }
    
    private func isParameter(_ c: UInt8) -> Bool {
        return c >= 0x30 && c <= 0x3F
    }
    
    private func updateEmptyAttr() {
        let config = YLLGlobalConfig.sharedInstance()
        let termAttr = TerminalAttribute(
            fgColor: Int(config.fgColorIndex),
            bgColor: Int(config.bgColorIndex),
            bold: false,
            underline: false,
            blink: false,
            reverse: false,
            doubleByte: 0,
            url: false
        )
        self.gEmptyAttr = termAttr.rawValue
    }
    
    private func currentAttrRaw() -> UInt16 {
        let termAttr = TerminalAttribute(
            fgColor: _fgColor,
            bgColor: _bgColor,
            bold: _bold,
            underline: _underline,
            blink: _blink,
            reverse: _reverse,
            doubleByte: 0,
            url: false
        )
        return termAttr.rawValue
    }
    
    private func cursorMoveTo(_ x: Int32, _ y: Int32) {
        _cursorX = x
        _cursorY = y
        if _cursorX < 0 { _cursorX = 0 }
        if _cursorX >= column { _cursorX = column - 1 }
        if _cursorY < 0 { _cursorY = 0 }
        if _cursorY >= row { _cursorY = row - 1 }
    }
    
    private func setGridByte(_ c: UInt8) {
        var x: Int
        if _cursorX <= column - 1 {
            if _modeIRM {
                for col in stride(from: Int(column) - 1, to: Int(_cursorX), by: -1) {
                    grid[Int(_cursorY)][col] = grid[Int(_cursorY)][col - 1]
                    setDirty(true, atRow: _cursorY, column: Int32(col))
                }
            }
            grid[Int(_cursorY)][Int(_cursorX)].byte = c
            grid[Int(_cursorY)][Int(_cursorX)].attr.v = currentAttrRaw()
            setDirty(true, atRow: _cursorY, column: _cursorX)
            _cursorX += 1
        } else if _cursorX == column && _modeWraptext {
            _cursorX = 0
            _gotWrapped = true
            if _cursorY == _scrollEndRow {
                _delegate?.updateBackedImage()
                _delegate?.extendBottom(from: _scrollBeginRow, to: _scrollEndRow)
                let emptyLine = grid[Int(_scrollBeginRow)]
                clearRow(_scrollBeginRow)
                for rowIdx in Int(_scrollBeginRow)..<Int(_scrollEndRow) {
                    grid[rowIdx] = grid[rowIdx + 1]
                }
                grid[Int(_scrollEndRow)] = emptyLine
                setAllDirty()
            } else {
                _cursorY += 1
                if _cursorY >= row { _cursorY = row - 1 }
            }
            grid[Int(_cursorY)][Int(_cursorX)].byte = c
            grid[Int(_cursorY)][Int(_cursorX)].attr.v = currentAttrRaw()
            setDirty(true, atRow: _cursorY, column: _cursorX)
            _cursorX += 1
        }
    }
    
    // MARK: - Input Interface
    @objc(feedData:connection:)
    public func feedData(_ data: Data, connection: Any) {
        data.withUnsafeBytes { rawBuffer in
            if let baseAddress = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) {
                self.feedBytes(baseAddress, length: Int32(data.count), connection: connection)
            }
        }
        _pluginLoader?.feedData(data)
    }
    
    // MARK: - Start / Stop
    @objc public func startConnection() {
        self.clearAll()
        _delegate?.updateBackedImage()
        _delegate?.needsDisplay = true
    }
    
    @objc public func closeConnection() {
        _delegate?.needsDisplay = true
    }
    
    // MARK: - Clear
    @objc public func clearAll() {
        _cursorX = 0
        _cursorY = 0
        updateEmptyAttr()
        for i in 0..<Int(row) {
            clearRow(Int32(i))
        }
        csBuf.removeAll()
        csArg.removeAll()
        _fgColor = Int(YLLGlobalConfig.sharedInstance().fgColorIndex)
        _bgColor = Int(YLLGlobalConfig.sharedInstance().bgColorIndex)
        csTemp = 0
        parserState = .normal
        _bold = false
        _underline = false
        _blink = false
        _reverse = false != _modeScreenReverse
    }
    
    @objc(clearRow:)
    public func clearRow(_ r: Int32) {
        clearRow(r, fromStart: 0, toEnd: column - 1)
    }
    
    @objc(clearRow:fromStart:toEnd:)
    public func clearRow(_ r: Int32, fromStart s: Int32, toEnd e: Int32) {
        for i in Int(s)...Int(e) {
            grid[Int(r)][i].byte = 0
            grid[Int(r)][i].attr.v = gEmptyAttr
            grid[Int(r)][i].attr.f.bgColor = UInt32(_bgColor & 0xF)
            grid[Int(r)][i].attr.f.reverse = UInt32(_reverse ? 1 : 0)
            setDirty(true, atRow: r, column: Int32(i))
        }
    }
    
    // MARK: - Dirty
    @objc public func setAllDirty() {
        let end = Int(column * row)
        for i in 0..<end {
            dirty[i] = true
        }
        for r in 0..<Int(row) {
            dirtyRows[r] = true
        }
    }
    
    @objc(setDirtyForRow:)
    public func setDirtyForRow(_ r: Int32) {
        guard r >= 0 && r < row else { return }
        let start = Int(r * column)
        let end = Int((r + 1) * column)
        for i in start..<end {
            dirty[i] = true
        }
        dirtyRows[Int(r)] = true
    }
    
    @objc(isDirtyAtRow:column:)
    public func isDirty(atRow r: Int32, column c: Int32) -> Bool {
        guard r >= 0 && r < row && c >= 0 && c < column else { return false }
        return dirty[Int(r * column + c)]
    }
    
    @objc(setDirty:atRow:column:)
    public func setDirty(_ d: Bool, atRow r: Int32, column c: Int32) {
        guard r >= 0 && r < row && c >= 0 && c < column else { return }
        dirty[Int(r * column + c)] = d
        if d {
            dirtyRows[Int(r)] = true
        }
    }
    
    @objc(isRowDirty:)
    public func isRowDirty(_ r: Int32) -> Bool {
        guard r >= 0 && r < row else { return false }
        return dirtyRows[Int(r)]
    }
    
    @objc(clearRowDirty:)
    public func clearRowDirty(_ r: Int32) {
        guard r >= 0 && r < row else { return }
        dirtyRows[Int(r)] = false
    }
    
    // MARK: - Access Data
    public func attrAtRow(_ r: Int32, column c: Int32) -> attribute {
        return grid[Int(r)][Int(c)].attr
    }
    
    @objc(stringFromIndex:length:)
    public func stringFromIndex(_ begin: Int32, length: Int32) -> String? {
        var textBuf = [unichar]()
        var firstByte: UInt8 = 0
        var spacebuf = 0
        
        let encoding = _connection?.site?.encoding ?? .YLBig5Encoding
        
        for i in Int(begin)..<Int(begin + length) {
            let x = i % Int(column)
            let y = i / Int(column)
            if x == 0 && i != Int(begin) && (i - 1) < Int(begin + length) {
                updateDoubleByteState(forRow: Int32(y))
                textBuf.append(0x000D) // newline CR
                spacebuf = 0
            }
            let db = grid[y][x].attr.f.doubleByte
            if db == 0 {
                if grid[y][x].byte == 0 || grid[y][x].byte == 32 {
                    spacebuf += 1
                } else {
                    for _ in 0..<spacebuf {
                        textBuf.append(32)
                    }
                    textBuf.append(UInt16(grid[y][x].byte))
                    spacebuf = 0
                }
            } else if db == 1 {
                firstByte = grid[y][x].byte
            } else if db == 2 && firstByte != 0 {
                let index = (Int(firstByte) << 8) + Int(grid[y][x].byte) - 0x8000
                for _ in 0..<spacebuf {
                    textBuf.append(32)
                }
                let charVal = (encoding == .YLBig5Encoding) ? lookupBig5(UInt16(index)) : lookupGBK(UInt16(index))
                textBuf.append(charVal)
                spacebuf = 0
            }
        }
        if textBuf.isEmpty { return nil }
        return String(utf16CodeUnits: textBuf, count: textBuf.count)
    }
    
    public func cells(ofRow r: Int32) -> [cell]? {
        guard r >= 0 && r < row else { return nil }
        return grid[Int(r)]
    }
    
    // MARK: - Update State
    @objc public func reverseAll() {
        for j in 0..<Int(row) {
            for i in 0..<Int(column) {
                let tmpBg = grid[j][i].attr.f.bgColor
                grid[j][i].attr.f.bgColor = grid[j][i].attr.f.fgColor
                grid[j][i].attr.f.fgColor = tmpBg
                setDirty(true, atRow: Int32(j), column: Int32(i))
            }
        }
    }
    
    @objc(updateDoubleByteStateForRow:)
    public func updateDoubleByteState(forRow r: Int32) {
        guard r >= 0 && r < row else { return }
        let rIdx = Int(r)
        var db = 0
        for i in 0..<Int(column) {
            if db == 0 || db == 2 {
                if grid[rIdx][i].byte > 0x7F {
                    db = 1
                } else {
                    db = 0
                }
            } else { // db == 1
                db = 2
            }
            grid[rIdx][i].attr.f.doubleByte = UInt32(db & 3)
        }
    }
    
    @objc(updateURLStateForRow:)
    public func updateURLState(forRow r: Int32) {
        guard r >= 0 && r < row else { return }
        let rIdx = Int(r)
        let protocols = ["http://", "https://", "ftp://", "telnet://", "bbs://", "ssh://", "mailto:"]
        var urlState = false
        if r > 0 {
            urlState = grid[rIdx - 1][Int(column - 1)].attr.f.url != 0
        }
        
        for i in 0..<Int(column) {
            if urlState {
                let c = grid[rIdx][i].byte
                if c < 0x21 || c > 0x7E || c == 41 {
                    urlState = false
                }
            } else {
                for p in protocols {
                    let len = p.count
                    if i + len <= Int(column) {
                        var match = true
                        let pBytes = Array(p.utf8)
                        for s in 0..<len {
                            if grid[rIdx][i + s].byte != pBytes[s] || grid[rIdx][i + s].attr.f.doubleByte != 0 {
                                match = false
                                break
                            }
                        }
                        if match {
                            urlState = true
                            break
                        }
                    }
                }
            }
            
            let currentUrlBit = grid[rIdx][i].attr.f.url != 0
            if currentUrlBit != urlState {
                grid[rIdx][i].attr.f.url = urlState ? 1 : 0
                setDirty(true, atRow: r, column: Int32(i))
            }
        }
    }
    
    @objc(urlStringAtRow:column:)
    public func urlString(atRow r: Int32, column c: Int32) -> String? {
        var rowIdx = Int(r)
        var colIdx = Int(c)
        
        if grid[rowIdx][colIdx].attr.f.url == 0 { return nil }
        
        while grid[rowIdx][colIdx].attr.f.url != 0 {
            colIdx -= 1
            if colIdx < 0 {
                colIdx = Int(column) - 1
                rowIdx -= 1
            }
            if rowIdx < 0 { break }
        }
        
        colIdx += 1
        if colIdx >= Int(column) {
            colIdx = 0
            rowIdx += 1
        }
        
        var urlString = ""
        while rowIdx >= 0 && rowIdx < Int(row) && grid[rowIdx][colIdx].attr.f.url != 0 {
            let charVal = Character(UnicodeScalar(grid[rowIdx][colIdx].byte))
            urlString.append(charVal)
            colIdx += 1
            if colIdx >= Int(column) {
                colIdx = 0
                rowIdx += 1
            }
        }
        return urlString
    }
    
    // MARK: - Accessors
    @objc public var delegate: Any? {
        get { return _delegate }
        set { _delegate = newValue as? YLView }
    }
    
    @objc public var cursorRow: Int32 {
        get { return _cursorY }
        set { cursorMoveTo(_cursorX, newValue) }
    }
    
    @objc public var cursorColumn: Int32 {
        get { return _cursorX }
        set { cursorMoveTo(newValue, _cursorY) }
    }
    
    @objc public var encoding: YLEncoding {
        get {
            return _connection?.site?.encoding ?? .YLBig5Encoding
        }
        set {
            _connection?.site?.encoding = newValue
        }
    }
    
    @objc public var hasMessage: Bool {
        get { return _hasMessage }
        set {
            if _hasMessage != newValue {
                _hasMessage = newValue
                let config = YLLGlobalConfig.sharedInstance()
                if _hasMessage {
                    NSApp.requestUserAttention(config.repeatBounce ? .criticalRequest : .informationalRequest)
                    if _connection !== _delegate?.selectedTabViewItem?.identifier as? YLConnection || !NSApp.isActive {
                        _connection?.icon = NSImage(named: "message.pdf")
                        config.messageCount = config.messageCount + 1
                    } else {
                        _hasMessage = false
                    }
                } else {
                    config.messageCount = config.messageCount - 1
                    if let conn = _connection {
                        conn.icon = NSImage(named: conn.connected ? "connect.pdf" : "offline.pdf")
                    }
                }
            }
        }
    }
    
    @objc public var connection: YLConnection? {
        get { return _connection }
        set { _connection = newValue }
    }
    
    @objc public var pluginLoader: YLPluginLoader? {
        get { return _pluginLoader }
        set { _pluginLoader = newValue }
    }
}

// Extension to support while-loop for feedBytes
extension YLTerminal {
    @objc(feedBytes:length:connection:)
    public func feedBytes(_ bytes: UnsafePointer<UInt8>, length len: Int32, connection: Any) {
        autoreleasepool {
            var x: Int
            var i = 0
            while i < Int(len) {
                let c = bytes[i]
                switch parserState {
                case .normal:
                    if c == ASC_NUL {
                        // do nothing
                    } else if c == ASC_ETX || c == ASC_EQT {
                        // do nothing
                    } else if c == ASC_ENQ {
                        let cmd: [UInt8] = [ASC_NUL]
                        _connection?.sendBytes(cmd, length: 1)
                    } else if c == ASC_ACK {
                        // do nothing
                    } else if c == ASC_BEL {
                        NSSound(named: "Whit.aiff")?.play()
                        self.hasMessage = true
                    } else if c == ASC_BS {
                        if _cursorX > 0 {
                            if _cursorX == column && _modeWraptext {
                                _cursorX -= 1
                            }
                            _cursorX -= 1
                        } else if _cursorX == 0 && _gotWrapped {
                            _cursorX = column - 1
                            if _cursorY == _scrollBeginRow {
                                _delegate?.updateBackedImage()
                                _delegate?.extendTop(from: _scrollBeginRow, to: _scrollEndRow)
                                let emptyLine = grid[Int(_scrollEndRow)]
                                clearRow(_scrollEndRow)
                                for rowIdx in stride(from: Int(_scrollEndRow), to: Int(_scrollBeginRow), by: -1) {
                                    grid[rowIdx] = grid[rowIdx - 1]
                                }
                                grid[Int(_scrollBeginRow)] = emptyLine
                                setAllDirty()
                            } else {
                                _cursorY -= 1
                                if _cursorY < 0 { _cursorY = 0 }
                            }
                            _gotWrapped = false
                        }
                    } else if c == ASC_HT {
                        let curX = Int(_cursorX)
                        let nextTab = (curX / 8 + 1) * 8
                        _cursorX = Int32(nextTab)
                    } else if c == ASC_LF || c == ASC_VT || c == ASC_FF {
                        if !_modeLNM { _cursorX = 0 }
                        if _cursorY == _scrollEndRow {
                            let emptyLine = grid[Int(_scrollBeginRow)]
                            clearRow(_scrollBeginRow)
                            for rowIdx in Int(_scrollBeginRow)..<Int(_scrollEndRow) {
                                grid[rowIdx] = grid[rowIdx + 1]
                            }
                            grid[Int(_scrollEndRow)] = emptyLine
                            setAllDirty()
                        } else {
                            _cursorY += 1
                            if _cursorY >= row { _cursorY = row - 1 }
                        }
                    } else if c == ASC_CR {
                        _cursorX = 0
                    } else if c == ASC_LS1 || c == ASC_LS0 || c == ASC_DLE || c == ASC_DC1 || c == ASC_DC2 || c == ASC_DC3 || c == ASC_DC4 || c == ASC_NAK || c == ASC_SYN || c == ASC_ETB {
                        // do nothing
                    } else if c == ASC_CAN || c == ASC_SUB {
                        // do nothing
                    } else if c == ASC_EM {
                        // do nothing
                    } else if c == ASC_ESC {
                        parserState = .escape
                    } else if c == ASC_FS || c == ASC_GS || c == ASC_RS || c == ASC_US || c == ASC_DEL {
                        // do nothing
                    } else {
                        setGridByte(c)
                    }
                    
                case .escape:
                    if c == ASC_ESC {
                        parserState = .escape
                    } else if c == ESC_CSI {
                        csBuf.removeAll()
                        csArg.removeAll()
                        csTemp = 0
                        parserState = .control
                    } else if c == ESC_RI {
                        if _cursorY == _scrollBeginRow {
                            _delegate?.updateBackedImage()
                            _delegate?.extendTop(from: _scrollBeginRow, to: _scrollEndRow)
                            let emptyLine = grid[Int(_scrollEndRow)]
                            clearRow(_scrollEndRow)
                            for rowIdx in stride(from: Int(_scrollEndRow), to: Int(_scrollBeginRow), by: -1) {
                                grid[rowIdx] = grid[rowIdx - 1]
                            }
                            grid[Int(_scrollBeginRow)] = emptyLine
                            setAllDirty()
                        } else {
                            _cursorY -= 1
                            if _cursorY < 0 { _cursorY = 0 }
                        }
                        parserState = .normal
                    } else if c == ESC_IND {
                        if _cursorY == _scrollEndRow {
                            _delegate?.updateBackedImage()
                            _delegate?.extendBottom(from: _scrollBeginRow, to: _scrollEndRow)
                            let emptyLine = grid[Int(_scrollBeginRow)]
                            clearRow(_scrollBeginRow)
                            for rowIdx in Int(_scrollBeginRow)..<Int(_scrollEndRow) {
                                grid[rowIdx] = grid[rowIdx + 1]
                            }
                            grid[Int(_scrollEndRow)] = emptyLine
                            setAllDirty()
                        } else {
                            _cursorY += 1
                            if _cursorY >= row { _cursorY = row - 1 }
                        }
                        parserState = .normal
                    } else if c == ESC_DECSC {
                        _savedCursorX = _cursorX
                        _savedCursorY = _cursorY
                        parserState = .normal
                    } else if c == ESC_DECRC {
                        _cursorX = _savedCursorX
                        _cursorY = _savedCursorY
                        parserState = .normal
                    } else if c == ESC_HASH {
                        if i < Int(len) - 1 && bytes[i + 1] == 56 {
                            i += 1 // skip '8'
                            for y in 0..<Int(row) {
                                for col in 0..<Int(column) {
                                    grid[y][col].byte = 69
                                    grid[y][col].attr.v = gEmptyAttr
                                    dirty[y * Int(column) + col] = true
                                }
                            }
                        } else {
                            NSLog("Unhandled <ESC># case")
                        }
                        parserState = .normal
                    } else if c == ESC_sG0 || c == ESC_sG1 {
                        parserState = .scs
                    } else if c == ESC_APPK || c == ESC_NUMK {
                        parserState = .normal
                    } else if c == ESC_NEL {
                        _cursorX = 0
                        if _cursorY == _scrollEndRow {
                            _delegate?.updateBackedImage()
                            _delegate?.extendBottom(from: _scrollBeginRow, to: _scrollEndRow)
                            let emptyLine = grid[Int(_scrollBeginRow)]
                            clearRow(_scrollBeginRow)
                            for rowIdx in Int(_scrollBeginRow)..<Int(_scrollEndRow) {
                                grid[rowIdx] = grid[rowIdx + 1]
                            }
                            grid[Int(_scrollEndRow)] = emptyLine
                            setAllDirty()
                        } else {
                            _cursorY += 1
                            if _cursorY >= row { _cursorY = row - 1 }
                        }
                        parserState = .normal
                    } else if c == ESC_RIS {
                        self.clearAll()
                        _cursorX = 0
                        _cursorY = 0
                        parserState = .normal
                    } else {
                        NSLog("unprocessed esc: %c(0x%X)", c, c)
                        parserState = .normal
                    }
                    
                case .scs:
                    parserState = .normal
                    
                case .control:
                    if isParameter(c) {
                        csBuf.append(c)
                        if c >= 48 && c <= 57 {
                            csTemp = csTemp * 10 + Int(c - 48)
                        } else if c == 63 {
                            csArg.append(-1)
                            csTemp = 0
                            csBuf.removeAll()
                        } else if !csBuf.isEmpty {
                            csArg.append(csTemp)
                            csTemp = 0
                            csBuf.removeAll()
                        }
                    } else if c == ASC_BS {
                        if !csBuf.isEmpty {
                            _ = csArg.popLast()
                        }
                    } else if c == ASC_VT {
                        if !_modeLNM { _cursorX = 0 }
                        if _cursorY == _scrollEndRow {
                            let emptyLine = grid[Int(_scrollBeginRow)]
                            clearRow(_scrollBeginRow)
                            for rowIdx in Int(_scrollBeginRow)..<Int(_scrollEndRow) {
                                grid[rowIdx] = grid[rowIdx + 1]
                            }
                            grid[Int(_scrollEndRow)] = emptyLine
                            setAllDirty()
                        } else {
                            _cursorY += 1
                            if _cursorY >= row { _cursorY = row - 1 }
                        }
                    } else if c == ASC_CR {
                        _cursorX = 0
                    } else {
                        if !csBuf.isEmpty {
                            csArg.append(csTemp)
                            csTemp = 0
                            csBuf.removeAll()
                        }
                        
                        if c == CSI_ICH {
                            let p = !csArg.isEmpty ? max(1, csArg[0]) : 1
                            for col in stride(from: Int(column) - 1, to: Int(_cursorX) + p - 1, by: -1) {
                                grid[Int(_cursorY)][col] = grid[Int(_cursorY)][col - p]
                                setDirty(true, atRow: _cursorY, column: Int32(col))
                            }
                            clearRow(_cursorY, fromStart: _cursorX, toEnd: _cursorX + Int32(p) - 1)
                        } else if c == CSI_CUU {
                            let p = !csArg.isEmpty ? max(1, csArg[0]) : 1
                            _cursorY -= Int32(p)
                            if _modeOriginRelative && _cursorY < _scrollBeginRow {
                                _cursorY = _scrollBeginRow
                            } else if _cursorY < 0 {
                                _cursorY = 0
                            }
                        } else if c == CSI_CUD {
                            let p = !csArg.isEmpty ? max(1, csArg[0]) : 1
                            _cursorY += Int32(p)
                            if _modeOriginRelative && _cursorY > _scrollEndRow {
                                _cursorY = _scrollEndRow
                            } else if _cursorY >= row {
                                _cursorY = row - 1
                            }
                        } else if c == CSI_CUF {
                            let p = !csArg.isEmpty ? max(1, csArg[0]) : 1
                            _cursorX += Int32(p)
                            if _cursorX >= column { _cursorX = column - 1 }
                        } else if c == CSI_CUB {
                            let p = !csArg.isEmpty ? max(1, csArg[0]) : 1
                            _cursorX -= Int32(p)
                            if _cursorX < 0 { _cursorX = 0 }
                        } else if c == CSI_CNL {
                            _cursorX = 0
                            let p = !csArg.isEmpty ? csArg[0] : 1
                            _cursorY += Int32(p)
                            if _cursorY >= row { _cursorY = row - 1 }
                        } else if c == CSI_CPL {
                            _cursorX = 0
                            let p = !csArg.isEmpty ? csArg[0] : 1
                            _cursorY -= Int32(p)
                            if _cursorY < 0 { _cursorY = 0 }
                        } else if c == CSI_CHA {
                            let p = !csArg.isEmpty ? max(1, csArg[0]) : 1
                            cursorMoveTo(Int32(p - 1), _cursorY)
                        } else if c == CSI_HVP || c == CSI_CUP {
                            if csArg.isEmpty {
                                _cursorX = 0
                                _cursorY = 0
                            } else if csArg.count == 1 {
                                var p = csArg[0]
                                if p < 1 { p = 1 }
                                if _modeOriginRelative && _scrollBeginRow > 0 {
                                    p += Int(_scrollBeginRow)
                                    if p > Int(_scrollEndRow) { p = Int(_scrollEndRow) + 1 }
                                }
                                cursorMoveTo(0, Int32(p - 1))
                            } else if csArg.count > 1 {
                                var p = csArg[0]
                                let q = csArg[1]
                                if p < 1 { p = 1 }
                                if _modeOriginRelative && _scrollBeginRow > 0 {
                                    p += Int(_scrollBeginRow)
                                    if p > Int(_scrollEndRow) { p = Int(_scrollEndRow) + 1 }
                                }
                                cursorMoveTo(Int32(max(1, q) - 1), Int32(p - 1))
                            }
                        } else if c == CSI_ED {
                            let mode = !csArg.isEmpty ? csArg[0] : 0
                            if mode == 0 {
                                clearRow(_cursorY, fromStart: _cursorX, toEnd: column - 1)
                                for j in (_cursorY + 1)..<row {
                                    clearRow(j)
                                }
                            } else if mode == 1 {
                                clearRow(_cursorY, fromStart: 0, toEnd: _cursorX)
                                for j in 0..<_cursorY {
                                    clearRow(j)
                                }
                            } else if mode == 2 {
                                self.clearAll()
                            }
                        } else if c == CSI_EL {
                            let mode = !csArg.isEmpty ? csArg[0] : 0
                            if mode == 0 {
                                clearRow(_cursorY, fromStart: _cursorX, toEnd: column - 1)
                            } else if mode == 1 {
                                clearRow(_cursorY, fromStart: 0, toEnd: _cursorX)
                            } else if mode == 2 {
                                clearRow(_cursorY)
                            }
                        } else if c == CSI_IL {
                            let p = !csArg.isEmpty ? max(1, csArg[0]) : 1
                            for _ in 0..<p {
                                clearRow(_scrollEndRow)
                                let emptyRow = grid[Int(_scrollEndRow)]
                                for r in stride(from: Int(_scrollEndRow), to: Int(_cursorY), by: -1) {
                                    grid[r] = grid[r - 1]
                                }
                                grid[Int(_cursorY)] = emptyRow
                            }
                            for j in _cursorY..._scrollEndRow {
                                setDirtyForRow(j)
                            }
                        } else if c == CSI_DL {
                            let p = !csArg.isEmpty ? max(1, csArg[0]) : 1
                            for _ in 0..<p {
                                clearRow(_cursorY)
                                let emptyRow = grid[Int(_cursorY)]
                                for r in Int(_cursorY)..<Int(_scrollEndRow) {
                                    grid[r] = grid[r + 1]
                                }
                                grid[Int(_scrollEndRow)] = emptyRow
                            }
                            for j in _cursorY..._scrollEndRow {
                                setDirtyForRow(j)
                            }
                        } else if c == CSI_DCH {
                            let p = !csArg.isEmpty ? max(1, csArg[0]) : 1
                            for j in Int(_cursorX)..<Int(column) {
                                if j <= Int(column) - 1 - p {
                                    grid[Int(_cursorY)][j] = grid[Int(_cursorY)][j + p]
                                } else {
                                    grid[Int(_cursorY)][j].byte = 0
                                    grid[Int(_cursorY)][j].attr.v = gEmptyAttr
                                    grid[Int(_cursorY)][j].attr.f.bgColor = UInt32(_bgColor & 0xF)
                                }
                                setDirty(true, atRow: _cursorY, column: Int32(j))
                            }
                        } else if c == CSI_HPA {
                            let p = !csArg.isEmpty ? max(1, csArg[0]) : 1
                            cursorMoveTo(Int32(p - 1), _cursorY)
                        } else if c == CSI_HPR {
                            let p = !csArg.isEmpty ? max(1, csArg[0]) : 1
                            cursorMoveTo(_cursorX + Int32(p), _cursorY)
                        } else if c == CSI_DA {
                            var cmd = [UInt8](repeating: 0, count: 10)
                            var cmdLen = 0
                            if emustd == .vt100 {
                                cmd[0] = 0x1B; cmd[1] = 0x5B; cmd[2] = 0x3F; cmd[3] = 49
                                cmd[4] = 0x3B; cmd[5] = 48; cmd[6] = 99
                                cmdLen = 7
                            } else if emustd == .vt102 {
                                cmd[0] = 0x1B; cmd[1] = 0x5B; cmd[2] = 0x3F; cmd[3] = 54
                                cmd[4] = 99
                                cmdLen = 5
                            }
                            if csArg.isEmpty || (csArg.count == 1 && csArg[0] == 0) {
                                _connection?.sendBytes(cmd, length: cmdLen)
                            }
                        } else if c == CSI_VPA {
                            let p = !csArg.isEmpty ? max(1, csArg[0]) : 1
                            cursorMoveTo(_cursorX, Int32(p - 1))
                        } else if c == CSI_VPR {
                            let p = !csArg.isEmpty ? max(1, csArg[0]) : 1
                            cursorMoveTo(_cursorX, _cursorY + Int32(p))
                        } else if c == CSI_TBC {
                            // Clear tab stop, ignored
                        } else if c == CSI_SM {
                            var doClear = false
                            var args = csArg
                            while !args.isEmpty {
                                var p = args[0]
                                args.removeFirst()
                                if p == -1 {
                                    if args.count == 1 {
                                        p = args[0]
                                        args.removeFirst()
                                        if p == 3 {
                                            doClear = true
                                            _modeOriginRelative = false
                                            _scrollBeginRow = 0
                                            _scrollEndRow = row - 1
                                        } else if p == 5 && !_modeScreenReverse {
                                            _modeScreenReverse = true
                                            _reverse = !_reverse
                                            reverseAll()
                                        } else if p == 6 {
                                            _modeOriginRelative = true
                                        } else if p == 7 {
                                            _modeWraptext = true
                                        }
                                    }
                                } else if p == 20 {
                                    _modeLNM = false
                                } else if p == 4 {
                                    _modeIRM = true
                                }
                            }
                            if doClear {
                                if !_modeOriginRelative {
                                    self.clearAll()
                                    _cursorX = 0
                                    _cursorY = 0
                                }
                            }
                        } else if c == CSI_HPB {
                            let p = !csArg.isEmpty ? max(1, csArg[0]) : 1
                            cursorMoveTo(_cursorX - Int32(p), _cursorY)
                        } else if c == CSI_VPB {
                            let p = !csArg.isEmpty ? max(1, csArg[0]) : 1
                            cursorMoveTo(_cursorX, _cursorY - Int32(p))
                        } else if c == CSI_RM {
                            var doClear = false
                            var args = csArg
                            while !args.isEmpty {
                                var p = args[0]
                                args.removeFirst()
                                if p == -1 {
                                    if args.count == 1 {
                                        p = args[0]
                                        args.removeFirst()
                                        if p == 3 {
                                            doClear = true
                                            _modeOriginRelative = false
                                            _scrollBeginRow = 0
                                            _scrollEndRow = row - 1
                                        } else if p == 5 && _modeScreenReverse {
                                            _modeScreenReverse = false
                                            _reverse = !_reverse
                                            reverseAll()
                                        } else if p == 6 {
                                            _modeOriginRelative = false
                                        } else if p == 7 {
                                            _modeWraptext = false
                                        }
                                    }
                                } else if p == 20 {
                                    _modeLNM = true
                                } else if p == 4 {
                                    _modeIRM = false
                                }
                            }
                            if doClear {
                                self.clearAll()
                                _cursorX = 0
                                _cursorY = 0
                            }
                        } else if c == CSI_SGR {
                            if csArg.isEmpty {
                                _fgColor = 7
                                _bgColor = 9
                                _bold = false
                                _underline = false
                                _blink = false
                                _reverse = false != _modeScreenReverse
                            } else {
                                for p in csArg {
                                    if p == 0 {
                                        _fgColor = 7
                                        _bgColor = 9
                                        _bold = false
                                        _underline = false
                                        _blink = false
                                        _reverse = false != _modeScreenReverse
                                    } else if p >= 30 && p <= 39 {
                                        _fgColor = p - 30
                                    } else if p >= 40 && p <= 49 {
                                        _bgColor = p - 40
                                    } else if p == 1 {
                                        _bold = true
                                    } else if p == 4 {
                                        _underline = true
                                    } else if p == 5 {
                                        _blink = true
                                    } else if p == 7 {
                                        _reverse = true != _modeScreenReverse
                                    }
                                }
                            }
                        } else if c == CSI_DSR {
                            if csArg.count == 1 {
                                if csArg[0] == 5 {
                                    let cmd: [UInt8] = [0x1B, 0x5B, 0x30, CSI_DSR]
                                    _connection?.sendBytes(cmd, length: 4)
                                } else if csArg[0] == 6 {
                                    var cmd = [UInt8](repeating: 0, count: 12)
                                    var cmdLen = 0
                                    cmd[cmdLen] = 0x1B; cmdLen += 1
                                    cmd[cmdLen] = 0x5B; cmdLen += 1
                                    
                                    let yVal = _cursorY + 1
                                    if yVal / 10 >= 1 {
                                        cmd[cmdLen] = 48 + UInt8(yVal / 10); cmdLen += 1
                                    }
                                    cmd[cmdLen] = 48 + UInt8(yVal % 10); cmdLen += 1
                                    cmd[cmdLen] = 0x3B; cmdLen += 1
                                    
                                    let xVal = _cursorX + 1
                                    if xVal / 10 >= 1 {
                                        cmd[cmdLen] = 48 + UInt8(xVal / 10); cmdLen += 1
                                    }
                                    cmd[cmdLen] = 48 + UInt8(xVal % 10); cmdLen += 1
                                    cmd[cmdLen] = CSI_CPR; cmdLen += 1
                                    _connection?.sendBytes(cmd, length: cmdLen)
                                }
                            }
                        } else if c == CSI_DECSTBM {
                            if csArg.isEmpty {
                                _scrollBeginRow = 0
                                _scrollEndRow = row - 1
                            } else if csArg.count == 2 {
                                var s = Int32(csArg[0])
                                var e = Int32(csArg[1])
                                if s > e { swap(&s, &e) }
                                _scrollBeginRow = s - 1
                                _scrollEndRow = e - 1
                            }
                            _cursorX = 0
                            _cursorY = _scrollBeginRow
                        } else if c == CSI_SCP {
                            _savedCursorX = _cursorX
                            _savedCursorY = _cursorY
                        } else if c == CSI_RCP {
                            if _savedCursorX >= 0 && _savedCursorY >= 0 {
                                _cursorX = _savedCursorX
                                _cursorY = _savedCursorY
                            }
                        } else {
                            NSLog("unsupported control sequence: 0x%X", c)
                        }
                        csArg.removeAll()
                        parserState = .normal
                    }
                }
                i += 1
            }
            
            for rowIdx in 0..<Int(row) {
                updateDoubleByteState(forRow: Int32(rowIdx))
                updateURLState(forRow: Int32(rowIdx))
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) { [weak self] in
                self?._delegate?.tick()
            }
        }
    }
}
