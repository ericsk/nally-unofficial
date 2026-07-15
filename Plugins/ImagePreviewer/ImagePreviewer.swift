import Cocoa

@objc(ImagePreviewer)
@objcMembers
public class ImagePreviewer: YLBundle {
    private var enabled: Bool = true
    
    public override init() {
        super.init()
        self.descriptionString = self.localizedString(forKey: "BundleDescription")
        self.title = self.localizedString(forKey: "BundleTitle")
        self.enabled = true
        
        NSLog("Loading Bundle ImagePreviewer.")
        
        let item = NSMenuItem(
            title: self.localizedString(forKey: "EnableImagePreview"),
            action: #selector(flipEnabled(_:)),
            keyEquivalent: ""
        )
        item.state = .on
        self.addMenuItem(item)
    }
    
    @IBAction public func flipEnabled(_ sender: Any?) {
        enabled = !enabled
        if let menuItem = sender as? NSMenuItem {
            menuItem.state = enabled ? .on : .off
        }
    }
}
