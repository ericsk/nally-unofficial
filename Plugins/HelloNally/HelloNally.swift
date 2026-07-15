import Cocoa

@objc(HelloNally)
@objcMembers
public class HelloNally: YLBundle {
    public override init() {
        super.init()
        self.descriptionString = self.localizedString(forKey: "BundleDescription")
        self.title = self.localizedString(forKey: "BundleTitle")
        
        NSLog("Loading Bundle HelloNally.")
        self.addMenuItem(withTitle: "Hey", action: nil, keyEquivalent: "")
    }
}
