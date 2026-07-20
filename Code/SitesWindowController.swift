import Cocoa
import SwiftUI

@objc(SitesWindowController)
@objcMembers
public class SitesWindowController: NSWindowController, NSWindowDelegate {
    public static var shared: SitesWindowController?
    private let controller: YLController
    
    private init(controller: YLController) {
        self.controller = controller
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 420),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Sites"
        
        super.init(window: window)
        window.delegate = self
        
        let sitesView = SitesView(
            controller: controller,
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
    
    public func windowWillClose(_ notification: Notification) {
        controller.saveSites()
    }
    
    @objc(showOver:controller:)
    public class func show(over mainWindow: NSWindow, controller: YLController) {
        if shared == nil {
            shared = SitesWindowController(controller: controller)
        }
        shared?.window?.center()
        shared?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func dismiss() {
        window?.close()
    }
}
