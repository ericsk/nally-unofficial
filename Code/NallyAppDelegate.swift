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
        NSLog("[Nally] Loading MainMenu.xib...")
        var objects: NSArray? = []
        let success = Bundle.main.loadNibNamed("MainMenu", owner: NSApp, topLevelObjects: &objects)
        NSLog("[Nally] loadNibNamed success: \(success), objects count: \(objects?.count ?? 0)")
        
        guard let objects = objects else { return }
        
        if let controller = objects.first(where: { $0 is YLController }) as? YLController {
            NSLog("[Nally] Found YLController instance!")
            self.controller = controller
            setupToolbar(for: controller)
            NSApp.activate(ignoringOtherApps: true)
            NSLog("[Nally] NSApp.activate called")
        } else {
            NSLog("[Nally] FAILED to find YLController in Nib objects!")
        }
    }
    
    private func setupToolbar(for controller: YLController) {
        NSLog("[Nally] setupToolbar started")
        guard let window = controller.value(forKey: "_mainWindow") as? NSWindow else {
            NSLog("[Nally] FAILED to get _mainWindow from YLController!")
            return
        }
        NSLog("[Nally] Found _mainWindow! title: \(window.title)")
        
        let toolbarDelegate = NallyToolbarDelegate(controller: controller)
        objc_setAssociatedObject(window, &toolbarDelegateKey, toolbarDelegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        let toolbar = NSToolbar(identifier: "NallyMainToolbar")
        toolbar.delegate = toolbarDelegate
        toolbar.allowsUserCustomization = true
        toolbar.autosavesConfiguration = true
        toolbar.displayMode = .iconOnly
        
        window.toolbar = toolbar
        
        let mainContentView = MainContentView(controller: controller)
        window.contentView = NSHostingView(rootView: mainContentView)
        
        window.makeKeyAndOrderFront(nil)
        NSLog("[Nally] makeKeyAndOrderFront called on window")
    }
}
