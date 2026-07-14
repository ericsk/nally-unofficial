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
        var objects: NSArray? = []
        let success = Bundle.main.loadNibNamed("MainMenu", owner: NSApp, topLevelObjects: &objects)
        NSLog("[Nally] loadNibNamed success: \(success), objects count: \(objects?.count ?? 0)")
        
        guard let objects = objects else { return }
        
        if let controller = objects.first(where: { $0 is YLController }) as? YLController {
            self.controller = controller
            setupToolbar(for: controller)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            NSLog("[Nally] FAILED to find YLController in Nib objects!")
        }
    }
    
    private func setupToolbar(for controller: YLController) {
        guard let window = controller.value(forKey: "_mainWindow") as? NSWindow else {
            NSLog("[Nally] FAILED to get _mainWindow from YLController!")
            return
        }
        
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
        
        // --- Calculate content dimensions ---
        let globalConfig = YLLGlobalConfig.sharedInstance()
        let termWidth = globalConfig.cellWidth * CGFloat(globalConfig.column)
        let termHeight = globalConfig.cellHeight * CGFloat(globalConfig.row)
        let tabBarHeight: CGFloat = 22
        
        // --- Create a plain AppKit container view ---
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: termWidth, height: termHeight + tabBarHeight))
        containerView.autoresizingMask = [.width, .height]
        
        // --- PSMTabBarControl at top (pure AppKit, bypasses SwiftUI NSViewRepresentable issues) ---
        let tabBar = PSMTabBarControl(frame: NSRect(x: 0, y: termHeight, width: termWidth, height: tabBarHeight))
        tabBar.autoresizingMask = [.width, .minYMargin]
        tabBar.setHideForSingleTab(false)
        tabBar.setCanCloseOnlyTab(true)
        tabBar.setTabView(telnetView)
        tabBar.setPartnerView(telnetView)
        tabBar.setDelegate(controller)
        // PSMTabBarControl implements NSTabViewDelegate methods but doesn't formally
        // declare protocol conformance, so Swift's `as? NSTabViewDelegate` returns nil.
        // Use performSelector to bypass Swift's protocol conformance check.
        telnetView.perform(NSSelectorFromString("setDelegate:"), with: tabBar)
        controller.setValue(tabBar, forKey: "_tab")
        containerView.addSubview(tabBar)
        
        // --- Terminal view via SwiftUI (NSHostingView) below tab bar ---
        let mainContentView = MainContentView(controller: controller)
        let hostingView = NSHostingView(rootView: mainContentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: termWidth, height: termHeight)
        hostingView.autoresizingMask = [.width, .height]
        containerView.addSubview(hostingView)
        
        // --- Set as window content ---
        window.contentView = containerView
        
        // --- Post-setup: create initial tabs ---
        controller.setupAfterSwiftUI()
        
        window.makeKeyAndOrderFront(nil)
    }
}
