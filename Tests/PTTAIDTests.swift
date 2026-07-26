//
//  PTTAIDTests.swift
//  Nally
//
//  Created by Antigravity on 2026/7/26.
//

import Testing
import Foundation
import AppKit
@testable import Nally

@Suite("PTT Article Code (#AID) Parsing & Menu Tests")
struct PTTAIDTests {
    
    @Test("Extract Standard PTT AID with Hash Prefix")
    @MainActor
    func testExtractAIDWithHash() {
        let manager = YLContextualMenuManager.sharedInstance
        
        let aid1 = manager.extractPTTAID(from: "#1a2b3c4d")
        #expect(aid1 == "#1a2b3c4d")
        
        let aid2 = manager.extractPTTAID(from: "#1A2B3C4D")
        #expect(aid2 == "#1A2B3C4D")
        
        let aid3 = manager.extractPTTAID(from: "#1_x_Y_z1")
        #expect(aid3 == "#1_x_Y_z1")
    }
    
    @Test("Extract PTT AID without Hash Prefix")
    @MainActor
    func testExtractAIDWithoutHash() {
        let manager = YLContextualMenuManager.sharedInstance
        
        let aid = manager.extractPTTAID(from: "1a2b3c4d")
        #expect(aid == "#1a2b3c4d")
    }
    
    @Test("Extract PTT AID from Mixed Text Block")
    @MainActor
    func testExtractAIDFromSentence() {
        let manager = YLContextualMenuManager.sharedInstance
        
        let aid = manager.extractPTTAID(from: "請參考文章 #1XYZW123 瞭解詳情")
        #expect(aid == "#1XYZW123")
    }
    
    @Test("Invalid AID Pattern Protection")
    @MainActor
    func testInvalidAIDProtection() {
        let manager = YLContextualMenuManager.sharedInstance
        
        #expect(manager.extractPTTAID(from: "hello world") == nil)
        #expect(manager.extractPTTAID(from: "#123") == nil)
        #expect(manager.extractPTTAID(from: "#2a2b3c4d") == nil)
    }
    
    @Test("Contextual Menu Items Generation for AID")
    @MainActor
    func testAIDMenuItemsGeneration() {
        let manager = YLContextualMenuManager.sharedInstance
        let items = manager.availableMenuItemForSelectionString("#1a2b3c4d")
        
        let hasJumpItem = items.contains { $0.title.contains("Jump to PTT Article") || $0.title.contains("#1a2b3c4d") }
        let hasCopyItem = items.contains { $0.title.contains("Copy PTT AID") || $0.title.contains("#1a2b3c4d") }
        
        #expect(hasJumpItem)
        #expect(hasCopyItem)
    }
}
