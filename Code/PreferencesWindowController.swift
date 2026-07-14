import Cocoa
import SwiftUI

@objc(PreferencesWindowController)
@objcMembers
public class PreferencesWindowController: NSWindowController {
    public static let shared = PreferencesWindowController()
    
    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Preferences"
        window.center()
        
        let hostingView = NSHostingView(rootView: PreferencesView())
        window.contentView = hostingView
        
        super.init(window: window)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public class func show() {
        shared.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
