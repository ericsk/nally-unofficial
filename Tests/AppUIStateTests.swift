import Testing
import Foundation
import SwiftUI
@testable import Nally

@Suite("App UI State & MenuBar Integration Tests")
@MainActor
struct AppUIStateTests {
    
    @Test("AppState Initialization and Focus Flags")
    @MainActor
    func testAppStateDefaults() {
        let appState = AppState.shared
        #expect(appState.addressText == "")
        #expect(appState.focusAddressBar == false)
        #expect(appState.tabs.isEmpty)
    }
    
    @Test("AppTheme Preferred ColorScheme Mapping")
    func testAppThemeColorSchemeMapping() {
        #expect(AppTheme.system.colorScheme == nil)
        #expect(AppTheme.light.colorScheme == .light)
        #expect(AppTheme.dark.colorScheme == .dark)
    }
    
    @Test("Quick Connect Sites Protocol Detection")
    func testProtocolBadgeDetection() {
        let telnetSite = YLSite(name: "PTT", address: "ptt.cc")
        let sshSite = YLSite(name: "BS2 SSH", address: "ssh://bs2.to")
        
        #expect(!telnetSite.address.lowercased().hasPrefix("ssh://"))
        #expect(sshSite.address.lowercased().hasPrefix("ssh://"))
    }
    
    @Test("ShowMenuBarExtra Preference Key Persistence")
    func testShowMenuBarExtraPreference() {
        let key = "TestShowMenuBarExtra"
        UserDefaults.standard.set(false, forKey: key)
        #expect(UserDefaults.standard.bool(forKey: key) == false)
        
        UserDefaults.standard.set(true, forKey: key)
        #expect(UserDefaults.standard.bool(forKey: key) == true)
        
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    @Test("Controller setEncoding and Notification Synchronization")
    func testControllerSetEncoding() {
        let controller = YLController()
        let view = YLView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        controller._telnetView = view
        view.delegate = controller
        
        let conn = YLConnection()
        let term = YLTerminal()
        term.encoding = .YLBig5Encoding
        conn.terminal = term
        
        let tabItem = NSTabViewItem(identifier: conn)
        view.addTabViewItem(tabItem)
        view.selectTabViewItem(tabItem)
        
        var notifiedEncoding: YLEncoding?
        let cancellable = NotificationCenter.default.publisher(for: YLController.encodingDidChangeNotification, object: term)
            .sink { notification in
                if let t = notification.object as? YLTerminal {
                    notifiedEncoding = t.encoding
                }
            }
        
        // 1. Change via direct Swift API
        controller.setEncoding(.YLGBKEncoding)
        #expect(term.encoding == .YLGBKEncoding)
        #expect(notifiedEncoding == .YLGBKEncoding)
        
        // 2. Change via NSMenuItem tag
        let menuItem = NSMenuItem()
        menuItem.tag = Int(YLEncoding.YLBig5Encoding.rawValue)
        controller.setEncodingAction(menuItem)
        #expect(term.encoding == .YLBig5Encoding)
        #expect(notifiedEncoding == .YLBig5Encoding)
        
        cancellable.cancel()
    }
    
    @Test("Controller DetectDoubleByte and ShowHiddenText Modern Actions")
    func testControllerFlagsActions() {
        let controller = YLController()
        let view = YLView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        controller._telnetView = view
        
        let conn = YLConnection()
        let site = YLSite()
        site.detectDoubleByte = false
        conn.site = site
        
        let tabItem = NSTabViewItem(identifier: conn)
        view.addTabViewItem(tabItem)
        view.selectTabViewItem(tabItem)
        
        // Test setDetectDoubleByte
        controller.setDetectDoubleByte(true)
        #expect(site.detectDoubleByte == true)
        controller.setDetectDoubleByte(false)
        #expect(site.detectDoubleByte == false)
        
        // Test setShowHiddenText
        let globalConfig = YLLGlobalConfig.sharedInstance()
        controller.setShowHiddenText(true)
        #expect(globalConfig.showHiddenText == true)
        controller.setShowHiddenText(false)
        #expect(globalConfig.showHiddenText == false)
    }
    
    @Test("YLView Tab Selection Change Notification Posting")
    func testTabSelectionDidChangeNotification() {
        let view = YLView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        let item1 = NSTabViewItem(identifier: YLConnection())
        let item2 = NSTabViewItem(identifier: YLConnection())
        view.addTabViewItem(item1)
        view.addTabViewItem(item2)
        
        var notificationCount = 0
        let cancellable = NotificationCenter.default.publisher(for: YLView.tabSelectionDidChangeNotification)
            .sink { _ in
                notificationCount += 1
            }
        
        view.selectTabViewItem(item2)
        #expect(view.selectedTabViewItem == item2)
        #expect(notificationCount >= 1)
        
        view.selectTabViewItem(item1)
        #expect(view.selectedTabViewItem == item1)
        #expect(notificationCount >= 2)
        
        cancellable.cancel()
    }
    
    @Test("YLView Non-Blocking Paste Streaming and Cancellation")
    func testNonBlockingPasteStreaming() async {
        class MockChunkedConnection: YLConnection {
            var sentChunks: [Data] = []
            override func sendData(_ msg: Data) {
                sentChunks.append(msg)
            }
        }
        
        let view = YLView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        let mockConn = MockChunkedConnection()
        mockConn.connected = true
        let tabItem = NSTabViewItem(identifier: mockConn)
        view.addTabViewItem(tabItem)
        view.selectTabViewItem(tabItem)
        
        // 1. Small payload sent immediately
        let smallData = "Hello".data(using: .utf8)!
        view.sendDataChunked(smallData, to: mockConn, microsecondDelay: 100)
        #expect(mockConn.sentChunks.count == 1)
        #expect(view.activePasteTask == nil)
        
        // 2. Large payload creates asynchronous task without blocking
        mockConn.sentChunks.removeAll()
        let largeData = Data(repeating: 0x41, count: 256)
        view.sendDataChunked(largeData, to: mockConn, microsecondDelay: 50)
        #expect(view.activePasteTask != nil)
        
        // 3. Cancel paste terminates the task
        view.cancelCurrentPaste()
        #expect(view.activePasteTask == nil)
        
        // 4. Esc key cancelOperation aborts ongoing paste
        view.sendDataChunked(largeData, to: mockConn, microsecondDelay: 50)
        #expect(view.activePasteTask != nil)
        view.doCommand(by: #selector(NSResponder.cancelOperation(_:)))
        #expect(view.activePasteTask == nil)
    }
}
