import Cocoa
import SwiftUI

extension YLController {
    // MARK: - Actions
    public func setDetectDoubleByte(_ ddb: Bool) {
        ((_telnetView?.frontMostConnection() as? YLConnection)?.site as? YLSite)?.detectDoubleByte = ddb
    }
    
    @IBAction public func setDetectDoubleByteAction(_ sender: Any?) {
        var ddb: Bool
        if let control = sender as? NSControl {
            ddb = control.integerValue != 0
        } else if let menuItem = sender as? NSMenuItem {
            ddb = menuItem.state == .off
        } else if let boolVal = sender as? Bool {
            ddb = boolVal
        } else {
            ddb = false
        }
        setDetectDoubleByte(ddb)
    }
    
    @objc(setEncodingWithEncoding:)
    public func setEncoding(_ encoding: YLEncoding) {
        guard let term = _telnetView?.frontMostTerminal() else { return }
        guard term.encoding != encoding else { return }
        term.encoding = encoding
        term.setAllDirty()
        _telnetView?.updateBackedImage()
        _telnetView?.needsDisplay = true
        NotificationCenter.default.post(name: YLController.encodingDidChangeNotification, object: term)
    }
    
    @IBAction
    @objc(setEncoding:)
    public func setEncodingAction(_ sender: Any?) {
        if let enc = sender as? YLEncoding {
            setEncoding(enc)
            return
        }
        if let menuItem = sender as? NSMenuItem {
            if let enc = YLEncoding(rawValue: UInt16(menuItem.tag)) {
                setEncoding(enc)
                return
            }
        }
    }
    
    @IBAction public func newTab(_ sender: Any?) {
        let connection = YLConnection()
        connection.connectionAddress = ""
        connection.connectionName = ""
        let tabItem = NSTabViewItem(identifier: connection)
        _telnetView?.addTabViewItem(tabItem)
        _telnetView?.selectTabViewItem(tabItem)
        
        let s = YLSite()
        s.encoding = YLLGlobalConfig.sharedInstance().defaultEncoding
        s.detectDoubleByte = YLLGlobalConfig.sharedInstance().detectDoubleByte
        connection.site = s
        
        if let window = _mainWindow {
            window.makeKeyAndOrderFront(self)
        }
        _telnetView?.resignFirstResponder()
        _addressBar?.becomeFirstResponder()
    }
    
    @objc(connectToAddressString:)
    public func connect(toAddressString addressString: String) -> String {
        var ssh = false
        var name = addressString
        if name.lowercased().hasPrefix("ssh://") {
            ssh = true
        }
        if name.lowercased().hasPrefix("telnet://") {
            name = String(name.dropFirst(9))
        }
        if name.lowercased().hasPrefix("bbs://") {
            name = String(name.dropFirst(6))
        }
        
        var matchedSites: [YLSite] = []
        var connectSite = YLSite()
        
        if name.contains(".") { /* Normal address */
            for site in sitesList {
                let address = site.address
                if address.contains(name) && !(ssh != address.hasPrefix("ssh://")) {
                    matchedSites.append(site)
                }
            }
            if !matchedSites.isEmpty {
                matchedSites.sort { $0.address.count < $1.address.count }
                if let firstSite = matchedSites.first {
                    connectSite = firstSite.copySite()
                }
            } else {
                connectSite.address = addressString
                connectSite.name = name
                connectSite.encoding = YLLGlobalConfig.sharedInstance().defaultEncoding
                connectSite.ansiColorKey = YLLGlobalConfig.sharedInstance().defaultANSIColorKey
                connectSite.detectDoubleByte = YLLGlobalConfig.sharedInstance().detectDoubleByte
            }
        } else { /* Short Address? */
            for site in sitesList {
                let sName = site.name
                if sName.contains(name) {
                    matchedSites.append(site)
                }
            }
            matchedSites.sort { $0.name.count < $1.name.count }
            if matchedSites.isEmpty {
                for site in sitesList {
                    let address = site.address
                    if address.contains(name) {
                        matchedSites.append(site)
                    }
                }
                matchedSites.sort { $0.address.count < $1.address.count }
            }
            if !matchedSites.isEmpty {
                if let firstSite = matchedSites.first {
                    connectSite = firstSite.copySite()
                }
            } else {
                connectSite.address = addressString
                connectSite.name = name
                connectSite.encoding = YLLGlobalConfig.sharedInstance().defaultEncoding
                connectSite.ansiColorKey = YLLGlobalConfig.sharedInstance().defaultANSIColorKey
                connectSite.detectDoubleByte = YLLGlobalConfig.sharedInstance().detectDoubleByte
            }
        }
        newConnection(with: connectSite)
        return connectSite.address
    }
    
    @IBAction public func connect(_ sender: Any?) {
        guard let textField = sender as? NSTextField else { return }
        textField.abortEditing()
        _telnetView?.window?.makeFirstResponder(_telnetView)
        let finalAddress = connect(toAddressString: textField.stringValue)
        textField.stringValue = finalAddress
    }
    
    @IBAction public func openLocation(_ sender: Any?) {
        if let window = _mainWindow {
            window.makeKeyAndOrderFront(self)
            if let superview = window.contentView?.superview, let tf = findAddressBar(in: superview) {
                let success = window.makeFirstResponder(tf)
                if success {
                    tf.selectText(self)
                }
                NSLog("[Nally] openLocation focus success: \(success)")
            } else {
                NSLog("[Nally] openLocation could not find address bar")
            }
        }
    }
    
    @IBAction public func selectNextTab(_ sender: Any?) {
        guard let tv = _telnetView, let selected = tv.selectedTabViewItem else { return }
        if tv.indexOfTabViewItem(selected) == tv.numberOfTabViewItems - 1 {
            tv.selectFirstTabViewItem(self)
        } else {
            tv.selectNextTabViewItem(self)
        }
    }
    
    @IBAction public func selectPrevTab(_ sender: Any?) {
        guard let tv = _telnetView, let selected = tv.selectedTabViewItem else { return }
        if tv.indexOfTabViewItem(selected) == 0 {
            tv.selectLastTabViewItem(self)
        } else {
            tv.selectPreviousTabViewItem(self)
        }
    }
    
    @IBAction public func selectTabNumber(_ index: Int32) {
        if let tv = _telnetView, index <= tv.numberOfTabViewItems {
            tv.selectTabViewItem(at: Int(index - 1))
        }
    }
    
    @IBAction public func closeTab(_ sender: Any?) {
        guard let tv = _telnetView else { return }
        if tv.numberOfTabViewItems == 0 { return }
        
        guard let tabItem = tv.selectedTabViewItem else { return }
        closeTabViewItem(tabItem)
    }
    
    @objc public func closeTabViewItem(_ tabItem: NSTabViewItem) {
        guard _telnetView != nil else { return }
        guard let connection = tabItem.identifier as? YLConnection else {
            performCloseTabViewItem(tabItem)
            return
        }
        
        let confirm = (UserDefaults.standard.object(forKey: "ConfirmOnClose") as? Bool) ?? true
        if connection.connected && confirm {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("Are you sure you want to close this tab?", comment: "Sheet Title")
            alert.informativeText = NSLocalizedString("The connection is still alive. If you close this tab, the connection will be lost. Do you want to close this tab anyway?", comment: "Sheet Message")
            alert.addButton(withTitle: NSLocalizedString("Close", comment: "Default Button"))
            alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Cancel Button"))
            
            if let window = _mainWindow {
                alert.beginSheetModal(for: window) { [weak self] response in
                    if response == .alertFirstButtonReturn {
                        self?.performCloseTabViewItem(tabItem)
                    }
                }
            } else {
                performCloseTabViewItem(tabItem)
            }
        } else {
            performCloseTabViewItem(tabItem)
        }
    }
    
    private func performCloseTabViewItem(_ tabItem: NSTabViewItem) {
        guard let tv = _telnetView else { return }
        tabView(tv, willClose: tabItem)
        if let connection = tabItem.identifier as? YLConnection {
            connection.terminal?.hasMessage = false
            connection.close()
        }
        tv.removeTabViewItem(tabItem)
        tabView(tv, didClose: tabItem)
    }
    
    @MainActor
    @objc public func closeOtherTabs(except keepItem: NSTabViewItem) {
        guard let tv = _telnetView else { return }
        let allItems = tv.tabViewItems
        for item in allItems where item != keepItem {
            performCloseTabViewItem(item)
        }
        tv.selectTabViewItem(keepItem)
        refreshTabLabelNumber(tv)
        AppState.shared.syncTabs(from: tv)
    }
    
    @MainActor
    @objc public func moveTab(fromIndex: Int, toIndex: Int) {
        guard let tv = _telnetView else { return }
        tv.moveTab(fromIndex: fromIndex, toIndex: toIndex)
        refreshTabLabelNumber(tv)
        AppState.shared.syncTabs(from: tv)
    }
    
    @IBAction public func editSites(_ sender: Any?) {
        AppState.shared.openSitesWindowAction?()
    }
    
    @IBAction public func openSites(_ sender: Any?) {
        // Unused in Nally UI but preserved
    }
    
    @IBAction public func closeSites(_ sender: Any?) {
        // Unused in Nally UI but preserved
    }
    
    @IBAction public func openSiteMenu(_ sender: Any?) {
        if let menuItem = sender as? NSMenuItem, let site = menuItem.representedObject as? YLSite {
            newConnection(with: site)
        }
    }
    
    @IBAction public func autoLogin(_ sender: Any?) {
        guard let conn = _telnetView?.frontMostConnection() as? YLConnection else { return }
        guard let site = conn.site?.copySite() else { return }
        
        if conn.connected {
            let account = site.account
            let password = site.password
            if !account.isEmpty && !password.isEmpty {
                _telnetView?.insertText("\(account)\n\(password)\n", withDelay: 0)
            }
        }
    }
    
    public func setShowHiddenText(_ show: Bool) {
        YLLGlobalConfig.sharedInstance().showHiddenText = show
        _telnetView?.refreshHiddenRegion()
        _telnetView?.updateBackedImage()
        _telnetView?.needsDisplay = true
    }
    
    @IBAction public func showHiddenText(_ sender: Any?) {
        var show: Bool
        if let menuItem = sender as? NSMenuItem {
            show = menuItem.state == .off
        } else if let control = sender as? NSControl {
            show = control.integerValue != 0
        } else if let boolVal = sender as? Bool {
            show = boolVal
        } else {
            show = false
        }
        setShowHiddenText(show)
    }
    
    @IBAction public func openPreferencesWindow(_ sender: Any?) {
        if #available(macOS 13, *) {
            NSApp.sendAction(NSSelectorFromString("showSettingsWindow:"), to: nil, from: nil)
        } else {
            NSApp.sendAction(NSSelectorFromString("showPreferencesWindow:"), to: nil, from: nil)
        }
    }
}
