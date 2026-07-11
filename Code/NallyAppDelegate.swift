import Cocoa

private var toolbarDelegateKey: UInt8 = 0

@objc(NallyAppDelegate)
public class NallyAppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        var objects: NSArray? = []
        Bundle.main.loadNibNamed("MainMenu", owner: NSApp, topLevelObjects: &objects)
        
        setupToolbar()
    }
    
    private func setupToolbar() {
        guard let controller = NSApp.delegate as? YLController,
              let window = controller.value(forKey: "_mainWindow") as? NSWindow else {
            return
        }
        
        let toolbarDelegate = NallyToolbarDelegate(controller: controller)
        objc_setAssociatedObject(window, &toolbarDelegateKey, toolbarDelegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        let toolbar = NSToolbar(identifier: "NallyMainToolbar")
        toolbar.delegate = toolbarDelegate
        toolbar.allowsUserCustomization = true
        toolbar.autosavesConfiguration = true
        toolbar.displayMode = .iconOnly
        
        window.toolbar = toolbar
    }
}
