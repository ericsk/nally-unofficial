//
//  YLController.swift
//  Nally
//
//  Created by Yung-Luen Lan on 9/11/07.
//  Copyright 2007-2026 yllan.org. All rights reserved.
//

import Cocoa
import Combine
import Observation
import SwiftData

@MainActor
@Observable
@objc(YLController)
@objcMembers
public class YLController: NSObject, NSWindowDelegate {
    @objc public dynamic weak var _mainWindow: NSWindow?
    @objc public dynamic var _telnetView: YLView?
    @objc public dynamic weak var _addressBar: NSTextField?
    public static let encodingDidChangeNotification = Notification.Name("YLEncodingDidChangeNotification")
    
    public var sitesList: [YLSite] = []
    public var modelContainer: ModelContainer?
    private var cancellables = Set<AnyCancellable>()
    private var lastConnectionTime = Date.distantPast
    private var lastConnectionAddress = ""
    @objc public dynamic var _pluginLoader: YLPluginLoader?
    @objc public dynamic weak var _exifController: YLExifController?
    

    
    // MARK: - Initializer & Lifecycle
    @MainActor
    @objc public func setupProgrammatically() {
        // Register defaults
        UserDefaults.standard.register(defaults: [
            "ConfirmOnClose": true,
            "RestoreConnection": false
        ])
        
        // Register URL event handler
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(getUrl(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
        
        let globalConfig = YLLGlobalConfig.sharedInstance()
        
        globalConfig.publisher(for: \.messageCount)
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
            
        globalConfig.publisher(for: \.shouldSmoothFonts)
            .sink { [weak self] _ in
                self?.refreshTerminalState()
            }
            .store(in: &cancellables)
            
        Publishers.Merge(
            globalConfig.publisher(for: \.cellWidth).map { _ in () },
            globalConfig.publisher(for: \.cellHeight).map { _ in () }
        )
        .sink { [weak self] _ in
            self?.updateWindowAndTerminalLayout()
        }
        .store(in: &cancellables)
            
        let fontAndColorPublishers: [AnyPublisher<Void, Never>] = [
            globalConfig.publisher(for: \.chineseFontName).map { _ in () }.eraseToAnyPublisher(),
            globalConfig.publisher(for: \.chineseFontSize).map { _ in () }.eraseToAnyPublisher(),
            globalConfig.publisher(for: \.englishFontName).map { _ in () }.eraseToAnyPublisher(),
            globalConfig.publisher(for: \.englishFontSize).map { _ in () }.eraseToAnyPublisher(),
            globalConfig.publisher(for: \.chineseFontPaddingLeft).map { _ in () }.eraseToAnyPublisher(),
            globalConfig.publisher(for: \.chineseFontPaddingBottom).map { _ in () }.eraseToAnyPublisher(),
            globalConfig.publisher(for: \.englishFontPaddingLeft).map { _ in () }.eraseToAnyPublisher(),
            globalConfig.publisher(for: \.englishFontPaddingBottom).map { _ in () }.eraseToAnyPublisher()
        ]
        
        Publishers.MergeMany(fontAndColorPublishers)
            .sink { [weak self] _ in
                globalConfig.refreshFont()
                self?.refreshTerminalState()
            }
            .store(in: &cancellables)
            
        globalConfig.showHiddenText = globalConfig.showHiddenText
        globalConfig.cellWidth = globalConfig.cellWidth
        
        initSwiftData()
        updateSitesMenu()
        
        _pluginLoader = YLPluginLoader()
        
        if UserDefaults.standard.bool(forKey: "RestoreConnection") {
            loadLastConnections()
        }
        
        Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateBlinkTicker(_:)), userInfo: nil, repeats: true)
    }
    
    
    
    private var isWindowSetupDone = false
    
    func findAddressBar(in view: NSView) -> NSTextField? {
        if let tf = view as? NSTextField, tf.placeholderString == "Go to this address" {
            return tf
        }
        for subview in view.subviews {
            if let tf = findAddressBar(in: subview) {
                return tf
            }
        }
        return nil
    }
    
    @objc(setupWindow:)
    public func setupWindow(_ window: NSWindow) {
        self._mainWindow = window
        if window.delegate !== self {
            window.delegate = self
        }
        if isWindowSetupDone { return }
        isWindowSetupDone = true
        
        window.hasShadow = false
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
        
        setupAfterSwiftUI()
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
    
    // MARK: - Menu Updates (Obsolete: Handled declaratively by SwiftUI NallyCommands)
    @objc public func updateSitesMenu() {
    }
    
    @objc public func updateEncodingMenu() {
    }
    
    @objc public func updateBlinkTicker(_ timer: Timer) {
        YLLGlobalConfig.sharedInstance().updateBlinkTicker()
        if _telnetView?.hasBlinkCell() ?? false {
            _telnetView?.needsDisplay = true
        }
    }
    
    // MARK: - Connection Management
    public func newConnection(with site: YLSite) {
        let now = Date()
        if site.address == lastConnectionAddress && now.timeIntervalSince(lastConnectionTime) < 0.5 {
            NSLog("[Nally] Ignored duplicate connection request to site: \(site.name)")
            return
        }
        lastConnectionTime = now
        lastConnectionAddress = site.address
        
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
            
            _ = connection.connect(to: site)
            _telnetView?.selectTabViewItem(tabItem)
            _telnetView?.updateBackedImage()
            _telnetView?.needsDisplay = true
            
            if let tv = _telnetView {
                refreshTabLabelNumber(tv)
            }
            updateEncodingMenu()
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if let tv = self._telnetView, let window = self._mainWindow {
                    window.makeFirstResponder(tv)
                }
            }
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
    
    // MARK: - Serialization (SwiftData & Keychain)
    @MainActor
    public func initSwiftData() {
        do {
            let container = try ModelContainer(for: YLSite.self)
            self.modelContainer = container
            syncSitesWithSwiftData()
        } catch {
            NSLog("Failed to initialize SwiftData ModelContainer: \(error)")
            loadSites()
        }
    }
    
    @MainActor
    public func syncSitesWithSwiftData() {
        guard let container = modelContainer else {
            loadSites()
            return
        }
        let context = container.mainContext
        do {
            let descriptor = FetchDescriptor<YLSite>(sortBy: [SortDescriptor(\.name)])
            var fetched = try context.fetch(descriptor)
            
            if fetched.isEmpty {
                // Migrate legacy sites from UserDefaults if available
                loadSites()
                if !sitesList.isEmpty {
                    for site in sitesList {
                        context.insert(site)
                    }
                    try? context.save()
                    fetched = try context.fetch(descriptor)
                } else {
                    // Seed default site
                    let defaultSite = YLSite(
                        name: "PTT 批踢踢實業坊",
                        address: "ptt.cc",
                        encoding: .YLBig5Encoding,
                        ansiColorKey: .YLCtrlUANSIColorKey,
                        detectDoubleByte: true
                    )
                    context.insert(defaultSite)
                    try? context.save()
                    fetched = [defaultSite]
                }
            }
            
            for site in fetched {
                if let accounts = YLKeychain.accounts(forService: site.address),
                   let account = accounts.last?["acct"] as? String {
                    if let password = YLKeychain.password(forService: site.address, account: account) {
                        site.account = account
                        site.password = password
                    }
                }
            }
            
            self.sitesList = fetched
            updateSitesMenu()
        } catch {
            NSLog("SwiftData sync error: \(error)")
            loadSites()
        }
    }

    @MainActor
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
                            mutableDict["account"] = account
                            mutableDict["password"] = password
                        }
                    }
                }
                let site = YLSite.site(withDictionary: mutableDict as! [String : Any])
                sitesList.append(site)
            }
            saveSites()
        }
    }
    
    @MainActor
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
        if let container = modelContainer {
            let context = container.mainContext
            try? context.save()
        } else {
            do {
                let encodedData = try JSONEncoder().encode(sitesList)
                UserDefaults.standard.set(encodedData, forKey: "SitesCodable")
                UserDefaults.standard.synchronize()
            } catch {
                NSLog("Failed to encode SitesCodable: \(error)")
            }
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
                if let site = connection.site {
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
    
    // MARK: - MenuItem Validation
    @objc public func validateMenuItem(_ item: NSMenuItem) -> Bool {
        let action = item.action
        let numTabs = _telnetView?.numberOfTabViewItems ?? 0
        if (action == #selector(selectNextTab(_:)) || action == #selector(selectPrevTab(_:))) && numTabs == 0 {
            return false
        } else if action == #selector(setEncodingAction(_:)) && numTabs == 0 {
            return false
        }
        return true
    }
}
