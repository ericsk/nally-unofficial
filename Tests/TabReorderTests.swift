import Testing
import Foundation
import AppKit
@testable import Nally

@Suite("Terminal Tab Reordering & Management Tests")
struct TabReorderTests {
    
    @Test("YLView Tab Array Reordering Bounds & Operation")
    @MainActor
    func testYLViewTabReorder() {
        let view = YLView(frame: .zero)
        let item1 = NSTabViewItem(identifier: "tab1")
        let item2 = NSTabViewItem(identifier: "tab2")
        let item3 = NSTabViewItem(identifier: "tab3")
        
        view.addTabViewItem(item1)
        view.addTabViewItem(item2)
        view.addTabViewItem(item3)
        
        #expect(view.tabViewItems.count == 3)
        #expect(view.tabViewItems[0] == item1)
        #expect(view.tabViewItems[1] == item2)
        #expect(view.tabViewItems[2] == item3)
        
        // Move item 0 (item1) to index 2
        view.moveTab(fromIndex: 0, toIndex: 2)
        
        #expect(view.tabViewItems[0] == item2)
        #expect(view.tabViewItems[1] == item3)
        #expect(view.tabViewItems[2] == item1)
    }
    
    @Test("YLView Invalid Reorder Index Guarding")
    @MainActor
    func testInvalidReorderIndexGuarding() {
        let view = YLView(frame: .zero)
        let item1 = NSTabViewItem(identifier: "tab1")
        let item2 = NSTabViewItem(identifier: "tab2")
        
        view.addTabViewItem(item1)
        view.addTabViewItem(item2)
        
        // Attempt out of bounds move
        view.moveTab(fromIndex: -1, toIndex: 1)
        #expect(view.tabViewItems[0] == item1)
        
        view.moveTab(fromIndex: 0, toIndex: 10)
        #expect(view.tabViewItems[0] == item1)
    }
    
    @Test("TabInfo Identity and Selection Equality")
    func testTabInfoEquality() {
        let item1 = NSTabViewItem(identifier: "a")
        let tabA = TabInfo(label: "PTT", icon: nil, isSelected: true, tabItem: item1)
        let tabB = TabInfo(label: "PTT", icon: nil, isSelected: true, tabItem: item1)
        
        #expect(tabA.id == tabB.id)
        #expect(tabA == tabB)
    }
}
