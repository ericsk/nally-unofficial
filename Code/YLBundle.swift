import Cocoa

@objc(YLBundle)
@objcMembers
open class YLBundle: NSObject {
    public var title: String = "<name undefined>"
    private var _description: String = "<description undefined>"
    
    open override var description: String {
        return _description
    }
    
    public var descriptionString: String {
        get { return _description }
        set { _description = newValue }
    }
    
    private var pluginsMenu: NSMenu? = NSApp.mainMenu?.item(withTitle: "Plugins")?.submenu
    
    public override init() {
        super.init()
    }
    
    @objc public func icon() -> NSImage? {
        let currBundle = Bundle(for: type(of: self))
        if let bundleIconName = currBundle.object(forInfoDictionaryKey: "CFBundleIconFile") as? String {
            if let iconPathStr = currBundle.path(forResource: bundleIconName, ofType: nil) {
                return NSImage(contentsOfFile: iconPathStr)
            }
        }
        return nil
    }
    
    @objc public func localizedString(forKey key: String) -> String {
        return Bundle(for: type(of: self)).localizedString(forKey: key, value: "", table: nil)
    }
    
    @objc public func pluginMenu() -> NSMenu? {
        guard let pluginsMenu = pluginsMenu else { return nil }
        
        if let existingPluginMenu = pluginsMenu.item(withTitle: self.title)?.submenu {
            return existingPluginMenu
        }
        
        let pluginMenuItem = NSMenuItem(title: self.title, action: nil, keyEquivalent: "")
        pluginMenuItem.toolTip = self.description
        pluginsMenu.addItem(pluginMenuItem)
        
        let subMenu = NSMenu(title: self.title)
        pluginMenuItem.submenu = subMenu
        return subMenu
    }
    
    @objc public func addMenuItem(_ item: NSMenuItem) {
        item.target = self
        pluginMenu()?.addItem(item)
    }
    
    @objc(addMenuItemWithTitle:action:keyEquivalent:)
    @discardableResult
    public func addMenuItem(withTitle title: String, action: Selector?, keyEquivalent: String) -> NSMenuItem? {
        return pluginMenu()?.addItem(withTitle: title, action: action, keyEquivalent: keyEquivalent)
    }
}
