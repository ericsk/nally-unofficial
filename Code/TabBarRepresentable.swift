import SwiftUI
import Cocoa

/// A wrapper NSView that hosts PSMTabBarControl and provides proper sizing for SwiftUI.
/// PSMTabBarControl doesn't support Auto Layout intrinsicContentSize, so we wrap it in
/// a container that manages its frame manually via layout().
public class TabBarContainerView: NSView {
    let tabBar: PSMTabBarControl
    
    init(tabBar: PSMTabBarControl) {
        self.tabBar = tabBar
        super.init(frame: NSRect(x: 0, y: 0, width: 800, height: 22))
        
        // Don't use Auto Layout for the tab bar - manage its frame manually
        tabBar.autoresizingMask = [.width]
        addSubview(tabBar)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public var intrinsicContentSize: NSSize {
        return NSSize(width: NSView.noIntrinsicMetric, height: 22)
    }
    
    override public func layout() {
        super.layout()
        tabBar.frame = bounds
    }
    
    override public var isFlipped: Bool {
        return true
    }
}

public struct TabBarRepresentable: NSViewRepresentable {
    public typealias NSViewType = TabBarContainerView
    
    private weak var controller: YLController?
    
    public init(controller: YLController) {
        self.controller = controller
    }
    
    public func makeNSView(context: Context) -> TabBarContainerView {
        let tabBar: PSMTabBarControl
        if let existingTab = controller?._tab {
            tabBar = existingTab
        } else {
            tabBar = PSMTabBarControl(frame: NSRect(x: 0, y: 0, width: 800, height: 22))
            tabBar.setHideForSingleTab(false)
            tabBar.setCanCloseOnlyTab(true)
            if let controller = controller {
                tabBar.setDelegate(controller)
                if let telnetView = controller.telnetView() as? NSTabView {
                    tabBar.setTabView(telnetView)
                    tabBar.setPartnerView(telnetView)
                    // PSMTabBarControl implements NSTabViewDelegate methods but doesn't formally
                    // declare protocol conformance, so use performSelector to bypass Swift's check.
                    telnetView.perform(NSSelectorFromString("setDelegate:"), with: tabBar)
                }
                controller._tab = tabBar
            }
        }
        
        return TabBarContainerView(tabBar: tabBar)
    }
    
    public func updateNSView(_ nsView: TabBarContainerView, context: Context) {
        let tabBar = nsView.tabBar
        tabBar.frame = nsView.bounds
        tabBar.isHidden = false
        tabBar.needsDisplay = true
    }
}
