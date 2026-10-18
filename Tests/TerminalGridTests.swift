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
}
