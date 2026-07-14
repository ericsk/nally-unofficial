import SwiftUI
import Cocoa

public struct TabBarRepresentable: NSViewRepresentable {
    public typealias NSViewType = PSMTabBarControl
    
    private weak var controller: YLController?
    
    public init(controller: YLController) {
        self.controller = controller
    }
    
    public func makeNSView(context: Context) -> PSMTabBarControl {
        let tabBar = PSMTabBarControl(frame: .zero)
        tabBar.setDelegate(controller as? PSMTabBarControlDelegate)
        
        if let controller = controller {
            tabBar.setTabView(controller.telnetView() as? NSTabView)
            tabBar.setCanCloseOnlyTab(true)
            
            // Set the outlet in YLController so it can access it (e.g. for resizing/refreshes)
            controller.setValue(tabBar, forKey: "_tab")
        }
        
        return tabBar
    }
    
    public func updateNSView(_ nsView: PSMTabBarControl, context: Context) {
        if let controller = controller, let telnetView = controller.telnetView() as? NSTabView {
            if nsView.tabView() != telnetView {
                nsView.setTabView(telnetView)
            }
        }
    }
}
