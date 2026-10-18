import Cocoa
import SwiftUI

extension YLController {
    // MARK: - Application Delegate
    @objc public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        _mainWindow?.makeKeyAndOrderFront(self)
        return false
    }
    
    @objc public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let tabNumber = _telnetView?.numberOfTabViewItems ?? 0
        
        if UserDefaults.standard.bool(forKey: "RestoreConnection") {
            saveLastConnections()
        }
        
        let confirm = (UserDefaults.standard.object(forKey: "ConfirmOnClose") as? Bool) ?? true
        if !confirm {
            return .terminateNow
        }
        
        var hasConnectedConnection = false
        for i in 0..<tabNumber {
            if let connection = _telnetView?.tabViewItem(at: i).connection, connection.connected {
                hasConnectedConnection = true
                break
            }
        }
        if !hasConnectedConnection { return .terminateNow }
        
        let errorMessage = String(format: NSLocalizedString("There are %d tabs open in Nally. Do you want to quit anyway?", comment: "Sheet Message"), tabNumber)
        
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Are you sure you want to quit Nally?", comment: "Sheet Title")
        alert.informativeText = errorMessage
        alert.addButton(withTitle: NSLocalizedString("Quit", comment: "Default Button"))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Cancel Button"))
        
        if let window = _mainWindow {
            alert.beginSheetModal(for: window) { response in
                if response == .alertFirstButtonReturn {
                    NSApp.reply(toApplicationShouldTerminate: true)
                } else {
                    NSApp.reply(toApplicationShouldTerminate: false)
                }
            }
        } else {
            return .terminateNow
        }
        
        return .terminateLater
    }
    
    // MARK: - Window Delegate
    @objc public func windowShouldClose(_ window: NSWindow) -> Bool {
        let confirm = (UserDefaults.standard.object(forKey: "ConfirmOnClose") as? Bool) ?? true
        let connectedCount = connectedTabCount()
        
        if confirm && connectedCount > 0 {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("Are you sure you want to close the window?", comment: "Sheet Title")
            alert.informativeText = String(format: NSLocalizedString("There are %d active connections. Closing the window will disconnect them.", comment: "Sheet Message"), connectedCount)
            alert.addButton(withTitle: NSLocalizedString("Close Window", comment: "Default Button"))
            alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Cancel Button"))
            
            alert.beginSheetModal(for: window) { [weak self] response in
                if response == .alertFirstButtonReturn {
                    self?.closeAllTabsAndOrderOut()
                }
            }
            return false
        } else {
            closeAllTabsAndOrderOut()
            return true
        }
    }
    
    private func connectedTabCount() -> Int {
        guard let tv = _telnetView else { return 0 }
        var count = 0
        for i in 0..<tv.numberOfTabViewItems {
            if let conn = tv.tabViewItem(at: i).connection, conn.connected {
                count += 1
            }
        }
        return count
    }
    
    private func closeAllTabsAndOrderOut() {
        guard let tv = _telnetView else {
            _mainWindow?.orderOut(self)
            return
        }
        for item in tv.tabViewItems {
            if let conn = item.connection {
                conn.terminal?.hasMessage = false
                conn.close()
            }
        }
        _mainWindow?.orderOut(self)
    }
    
    @objc public func windowDidBecomeKey(_ notification: Notification) {
        guard let tv = _telnetView else { return }
        tv.frontMostTerminal()?.setAllDirty()
        tv.updateBackedImage()
        tv.needsDisplay = true
    }
    
    @objc public func windowDidResignKey(_ notification: Notification) {
    }
    
    @objc public func windowDidChangeOcclusionState(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window.occlusionState.contains(.visible),
              let tv = _telnetView else { return }
        tv.frontMostTerminal()?.setAllDirty()
        tv.updateBackedImage()
        tv.needsDisplay = true
    }
    
    @objc public func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        let globalConfig = YLLGlobalConfig.sharedInstance()
        let cols = CGFloat(max(1, globalConfig.column))
        let rows = CGFloat(max(1, globalConfig.row))
        let chromeHeight = sender.frame.height - (sender.contentView?.frame.height ?? 0) + 26
        
        let proposedTermWidth = max(6.0 * cols, min(30.0 * cols, frameSize.width))
        let stepWidth = (proposedTermWidth / cols * 2.0).rounded() / 2.0
        let stepHeight = stepWidth * 2.0
        
        return NSSize(
            width: stepWidth * cols,
            height: stepHeight * rows + chromeHeight
        )
    }
    
    @objc public func windowDidEndLiveResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        let globalConfig = YLLGlobalConfig.sharedInstance()
        let cols = CGFloat(max(1, globalConfig.column))
        let newWidth = window.frame.width / cols
        globalConfig.applyCellSize(width: newWidth, height: newWidth * 2.0)
    }
    
    @objc public func getUrl(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard var url = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue else { return }
        if url.lowercased().hasPrefix("bbs://") {
            url = String(url.dropFirst(6))
        }
        let finalAddress = connect(toAddressString: url)
        AppState.shared.addressText = finalAddress
    }
    
    // MARK: - Tab Delegate
    @objc public func tabView(_ tabView: YLView, shouldClose tabViewItem: NSTabViewItem) -> Bool {
        return true
    }
    
    @objc public func tabView(_ tabView: YLView, willClose tabViewItem: NSTabViewItem) {
    }
    
    @objc public func tabView(_ tabView: YLView, didClose tabViewItem: NSTabViewItem) {
        tabViewItem.connection?.close()
    }
    
    @MainActor
    @objc public func tabView(_ tabView: YLView, didSelect tabViewItem: NSTabViewItem?) {
        guard let conn = tabViewItem?.connection else { return }
        conn.terminal?.setAllDirty()
        _telnetView?.updateBackedImage()
        AppState.shared.addressText = conn.connectionAddress ?? ""
        _telnetView?.needsDisplay = true
        if let tv = _telnetView, let window = _mainWindow {
            window.makeFirstResponder(tv)
        }
        conn.terminal?.hasMessage = false
        
        AppState.shared.syncTabs(from: tabView)
        NotificationCenter.default.post(name: YLController.encodingDidChangeNotification, object: conn.terminal)
        NotificationCenter.default.post(name: YLView.tabSelectionDidChangeNotification, object: tabView)
    }
    
    @objc public func tabView(_ tabView: YLView, shouldSelect tabViewItem: NSTabViewItem?) -> Bool {
        return true
    }
    
    @objc public func tabView(_ tabView: YLView, willSelect tabViewItem: NSTabViewItem?) {
        guard let conn = tabViewItem?.connection else { return }
        conn.terminal?.setAllDirty()
        _telnetView?.clearSelection()
    }
    
    @MainActor
    @objc public func tabViewDidChangeNumberOfTabViewItems(_ tabView: YLView) {
        refreshTabLabelNumber(tabView)
        AppState.shared.syncTabs(from: tabView)
    }
    
    @objc public func refreshTabLabelNumber(_ tabView: YLView) {
        let tabNumber = tabView.numberOfTabViewItems
        for i in 0..<tabNumber {
            let item = tabView.tabViewItem(at: i)
            let connName = item.connection?.connectionName ?? ""
            item.label = "\(i + 1). \(connName)"
        }
    }
}
