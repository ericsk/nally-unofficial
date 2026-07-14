import SwiftUI
import Cocoa

public struct TabBarRepresentable: NSViewRepresentable {
    public typealias NSViewType = PSMTabBarControl
    
    private weak var controller: YLController?
    
    public init(controller: YLController) {
        self.controller = controller
    }
    
    public func makeNSView(context: Context) -> PSMTabBarControl {
        // Return the pre-created PSMTabBarControl from controller._tab
        if let tabBar = controller?.value(forKey: "_tab") as? PSMTabBarControl {
            return tabBar
        }
        
        // Fallback: create a new one (should not happen in normal flow)
        let tabBar = PSMTabBarControl(frame: NSRect(x: 0, y: 0, width: 800, height: 22))
        tabBar.setHideForSingleTab(false)
        tabBar.setCanCloseOnlyTab(true)
        if let controller = controller {
            tabBar.setDelegate(controller)
            if let telnetView = controller.telnetView() as? NSTabView {
                tabBar.setTabView(telnetView)
                tabBar.setPartnerView(telnetView)
                telnetView.delegate = (tabBar as AnyObject) as? NSTabViewDelegate
            }
            controller.setValue(tabBar, forKey: "_tab")
        }
        return tabBar
    }
    
    public func updateNSView(_ nsView: PSMTabBarControl, context: Context) {
        // No dynamic updates needed; the tab bar is driven by NSTabView delegate callbacks
    }
}
