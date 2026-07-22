import Testing
import Foundation
@testable import Nally

@Suite("Terminal Grid & Memory Safety Tests")
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
}
