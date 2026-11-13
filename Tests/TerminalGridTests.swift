import Testing
import Foundation
@testable import Nally

@Suite("Terminal Grid & Memory Safety Tests")
@MainActor
struct TerminalGridTests {
    @Test("YLTerminal Grid Matrix Initialization and Row/Column Dimensions")
    func testTerminalInitialization() {
        let terminal = YLTerminal()
        #expect(terminal.row > 0)
        #expect(terminal.column > 0)
        #expect(terminal.cells(ofRow: 0) != nil)
        #expect(terminal.cells(ofRow: 0)?.count == Int(terminal.column) + 1)
    }
    
    @Test("YLTerminal Dirty State and Clearing Controls")
    func testTerminalDirtyState() {
        let terminal = YLTerminal()
        terminal.setAllDirty()
        #expect(terminal.isDirty(atRow: 0, column: 0) == true)
        
        terminal.setDirty(false, atRow: 0, column: 0)
        #expect(terminal.isDirty(atRow: 0, column: 0) == false)
    }
    
    @Test("YLTerminal FeedBytes Only Marks Modified Rows Dirty")
    func testFeedBytesDirtyRowIsolation() {
        let terminal = YLTerminal()
        for r in 0..<terminal.row {
            terminal.clearDirty(forRow: r)
        }
        
        let conn = YLConnection()
        terminal.feedData(Data("Hello Row 0".utf8), connection: conn)
        
        #expect(terminal.isRowDirty(0) == true)
        #expect(terminal.isRowDirty(1) == false)
        #expect(terminal.isRowDirty(23) == false)
    }
    
    @Test("YLTerminal Malformed VT100/VT102 Escape Sequences Do Not Crash")
    func testMalformedEscapeSequenceBoundsSafety() {
        let terminal = YLTerminal()
        let conn = YLConnection()
        
        // 1. ESC 8 (DECRC) before any ESC 7 (DECSC) followed by printable text
        terminal.feedData(Data("\u{1B}8Hello".utf8), connection: conn)
        #expect(terminal.cursorRow >= 0 && terminal.cursorRow < terminal.row)
        #expect(terminal.cursorColumn >= 0 && terminal.cursorColumn <= terminal.column)
        
        // 2. Out-of-bounds DECSTBM (\e[0;0r and \e[1;999r) followed by LF / RI scrolling
        terminal.feedData(Data("\u{1B}[0;0r\n\u{1B}M\u{1B}[1;999r\u{1B}[24;1H\n".utf8), connection: conn)
        #expect(terminal.cursorRow >= 0 && terminal.cursorRow < terminal.row)
        
        // 3. IL / DL when cursor is below a restricted scroll region (\e[2;5r then move to row 10)
        terminal.feedData(Data("\u{1B}[2;5r\u{1B}[10;1H\u{1B}[3L\u{1B}[3M".utf8), connection: conn)
        #expect(terminal.cursorRow == 9)
        
        // 4. Tab at right margin followed by DCH / ICH / EL 1
        let eightyChars = String(repeating: "A", count: 80)
        terminal.feedData(Data(("\u{1B}[r\u{1B}[1;1H" + eightyChars + "\t\u{1B}[2P\u{1B}[2@\u{1B}[1K").utf8), connection: conn)
        #expect(terminal.cursorColumn < terminal.column)
        
        // 5. Huge CSI numeric parameter does not overflow Int / Int32
        terminal.feedData(Data("\u{1B}[999999999999999999999999999A\u{1B}[999999999999999999999999999C".utf8), connection: conn)
        #expect(terminal.cursorRow == 0)
        #expect(terminal.cursorColumn == terminal.column - 1)
        
        // 6. ESC # 8 (DECALN) marks all rows dirty
        for r in 0..<terminal.row { terminal.clearDirty(forRow: r) }
        terminal.feedData(Data("\u{1B}#8".utf8), connection: conn)
        #expect(terminal.isRowDirty(0) == true)
        #expect(terminal.isRowDirty(terminal.row - 1) == true)
    }
    
    @Test("YLTerminal Double-Byte Partial Overwrite Propagates Dirty Flag to Paired Cell")
    func testDoubleByteDirtyPairPropagation() {
        let terminal = YLTerminal()
        let conn = YLConnection()
        
        // Write Big5 "中" (0xA4 0xA4) at (0, 0)-(0, 1)
        terminal.feedData(Data([0xA4, 0xA4]), connection: conn)
        terminal.clearDirty(forRow: 0)
        #expect(terminal.isDirty(atRow: 0, column: 0) == false)
        #expect(terminal.isDirty(atRow: 0, column: 1) == false)
        
        // Move cursor to column 1 (second byte only) and overwrite with 0x40 -> Big5 "世" (0xA4 0x40)
        terminal.feedData(Data("\u{1B}[1;2H".utf8) + Data([0x40]), connection: conn)
        
        // Both col 0 (left half) and col 1 (right half) must be marked dirty to prevent ghosting/half-glyphs
        #expect(terminal.isDirty(atRow: 0, column: 0) == true)
        #expect(terminal.isDirty(atRow: 0, column: 1) == true)
    }
    
    @Test("YLTerminal UTF-8 Multi-Byte & Split Packet Decoding")
    func testUTF8TerminalDecodingAndSplitPackets() {
        let terminal = YLTerminal()
        let conn = YLConnection()
        terminal.encoding = .YLUTF8Encoding
        
        // "批踢踢あいうABC" where "批" (E6 89 B9) is split across two network packets
        let fullBytes = Array("批踢踢あいうABC".utf8)
        let part1 = Data(fullBytes[0..<2])   // Partial 3-byte UTF-8 sequence (E6 89)
        let part2 = Data(fullBytes[2...])    // Remainder starting with B9
        
        terminal.feedData(part1, connection: conn)
        #expect(terminal.cursorColumn == 0)  // Incomplete sequence buffered until third byte arrives
        
        terminal.feedData(part2, connection: conn)
        // 6 wide chars * 2 cols + 3 ASCII chars * 1 col = 15 columns
        #expect(terminal.cursorColumn == 15)
        
        let extracted = terminal.stringFromIndex(0, length: 15)
        #expect(extracted == "批踢踢あいうABC")
    }
    
    @Test("YLTerminal ANSI SGR Reset Codes, 39/49 Defaults, and 256/TrueColor Sequences")
    func testSGRResetAndExtendedColors() {
        let terminal = YLTerminal()
        let conn = YLConnection()
        let config = YLLGlobalConfig.sharedInstance()
        
        // 1. Set bold(1), underline(4), blink(5), reverse(7), red fg(31), blue bg(44), then turn off individually (22, 24, 25, 27, 39, 49)
        terminal.feedData(Data("\u{1B}[1;4;5;7;31;44mX\u{1B}[22;24;25;27;39;49mY".utf8), connection: conn)
        let attrX = terminal.attrAtRow(0, column: 0).terminalAttribute
        #expect(attrX.bold == true)
        #expect(attrX.underline == true)
        #expect(attrX.blink == true)
        #expect(attrX.reverse == true)
        #expect(attrX.fgColor == 1)
        #expect(attrX.bgColor == 4)
        
        let attrY = terminal.attrAtRow(0, column: 1).terminalAttribute
        #expect(attrY.bold == false)
        #expect(attrY.underline == false)
        #expect(attrY.blink == false)
        #expect(attrY.reverse == false)
        #expect(attrY.fgColor == Int(config.fgColorIndex)) // 7, NOT 9 (black)!
        #expect(attrY.bgColor == Int(config.bgColorIndex)) // 9
        
        // 2. 256-color (\e[38;5;196m) and TrueColor (\e[38;2;0;255;0m) must NOT falsely trigger blink(5) or underline(4)
        terminal.feedData(Data("\u{1B}[0;38;5;9mR\u{1B}[0;38;2;0;255;4mG".utf8), connection: conn)
        let attrR = terminal.attrAtRow(0, column: 2).terminalAttribute
        #expect(attrR.blink == false)
        #expect(attrR.fgColor == 1)
        #expect(attrR.bold == true)
        
        let attrG = terminal.attrAtRow(0, column: 3).terminalAttribute
        #expect(attrG.underline == false)
        #expect(attrG.fgColor == 2)
    }
}
