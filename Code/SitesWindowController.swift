import Cocoa
import SwiftUI

@objc(SitesWindowController)
@objcMembers
public class SitesWindowController: NSWindowController {
    private static var activeInstance: SitesWindowController?
    private weak var parentWindow: NSWindow?
    private let manager: SitesManager
    
    private init(parentWindow: NSWindow, controller: YLController) {
        self.parentWindow = parentWindow
        self.manager = SitesManager(controller: controller)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 420),
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Sites"
        
        super.init(window: window)
        
        let sitesView = SitesView(
            manager: manager,
            onConnect: { [weak self] site in
                controller.newConnection(with: site)
                self?.dismiss()
            },
            onClose: { [weak self] in
                self?.dismiss()
            }
        )
        window.contentView = NSHostingView(rootView: sitesView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public class func show(over mainWindow: NSWindow, controller: YLController) {
        if activeInstance == nil {
            let instance = SitesWindowController(parentWindow: mainWindow, controller: controller)
            activeInstance = instance
            mainWindow.beginSheet(instance.window!) { _ in
                activeInstance = nil
            }
        }
    }
    
    private func dismiss() {
        manager.save()
        if let parent = parentWindow, let window = window {
            parent.endSheet(window)
        }
    }
}
