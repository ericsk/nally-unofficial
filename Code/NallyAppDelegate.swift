import Cocoa
import SwiftUI

private var toolbarDelegateKey: UInt8 = 0

@objc(NallyAppDelegate)
public class NallyAppDelegate: NSObject, NSApplicationDelegate {
    public static var shared: NallyAppDelegate!
    
    public override init() {
        super.init()
        NallyAppDelegate.shared = self
    }
    
    @objc public var controller: YLController?
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        let mainController = AppState.shared.controller
        self.controller = mainController
        if let ylApp = NSApp as? YLApplication {
            ylApp._controller = mainController
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}
