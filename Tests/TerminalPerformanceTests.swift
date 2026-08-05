//
//  TerminalPerformanceTests.swift
//  Nally
//
//  Created by Antigravity on 2026/7/23.
//

import Testing
import Foundation
@testable import Nally

@Suite("Terminal Rendering Performance & Selective Redraw Tests")
@MainActor
struct TerminalPerformanceTests {
    
    @Test("Row Dirty Tracking and Clearing Logic")
    func testRowDirtyTracking() {
        let term = YLTerminal()
        term.row = 24
        term.column = 80
        term.clearAll()
        
        // Initial state after clearAll should have dirty rows
        term.setAllDirty()
        #expect(term.isRowDirty(0) == true)
        #expect(term.isRowDirty(10) == true)
        
        // Clear dirty row 5
        term.clearRowDirty(5)
        #expect(term.isRowDirty(5) == false)
        #expect(term.isRowDirty(4) == true)
        
        // Mark cell on row 5 as dirty
        term.setDirty(true, atRow: 5, column: 10)
        #expect(term.isRowDirty(5) == true)
    }
    
    @Test("setDirtyForRow Precision and Bounds")
    func testSetDirtyForRowPrecision() {
        let term = YLTerminal()
        term.row = 24
        term.column = 80
        
        // Clear all dirty flags
        for r in 0..<24 {
            term.clearRowDirty(Int32(r))
            for c in 0..<80 {
                term.setDirty(false, atRow: Int32(r), column: Int32(c))
            }
        }
        
        #expect(term.isRowDirty(3) == false)
        #expect(term.isDirty(atRow: 3, column: 0) == false)
        
        // Set row 3 dirty
        term.setDirtyForRow(3)
        #expect(term.isRowDirty(3) == true)
        #expect(term.isDirty(atRow: 3, column: 0) == true)
        #expect(term.isDirty(atRow: 3, column: 79) == true)
        
        // Ensure adjacent row 4 was NOT marked dirty by range bug
        #expect(term.isRowDirty(4) == false)
        #expect(term.isDirty(atRow: 4, column: 0) == false)
    }
    
    @Test("Terminal Scrolling Decoupled from View Delegate")
    func testTerminalScrollingDecoupled() {
        let term = YLTerminal()
        term.row = 24
        term.column = 80
        term.clearAll()
        
        // Test ESC_IND scrolling at bottom line without delegate
        term._cursorX = 0
        term._cursorY = 23
        let lf: [UInt8] = [0x0A]
        lf.withUnsafeBufferPointer { buf in
            term.feedBytes(buf.baseAddress!, length: 1, connection: term)
        }
        #expect(term.row == 24)
        #expect(term.column == 80)
        #expect(term.isRowDirty(0) == true)
        #expect(term.isRowDirty(23) == true)
        
        // Test ESC_RI Reverse Index scrolling at top line without delegate
        term._cursorY = 0
        let ri: [UInt8] = [0x1B, 0x4D]
        ri.withUnsafeBufferPointer { buf in
            term.feedBytes(buf.baseAddress!, length: 2, connection: term)
        }
        #expect(term.isRowDirty(0) == true)
        #expect(term.isRowDirty(23) == true)
    }
}
