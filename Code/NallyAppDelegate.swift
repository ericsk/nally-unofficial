import Cocoa
import SwiftUI


@objc(NallyAppDelegate)
public class NallyAppDelegate: NSObject, NSApplicationDelegate {
    public static var shared: NallyAppDelegate!
    
    public override init() {
        super.init()
        NallyAppDelegate.shared = self
    }
    
    @objc public var controller: YLController?
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        let savedTheme = UserDefaults.standard.string(forKey: "AppTheme") ?? AppTheme.system.rawValue
        AppTheme.applyTheme(rawValue: savedTheme)
        
        let mainController = AppState.shared.controller
        self.controller = mainController
        if let ylApp = NSApp as? YLApplication {
            ylApp._controller = mainController
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}
