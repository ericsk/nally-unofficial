//
//  YLController.swift
//  Nally
//
//  Created by Yung-Luen Lan on 9/11/07.
//  Copyright 2007-2026 yllan.org. All rights reserved.
//

import Cocoa
import Combine

@objc(YLController)
public class YLController: NSObject, NSTabViewDelegate, NSWindowDelegate {
    @IBOutlet @objc public dynamic weak var _mainWindow: NSWindow?
    @IBOutlet @objc public dynamic var _telnetView: YLView?
    @IBOutlet @objc public dynamic weak var _addressBar: NSTextField?
    @IBOutlet @objc public dynamic weak var _detectDoubleByteButton: NSButton?
    
    @IBOutlet @objc public dynamic weak var _detectDoubleByteMenuItem: NSMenuItem?
    @IBOutlet @objc public dynamic weak var _closeWindowMenuItem: NSMenuItem?
    @IBOutlet @objc public dynamic weak var _closeTabMenuItem: NSMenuItem?
    
    @IBOutlet @objc public dynamic weak var _sitesMenu: NSMenuItem?
    @IBOutlet @objc public dynamic weak var _showHiddenTextMenuItem: NSMenuItem?
    @IBOutlet @objc public dynamic weak var _encodingMenuItem: NSMenuItem?
    @IBOutlet @objc public dynamic weak var _exifController: YLExifController?
    
    public var sitesList: [YLSite] = []
    private var cancellables = Set<AnyCancellable>()
    @objc public dynamic var _pluginLoader: YLPluginLoader?
    
    // MARK: - KVC Compliance Accessors for Sites
    @objc public func sites() -> NSArray {
        return sitesList as NSArray
    }
    
    @objc public func countOfSites() -> Int {
        return sitesList.count
    }
    
    @objc public func objectInSitesAtIndex(_ index: Int) -> Any {
        return sitesList[index]
    }
    
    @objc public func insertObject(_ obj: Any, inSitesAtIndex index: Int) {
        if let site = obj as? YLSite {
            sitesList.insert(site, at: index)
        }
    }
    
    @objc public func removeObjectFromSitesAtIndex(_ index: Int) {
        sitesList.remove(at: index)
    }
    
    @objc public func replaceObjectInSitesAtIndex(_ index: Int, withObject obj: Any) {
        if let site = obj as? YLSite {
            sitesList[index] = site
        }
    }
    
    // MARK: - Initializer & Lifecycle
    @objc public func setupProgrammatically() {
        // Register URL event handler
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(getUrl(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
        
        let globalConfig = YLLGlobalConfig.sharedInstance()
        
        globalConfig.publisher(for: \._showHiddenText)
            .sink { [weak self] show in
                self?._showHiddenTextMenuItem?.state = show ? .on : .off
            }
            .store(in: &cancellables)
            
        globalConfig.publisher(for: \._messageCount)
            .sink { count in
                let dockTile = NSApp.dockTile
                if count == 0 {
                    dockTile.badgeLabel = nil
                } else {
                    dockTile.badgeLabel = "\(count)"
                }
                dockTile.display()
            }
            .store(in: &cancellables)
            
        globalConfig.publisher(for: \._shouldSmoothFonts)
            .sink { [weak self] _ in
                self?.refreshTerminalState()
            }
            .store(in: &cancellables)
            
        Publishers.Merge(
            globalConfig.publisher(for: \._cellWidth).map { _ in () },
            globalConfig.publisher(for: \._cellHeight).map { _ in () }
        )
        .sink { [weak self] _ in
            self?.updateWindowAndTerminalLayout()
        }
        .store(in: &cancellables)
            
        let fontAndColorPublishers: [AnyPublisher<Void, Never>] = [
            globalConfig.publisher(for: \._chineseFontName).map { _ in () }.eraseToAnyPublisher(),
            globalConfig.publisher(for: \._chineseFontSize).map { _ in () }.eraseToAnyPublisher(),
            globalConfig.publisher(for: \._englishFontName).map { _ in () }.eraseToAnyPublisher(),
            globalConfig.publisher(for: \._englishFontSize).map { _ in () }.eraseToAnyPublisher(),
            globalConfig.publisher(for: \._chineseFontPaddingLeft).map { _ in () }.eraseToAnyPublisher(),
            globalConfig.publisher(for: \._chineseFontPaddingBottom).map { _ in () }.eraseToAnyPublisher(),
            globalConfig.publisher(for: \._englishFontPaddingLeft).map { _ in () }.eraseToAnyPublisher(),
            globalConfig.publisher(for: \._englishFontPaddingBottom).map { _ in () }.eraseToAnyPublisher()
        ]
        
        Publishers.MergeMany(fontAndColorPublishers)
            .sink { [weak self] _ in
                globalConfig.refreshFont()
                self?.refreshTerminalState()
            }
            .store(in: &cancellables)
            
        globalConfig.showHiddenText = globalConfig.showHiddenText
        globalConfig.cellWidth = globalConfig.cellWidth
        
        loadSites()
        updateSitesMenu()
        
        _pluginLoader = YLPluginLoader()
        
        if UserDefaults.standard.bool(forKey: "RestoreConnection") {
            loadLastConnections()
        }
        
        Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateBlinkTicker(_:)), userInfo: nil, repeats: true)
    }
    
    @objc override public func awakeFromNib() {
        setupProgrammatically()
        if let window = _mainWindow {
            setupWindow(window)
        }
    }
    
    @objc(setupWindow:)
    public func setupWindow(_ window: NSWindow) {
        self._mainWindow = window
        window._setContentHasShadow(false)
        window.isOpaque = false
        if #available(macOS 11.0, *) {
            window.toolbarStyle = .expanded
        }
        window.setFrameAutosaveName("nallyMainWindowFrame")
        
        let globalConfig = YLLGlobalConfig.sharedInstance()
        let shift = window.frame.height - (window.contentView?.frame.height ?? 0) + 22
        var r = window.frame
        let topLeftCorner = r.origin.y + r.size.height
        r.size.width = globalConfig.cellWidth * CGFloat(globalConfig.column)
        r.size.height = globalConfig.cellHeight * CGFloat(globalConfig.row) + shift
        r.origin.y = topLeftCorner - r.size.height
        window.setFrame(r, display: true, animate: false)
        _telnetView?.configure()
    }
    
    @objc public func setupAfterSwiftUI() {
        _telnetView?.configure()
        
        let globalConfig = YLLGlobalConfig.sharedInstance()
        if let window = _mainWindow {
            let shift = window.frame.height - (window.contentView?.frame.height ?? 0) + 22
            var r = window.frame
            let topLeftCorner = r.origin.y + r.size.height
            r.size.width = globalConfig.cellWidth * CGFloat(globalConfig.column)
            r.size.height = globalConfig.cellHeight * CGFloat(globalConfig.row) + shift
            r.origin.y = topLeftCorner - r.size.height
            window.setFrame(r, display: true, animate: false)
        }
        
        if UserDefaults.standard.bool(forKey: "RestoreConnection") {
            loadLastConnections()
        }
    }
    
    // MARK: - Menu Updates
    @objc public func updateSitesMenu() {
        guard let submenu = _sitesMenu?.submenu else { return }
        let total = submenu.numberOfItems
        if total > 3 {
            for _ in 3..<total {
                submenu.removeItem(at: 3)
            }
        }
        
        for site in sitesList {
            let menuItem = NSMenuItem(title: site.name, action: #selector(openSiteMenu(_:)), keyEquivalent: "")
            menuItem.representedObject = site
            submenu.addItem(menuItem)
        }
    }
    
    @objc public func updateEncodingMenu() {
        guard let submenu = _encodingMenuItem?.submenu else { return }
        for i in 0..<submenu.numberOfItems {
            let item = submenu.item(at: i)
            item?.state = .off
            if let term = _telnetView?.frontMostTerminal(), i == Int(term.encoding.rawValue) {
                item?.state = .on
            }
        }
    }
    
    @objc public func updateBlinkTicker(_ timer: Timer) {
        YLLGlobalConfig.sharedInstance().updateBlinkTicker()
        if _telnetView?.hasBlinkCell() ?? false {
            _telnetView?.needsDisplay = true
        }
    }
    
    // MARK: - Connection Management
    @objc(newConnectionWithSite:)
    public func newConnection(with site: YLSite) {
        autoreleasepool {
            let terminal = YLTerminal()
            let connection = YLConnection.connection(withAddress: site.address)
            
            let emptyTab = _telnetView?.frontMostConnection() != nil && _telnetView?.frontMostTerminal() == nil
            
            terminal.encoding = site.encoding
            terminal.setAllDirty()
            connection.terminal = terminal
            connection.connectionName = site.name
            connection.connectionAddress = site.address
            terminal.delegate = _telnetView
            terminal.pluginLoader = _pluginLoader
            
            let tabItem: NSTabViewItem
            
            if emptyTab, let selectedItem = _telnetView?.selectedTabViewItem {
                tabItem = selectedItem
                tabItem.identifier = connection
            } else {
                tabItem = NSTabViewItem(identifier: connection)
                _telnetView?.addTabViewItem(tabItem)
            }
            
            tabItem.label = site.name
            
            connection.connect(to: site)
            _telnetView?.selectTabViewItem(tabItem)
            _telnetView?.updateBackedImage()
            _telnetView?.needsDisplay = true
            
            if let tv = _telnetView {
                refreshTabLabelNumber(tv)
            }
            updateEncodingMenu()
            
            let ddb = site.detectDoubleByte
            _detectDoubleByteButton?.state = ddb ? .on : .off
            _detectDoubleByteMenuItem?.state = ddb ? .on : .off
        }
    }
    
    // MARK: - KVO Observers Helpers
    private func refreshTerminalState() {
        (_telnetView?.selectedTabViewItem?.identifier as? YLConnection)?.terminal?.setAllDirty()
        _telnetView?.updateBackedImage()
        _telnetView?.needsDisplay = true
    }
    
    private func updateWindowAndTerminalLayout() {
        let globalConfig = YLLGlobalConfig.sharedInstance()
        if let window = _mainWindow {
            let shift = window.frame.height - (window.contentView?.frame.height ?? 0) + 22
            var r = window.frame
            let topLeftCorner = r.origin.y + r.size.height
            r.size.width = globalConfig.cellWidth * CGFloat(globalConfig.column)
            r.size.height = globalConfig.cellHeight * CGFloat(globalConfig.row) + shift
            r.origin.y = topLeftCorner - r.size.height
            window.setFrame(r, display: true, animate: false)
            
            _telnetView?.configure()
            (_telnetView?.selectedTabViewItem?.identifier as? YLConnection)?.terminal?.setAllDirty()
            _telnetView?.updateBackedImage()
            _telnetView?.needsDisplay = true
            
        }
    }
    
    // MARK: - Serialization (User Defaults & Keychain)
    @objc public func loadSites() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: "SitesCodable") {
            do {
                let decodedSites = try JSONDecoder().decode([YLSite].self, from: data)
                self.sitesList = decodedSites
                for site in sitesList {
                    if let accounts = YLKeychain.accounts(forService: site.address),
                       let account = accounts.last?["acct"] as? String {
                        if let password = YLKeychain.password(forService: site.address, account: account) {
                            site.account = account
                            site.password = password
                        }
                    }
                }
            } catch {
                NSLog("Failed to decode SitesCodable: \(error)")
            }
        } else if let dictionaries = defaults.array(forKey: "Sites") as? [[String: Any]] {
            // Migration path
            for siteDict in dictionaries {
                let mutableDict = NSMutableDictionary(dictionary: siteDict)
                if let address = mutableDict["address"] as? String {
                    if let accounts = YLKeychain.accounts(forService: address),
                       let account = accounts.last?["acct"] as? String {
                        if let password = YLKeychain.password(forService: address, account: account) {
                            mutableDict.setValue(account, forKey: "account")
                            mutableDict.setValue(password, forKey: "password")
                        }
                    }
                }
                let site = YLSite.site(withDictionary: mutableDict as! [String : Any])
                insertObject(site, inSitesAtIndex: countOfSites())
            }
            saveSites()
        }
    }
    
    @objc public func saveSites() {
        for site in sitesList {
            let password = site.password
            let address = site.address
            if !password.isEmpty && !address.isEmpty {
                do {
                    try YLKeychain.setPassword(password, forService: address, account: site.account)
                } catch {
                    NSLog("keychain error reason: \(error.localizedDescription)")
                }
            }
        }
        do {
            let encodedData = try JSONEncoder().encode(sitesList)
            UserDefaults.standard.set(encodedData, forKey: "SitesCodable")
            UserDefaults.standard.synchronize()
        } catch {
            NSLog("Failed to encode SitesCodable: \(error)")
        }
        updateSitesMenu()
    }
    
    @objc public func loadLastConnections() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: "LastConnectionsCodable") {
            do {
                let decodedSites = try JSONDecoder().decode([YLSite].self, from: data)
                for site in decodedSites {
                    newConnection(with: site)
                }
            } catch {
                NSLog("Failed to decode LastConnectionsCodable: \(error)")
            }
        } else if let dictionaries = defaults.array(forKey: "LastConnections") as? [[String: Any]] {
            // Migration path
            for siteDict in dictionaries {
                let site = YLSite.site(withDictionary: siteDict)
                newConnection(with: site)
            }
        }
    }
    
    @objc public func saveLastConnections() {
        guard let tv = _telnetView else { return }
        let tabNumber = tv.numberOfTabViewItems
        var lastConnectedSites: [YLSite] = []
        for i in 0..<tabNumber {
            if let connection = tv.tabViewItem(at: i).identifier as? YLConnection, connection.terminal != nil {
                if let site = connection.site as? YLSite {
                    lastConnectedSites.append(site)
                }
            }
        }
        do {
            let encodedData = try JSONEncoder().encode(lastConnectedSites)
            UserDefaults.standard.set(encodedData, forKey: "LastConnectionsCodable")
            UserDefaults.standard.synchronize()
        } catch {
            NSLog("Failed to encode LastConnectionsCodable: \(error)")
        }
    }
    
    // MARK: - Actions
    @IBAction public func setDetectDoubleByteAction(_ sender: Any?) {
        var ddb: Bool
        if let control = sender as? NSControl {
            ddb = control.integerValue != 0
        } else if let menuItem = sender as? NSMenuItem {
            ddb = menuItem.state == .off
        } else {
            ddb = false
        }
        
        ((_telnetView?.frontMostConnection() as? YLConnection)?.site as? YLSite)?.detectDoubleByte = ddb
        _detectDoubleByteButton?.state = ddb ? .on : .off
        _detectDoubleByteMenuItem?.state = ddb ? .on : .off
    }
    
    @IBAction public func setEncoding(_ sender: Any?) {
        guard let menuItem = sender as? NSMenuItem, let submenu = _encodingMenuItem?.submenu else { return }
        let index = submenu.index(of: menuItem)
        if let term = _telnetView?.frontMostTerminal() {
            term.encoding = YLEncoding(rawValue: UInt16(index)) ?? .YLBig5Encoding
            term.setAllDirty()
            _telnetView?.updateBackedImage()
            _telnetView?.needsDisplay = true
            updateEncodingMenu()
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
        
        let matchedSites = NSMutableArray()
        var connectSite = YLSite()
        
        if name.contains(".") { /* Normal address */
            for site in sitesList {
                let address = site.address
                if address.contains(name) && !(ssh != address.hasPrefix("ssh://")) {
                    matchedSites.add(site)
                }
            }
            if matchedSites.count > 0 {
                matchedSites.sort(using: [NSSortDescriptor(key: "address.length", ascending: true)])
                if let firstSite = matchedSites.object(at: 0) as? YLSite {
                    connectSite = firstSite.copy() as! YLSite
                }
            } else {
                connectSite.address = name
                connectSite.name = name
                connectSite.encoding = YLLGlobalConfig.sharedInstance().defaultEncoding
                connectSite.ansiColorKey = YLLGlobalConfig.sharedInstance().defaultANSIColorKey
                connectSite.detectDoubleByte = YLLGlobalConfig.sharedInstance().detectDoubleByte
            }
        } else { /* Short Address? */
            for site in sitesList {
                let sName = site.name
                if sName.contains(name) {
                    matchedSites.add(site)
                }
            }
            matchedSites.sort(using: [NSSortDescriptor(key: "name.length", ascending: true)])
            if matchedSites.count == 0 {
                for site in sitesList {
                    let address = site.address
                    if address.contains(name) {
                        matchedSites.add(site)
                    }
                }
                matchedSites.sort(using: [NSSortDescriptor(key: "address.length", ascending: true)])
            }
            if matchedSites.count > 0 {
                if let firstSite = matchedSites.object(at: 0) as? YLSite {
                    connectSite = firstSite.copy() as! YLSite
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
        }
        AppState.shared.focusAddressBar = true
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
        if tabView(tv, shouldClose: tabItem) {
            tabView(tv, willClose: tabItem)
            (tabItem.identifier as? YLConnection)?.terminal?.hasMessage = false
            (tabItem.identifier as? YLConnection)?.close()
            tv.removeTabViewItem(tabItem)
            tabView(tv, didClose: tabItem)
        }
    }
    
    @IBAction public func editSites(_ sender: Any?) {
        if let window = _mainWindow {
            SitesWindowController.show(over: window, controller: self)
        }
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
        guard let site = (conn.site as? YLSite)?.copy() as? YLSite else { return }
        
        if conn.connected {
            let account = site.account
            let password = site.password
            if !account.isEmpty && !password.isEmpty {
                _telnetView?.insertText("\(account)\n\(password)\n", withDelay: 0)
            }
        }
    }
    
    @IBAction public func showHiddenText(_ sender: Any?) {
        var show: Bool
        if let menuItem = sender as? NSMenuItem {
            show = menuItem.state == .off
        } else if let control = sender as? NSControl {
            show = control.integerValue != 0
        } else {
            show = false
        }
        
        YLLGlobalConfig.sharedInstance().showHiddenText = show
        _telnetView?.refreshHiddenRegion()
        _telnetView?.updateBackedImage()
        _telnetView?.needsDisplay = true
    }
    
    @IBAction public func openPreferencesWindow(_ sender: Any?) {
        PreferencesWindowController.show()
    }
    
    // MARK: - Accessors
    @objc public func exifController() -> YLExifController? {
        return _exifController
    }
    
    @objc public func telnetView() -> Any? {
        return _telnetView
    }
    
    @objc public func setAddressBar(_ addressBar: Any?) {
        _addressBar = addressBar as? NSTextField
    }
    
    @objc public func setDetectDoubleByteButton(_ detectDoubleByteButton: Any?) {
        _detectDoubleByteButton = detectDoubleByteButton as? NSButton
    }
    
    // MARK: - MenuItem Validation
    @objc public func validateMenuItem(_ item: NSMenuItem) -> Bool {
        let action = item.action
        let numTabs = _telnetView?.numberOfTabViewItems ?? 0
        if (action == #selector(selectNextTab(_:)) || action == #selector(selectPrevTab(_:))) && numTabs == 0 {
            return false
        } else if action == #selector(setEncoding(_:)) && numTabs == 0 {
            return false
        }
        return true
    }
    
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
        
        if !UserDefaults.standard.bool(forKey: "ConfirmOnClose") {
            return .terminateNow
        }
        
        var hasConnectedConnection = false
        for i in 0..<tabNumber {
            if let connection = _telnetView?.tabViewItem(at: i).identifier as? YLConnection, connection.connected {
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
        _mainWindow?.orderOut(self)
        return false
    }
    
    @objc public func windowDidBecomeKey(_ notification: Notification) {
        _closeWindowMenuItem?.keyEquivalentModifierMask = [.command, .shift]
        _closeTabMenuItem?.keyEquivalent = "w"
    }
    
    @objc public func windowDidResignKey(_ notification: Notification) {
        _closeWindowMenuItem?.keyEquivalentModifierMask = [.command]
        _closeTabMenuItem?.keyEquivalent = ""
    }
    
    @objc public func getUrl(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard var url = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue else { return }
        if url.lowercased().hasPrefix("bbs://") {
            url = String(url.dropFirst(6))
        }
        _addressBar?.stringValue = url
        if let addressBar = _addressBar {
            connect(addressBar)
        }
    }
    
    // MARK: - Tab Delegate
    @objc public func tabView(_ tabView: NSTabView, shouldClose tabViewItem: NSTabViewItem) -> Bool {
        guard let connection = tabViewItem.identifier as? YLConnection else { return true }
        if !connection.connected { return true }
        if !UserDefaults.standard.bool(forKey: "ConfirmOnClose") { return true }
        
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Are you sure you want to close this tab?", comment: "Sheet Title")
        alert.informativeText = NSLocalizedString("The connection is still alive. If you close this tab, the connection will be lost. Do you want to close this tab anyway?", comment: "Sheet Message")
        alert.addButton(withTitle: NSLocalizedString("Close", comment: "Default Button"))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Cancel Button"))
        
        if let window = _mainWindow {
            alert.beginSheetModal(for: window) { [weak self] response in
                if response == .alertFirstButtonReturn {
                    connection.terminal?.hasMessage = false
                    self?._telnetView?.removeTabViewItem(tabViewItem)
                }
            }
        }
        return false
    }
    
    @objc public func tabView(_ tabView: NSTabView, willClose tabViewItem: NSTabViewItem) {
    }
    
    @objc public func tabView(_ tabView: NSTabView, didClose tabViewItem: NSTabViewItem) {
        (tabViewItem.identifier as? YLConnection)?.close()
    }
    
    @objc public func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        guard let conn = tabViewItem?.identifier as? YLConnection else { return }
        _telnetView?.updateBackedImage()
        _addressBar?.stringValue = conn.connectionAddress ?? ""
        _telnetView?.needsDisplay = true
        if let tv = _telnetView, let window = _mainWindow {
            window.makeFirstResponder(tv)
        }
        conn.terminal?.hasMessage = false
        updateEncodingMenu()
        
        let ddb = (conn.site as? YLSite)?.detectDoubleByte ?? false
        _detectDoubleByteButton?.state = ddb ? .on : .off
        _detectDoubleByteMenuItem?.state = ddb ? .on : .off
        
        AppState.shared.syncTabs(from: tabView)
    }
    
    @objc public func tabView(_ tabView: NSTabView, shouldSelect tabViewItem: NSTabViewItem?) -> Bool {
        return true
    }
    
    @objc public func tabView(_ tabView: NSTabView, willSelect tabViewItem: NSTabViewItem?) {
        guard let conn = tabViewItem?.identifier as? YLConnection else { return }
        conn.terminal?.setAllDirty()
        _telnetView?.clearSelection()
    }
    
    @objc public func tabViewDidChangeNumberOfTabViewItems(_ tabView: NSTabView) {
        refreshTabLabelNumber(tabView)
        AppState.shared.syncTabs(from: tabView)
    }
    
    @objc public func refreshTabLabelNumber(_ tabView: NSTabView) {
        let tabNumber = tabView.numberOfTabViewItems
        for i in 0..<tabNumber {
            let item = tabView.tabViewItem(at: i)
            let connName = (item.identifier as? YLConnection)?.connectionName ?? ""
            item.label = "\(i + 1). \(connName)"
        }
    }
}
