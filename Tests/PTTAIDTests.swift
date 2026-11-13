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
@MainActor
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
    
    @Test("Contextual Menu Preserves Distinct URLs per Menu Item and Encodes Safely")
    @MainActor
    func testContextualMenuURLIsolationAndEncoding() {
        let manager = YLContextualMenuManager.sharedInstance
        let items = manager.availableMenuItemForSelectionString("example.com/photo.jpg")
        
        let openItem = items.first { $0.title == "https://example.com/photo.jpg" }
        let searchItem = items.first { $0.title == "Image search by GOOGLE" }
        
        #expect(openItem != nil)
        #expect(searchItem != nil)
        #expect((openItem?.representedObject as? [String]) == ["https://example.com/photo.jpg"])
        #expect((searchItem?.representedObject as? [String])?.first?.contains("google.com/searchbyimage") == true)
        
        // Already percent-encoded URLs and #anchors must not be double-encoded
        let encodedWiki = "https://zh.wikipedia.org/wiki/%E5%8F%B0%E7%81%A3#section"
        #expect(YLContextualMenuManager.resolvedURL(from: encodedWiki)?.absoluteString == encodedWiki)
    }
    
    @Test("SSH and Telnet Address Parsing & Argument Injection Protection")
    @MainActor
    func testSSHAndTelnetAddressValidation() {
        // Reject option injection attacks
        #expect(YLSSH.parseSSHAddress("ssh://-oProxyCommand=calc") == nil)
        #expect(YLSSH.parseSSHAddress("-oProxyCommand=calc") == nil)
        #expect(YLSSH.parseSSHAddress("ssh://-baduser@ptt.cc") == nil)
        #expect(YLSSH.parseSSHAddress("ssh://bbs@-badhost.cc") == nil)
        #expect(YLSSH.parseSSHAddress("ssh://bbs@ptt.cc:99999") == nil)
        #expect(YLSSH.parseSSHAddress("ssh://bbs@ptt.cc:0") == nil)
        
        // Valid SSH addresses & accurate bbs user detection
        let ptt = YLSSH.parseSSHAddress("ssh://bbs@ptt.cc")
        #expect(ptt?.target == "bbs@ptt.cc")
        #expect(ptt?.port == 22)
        #expect(ptt?.loginAsBBS == true)
        
        let pttUTF8 = YLSSH.parseSSHAddress("ssh://bbsu@ptt.cc:2222")
        #expect(pttUTF8?.target == "bbsu@ptt.cc")
        #expect(pttUTF8?.port == 2222)
        #expect(pttUTF8?.loginAsBBS == true)
        
        // Host starting with "bbs" without user@ must NOT set loginAsBBS
        let bbsHost = YLSSH.parseSSHAddress("ssh://bbserver.example.com")
        #expect(bbsHost?.target == "bbserver.example.com")
        #expect(bbsHost?.loginAsBBS == false)
        
        // IPv6 bracketed SSH address
        let ipv6SSH = YLSSH.parseSSHAddress("ssh://bbs@[::1]:2222")
        #expect(ipv6SSH?.target == "bbs@::1")
        #expect(ipv6SSH?.port == 2222)
        
        // "--" option terminator is always present before target
        let args = YLSSH.sshArguments(target: "bbs@ptt.cc", port: 22, loginAsBBS: true)
        #expect(args == ["-e", "none", "-x", "-p", "22", "--", "bbs@ptt.cc"])
        
        // Telnet port bounds & IPv6 parsing
        #expect(YLTelnet.parseTelnetAddress("ptt.cc:99999") == nil)
        #expect(YLTelnet.parseTelnetAddress("ptt.cc:0") == nil)
        #expect(YLTelnet.parseTelnetAddress("ptt.cc")?.port == 23)
        #expect(YLTelnet.parseTelnetAddress("ptt.cc 443")?.port == 443)
        #expect(YLTelnet.parseTelnetAddress("[2001:db8::1]:2323")?.host == "2001:db8::1")
        #expect(YLTelnet.parseTelnetAddress("[2001:db8::1]:2323")?.port == 2323)
    }
}
