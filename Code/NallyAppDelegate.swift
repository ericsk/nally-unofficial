import Cocoa

@objc(NallyAppDelegate)
public class NallyAppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        var objects: NSArray? = []
        Bundle.main.loadNibNamed("MainMenu", owner: NSApp, topLevelObjects: &objects)
    }
}
