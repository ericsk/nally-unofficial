import Cocoa
import SwiftUI

@objc(NallyToolbarDelegate)
public class NallyToolbarDelegate: NSObject, NSToolbarDelegate {
    private weak var controller: YLController?
    
    private var sitesButton: NSButton?
    private var addressBar: NSTextField?
    private var doubleByteButton: NSButton?
    private var showHiddenButton: NSButton?
    private var loginButton: NSButton?
    
    @objc public init(controller: YLController) {
        self.controller = controller
        super.init()
        setupViews()
    }
    
    private func setupViews() {
        guard let controller = controller else { return }
        
        // 1. Sites Button
        let btnSites = NSButton(frame: NSRect(x: 0, y: 0, width: 36, height: 28))
        btnSites.bezelStyle = .texturedRounded
        btnSites.image = NSImage(systemSymbolName: "bookmark", accessibilityDescription: "Sites")
        btnSites.target = controller
        btnSites.action = #selector(YLController.editSites(_:))
        btnSites.toolTip = "Manage Sites"
        self.sitesButton = btnSites
        
        // 2. Address Bar
        let tfAddress = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        tfAddress.placeholderString = "Go to this address"
        tfAddress.bezelStyle = .roundedBezel
        tfAddress.target = controller
        tfAddress.action = #selector(YLController.connect(_:))
        controller.setAddressBar(tfAddress)
        self.addressBar = tfAddress
        
        // 3. Double Byte Button
        let btnDoubleByte = NSButton(frame: NSRect(x: 0, y: 0, width: 36, height: 28))
        btnDoubleByte.setButtonType(.pushOnPushOff)
        btnDoubleByte.bezelStyle = .texturedRounded
        btnDoubleByte.title = "雙"
        btnDoubleByte.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        btnDoubleByte.target = controller
        btnDoubleByte.action = #selector(YLController.setDetectDoubleByteAction(_:))
        btnDoubleByte.toolTip = "Toggle Double Byte Detection"
        controller.setDetectDoubleByteButton(btnDoubleByte)
        self.doubleByteButton = btnDoubleByte
        
        // 4. Show Hidden Button
        let btnShowHidden = NSButton(frame: NSRect(x: 0, y: 0, width: 36, height: 28))
        btnShowHidden.setButtonType(.pushOnPushOff)
        btnShowHidden.bezelStyle = .texturedRounded
        btnShowHidden.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "Show Hidden Text")
        btnShowHidden.target = self
        btnShowHidden.action = #selector(toggleShowHidden(_:))
        btnShowHidden.toolTip = "Toggle Show Hidden Text"
        
        NotificationCenter.default.addObserver(self, selector: #selector(syncShowHiddenButton), name: UserDefaults.didChangeNotification, object: nil)
        self.showHiddenButton = btnShowHidden
        syncShowHiddenButton()
        
        // 5. Login Button
        let btnLogin = NSButton(frame: NSRect(x: 0, y: 0, width: 36, height: 28))
        btnLogin.bezelStyle = .texturedRounded
        btnLogin.title = "L"
        btnLogin.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        btnLogin.target = controller
        btnLogin.action = #selector(YLController.autoLogin(_:))
        btnLogin.toolTip = "Auto Login"
        self.loginButton = btnLogin
    }
    
    @objc private func toggleShowHidden(_ sender: NSButton) {
        guard let controller = controller else { return }
        let show = (sender.state == .on)
        YLLGlobalConfig.sharedInstance().showHiddenText = show
        
        controller.showHiddenText(sender)
    }
    
    @objc private func syncShowHiddenButton() {
        let show = YLLGlobalConfig.sharedInstance().showHiddenText
        showHiddenButton?.state = show ? .on : .off
    }
    
    // MARK: - NSToolbarDelegate
    
    public func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.sites, .address, .doubleByte, .showHiddenText, .login, .flexibleSpace, .space]
    }
    
    public func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.sites, .address, .doubleByte, .showHiddenText, .login]
    }
    
    public func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        
        switch itemIdentifier {
        case .sites:
            item.label = "Sites"
            item.paletteLabel = "Sites"
            item.view = sitesButton
            
        case .address:
            item.label = "Address"
            item.paletteLabel = "Address"
            item.view = addressBar
            
        case .doubleByte:
            item.label = "Double Byte"
            item.paletteLabel = "Double Byte"
            item.view = doubleByteButton
            
        case .showHiddenText:
            item.label = "Show Hidden Text"
            item.paletteLabel = "Show Hidden Text"
            item.view = showHiddenButton
            
        case .login:
            item.label = "Login"
            item.paletteLabel = "Login"
            item.view = loginButton
            
        default:
            return nil
        }
        
        return item
    }
}

extension NSToolbarItem.Identifier {
    public static let sites = NSToolbarItem.Identifier("NallySites")
    public static let address = NSToolbarItem.Identifier("NallyAddress")
    public static let doubleByte = NSToolbarItem.Identifier("NallyDoubleByte")
    public static let showHiddenText = NSToolbarItem.Identifier("NallyShowHiddenText")
    public static let login = NSToolbarItem.Identifier("NallyLogin")
}
