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
        
        // --- Toolbar ---
        let toolbarDelegate = NallyToolbarDelegate(controller: controller)
        objc_setAssociatedObject(window, &toolbarDelegateKey, toolbarDelegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        let toolbar = NSToolbar(identifier: "NallyMainToolbar")
        toolbar.delegate = toolbarDelegate
        toolbar.allowsUserCustomization = true
        toolbar.autosavesConfiguration = true
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar
        
        // --- Pre-create YLView (NSTabView subclass) ---
        let telnetView = YLView(frame: .zero)
        let markedTextView = YLMarkedTextView(frame: .zero)
        telnetView.setValue(markedTextView, forKey: "_textField")
        telnetView.addSubview(markedTextView)
        telnetView.configure()
        controller.setValue(telnetView, forKey: "_telnetView")
        
        // --- Pre-create PSMTabBarControl ---
        let tabBar = PSMTabBarControl(frame: NSRect(x: 0, y: 0, width: 800, height: 22))
        tabBar.setHideForSingleTab(false)
        tabBar.setCanCloseOnlyTab(true)
        tabBar.setTabView(telnetView)
        tabBar.setPartnerView(telnetView)
        tabBar.setDelegate(controller)
        // PSMTabBarControl intercepts NSTabView delegate calls, so set it as the tabView's delegate
        telnetView.delegate = (tabBar as AnyObject) as? NSTabViewDelegate
        controller.setValue(tabBar, forKey: "_tab")
        
        NSLog("[Nally] Pre-created YLView and PSMTabBarControl, wired delegate chain")
        
        // --- SwiftUI content view (representables will re-use pre-created views) ---
        let mainContentView = MainContentView(controller: controller)
        window.contentView = NSHostingView(rootView: mainContentView)
        
        // --- Post-setup: create initial tabs ---
        controller.setupAfterSwiftUI()
        
        window.makeKeyAndOrderFront(nil)
        NSLog("[Nally] makeKeyAndOrderFront called on window")
    }
}
