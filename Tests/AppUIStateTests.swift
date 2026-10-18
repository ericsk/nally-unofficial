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
    
    @Test("YLView Backing Properties Change & Disconnection Preserve Screen Content")
    func testBackingPropertiesAndDisconnectRedrawPreservesContent() {
        let view = YLView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        let conn = YLConnection()
        let term = YLTerminal()
        conn.terminal = term
        conn.connected = true
        
        let tabItem = NSTabViewItem(identifier: conn)
        view.addTabViewItem(tabItem)
        view.selectTabViewItem(tabItem)
        
        // Feed some text into terminal and render initial image
        let sample = "Hello Nally Terminal".data(using: .ascii)!
        term.feedData(sample, connection: conn)
        view.updateBackedImage()
        
        // After updateBackedImage(), all dirty flags are cleared
        #expect(term.isRowDirty(0) == false)
        #expect(view._backedImageCG != nil)
        
        // Simulate unfocus / backing properties change (e.g. True Tone, sleep/wake, WindowServer)
        view.viewDidChangeBackingProperties()
        
        // Backing image must be regenerated and rows cleaned after full redraw
        #expect(view._backedImageCG != nil)
        #expect(term.isRowDirty(0) == false)
        
        // Simulate idle disconnect while unfocused
        conn.connected = false
        view.selectAll(nil)
        #expect(view._selectionLength > 0)
        #expect(view.selectedPlainString()?.contains("Hello Nally Terminal") == true)
    }
    
    @Test("Address Bar Focus Triggered by OpenLocation and NewTab")
    func testAddressBarFocusFromControllerActions() {
        let appState = AppState.shared
        let controller = YLController()
        let view = YLView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        controller._telnetView = view
        
        appState.focusAddressBar = false
        controller.openLocation(nil)
        #expect(appState.focusAddressBar == true)
        
        appState.focusAddressBar = false
        appState.addressText = "ptt.cc"
        controller.newTab(nil)
        #expect(appState.focusAddressBar == true)
        #expect(appState.addressText == "")
        appState.focusAddressBar = false
    }
    
    @Test("Address Bar NSTextField Lookup and First Responder Focus")
    func testAddressFieldLookupAndFocus() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                              styleMask: [.titled], backing: .buffered, defer: false)
        let container = NSView(frame: window.contentRect(forFrameRect: window.frame))
        
        let otherField = NSTextField(labelWithString: "Status")
        let addressField = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 22))
        addressField.placeholderString = "Go to this address"
        let nested = NSView(frame: container.bounds)
        nested.addSubview(addressField)
        container.addSubview(otherField)
        container.addSubview(nested)
        window.contentView = container
        
        // Non-editable labels are skipped; the placeholder-matched field is found.
        #expect(YLController.findAddressField(in: container) === addressField)
        
        let controller = YLController()
        controller._mainWindow = window
        #expect(controller.focusAddressField() == true)
        let responder = window.firstResponder
        #expect(responder === addressField || (responder as? NSText)?.delegate === addressField)
    }
    
    @Test("Type-Safe NSTabViewItem and TabInfo Connection Accessors")
    func testTypeSafeTabViewItemConnectionAndTerminal() {
        let conn = YLConnection()
        let term = YLTerminal()
        conn.terminal = term
        
        let item = NSTabViewItem()
        item.connection = conn
        #expect(item.connection === conn)
        #expect(item.terminal === term)
        
        let tabInfo = TabInfo(label: "1. PTT", icon: nil, isSelected: true, tabItem: item)
        #expect(tabInfo.connection === conn)
        #expect(tabInfo.terminal === term)
    }
    
    @Test("YLLGlobalConfig Color Change Refreshes CoreText Attributes and Appearance Callback")
    func testGlobalConfigColorChangeRefreshesCoreTextAttributes() {
        let config = YLLGlobalConfig.sharedInstance()
        let originalRed = config.colorRed
        defer { config.colorRed = originalRed }
        
        var appearanceCallbackCount = 0
        let prevCallback = config.onAppearanceChange
        config.onAppearanceChange = {
            appearanceCallbackCount += 1
            prevCallback?()
        }
        defer { config.onAppearanceChange = prevCallback }
        
        let customRed = NSColor(calibratedRed: 0.91, green: 0.12, blue: 0.23, alpha: 1.0)
        config.colorRed = customRed
        #expect(appearanceCallbackCount == 1)
        
        let dict = config.chineseAttribute(withHilite: 0, index: 1) as? [String: Any]
        let attrColor = dict?[kCTForegroundColorAttributeName as String] as? NSColor
        #expect(attrColor == config.colorAtIndex(1, hilite: false))
    }
    
    @Test("YLLGlobalConfig Dynamic Zoom and Reset")
    func testGlobalConfigZoomAndReset() {
        let config = YLLGlobalConfig.sharedInstance()
        config.resetZoom()
        #expect(config.cellWidth == 12.0)
        #expect(config.cellHeight == 24.0)
        #expect(config.chineseFontSize == 22.0)
        #expect(config.englishFontSize == 18.0)
        
        config.zoomIn()
        #expect(config.cellWidth == 13.0)
        #expect(config.cellHeight == 26.0)
        #expect(config.chineseFontSize > 22.0)
        #expect(config.englishFontSize > 18.0)
        
        config.zoomOut()
        #expect(config.cellWidth == 12.0)
        #expect(config.cellHeight == 24.0)
        
        config.resetZoom()
    }
}
