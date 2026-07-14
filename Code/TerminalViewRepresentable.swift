import SwiftUI
import Cocoa

public struct TerminalViewRepresentable: NSViewRepresentable {
    public typealias NSViewType = YLView
    
    private weak var controller: YLController?
    
    public init(controller: YLController) {
        self.controller = controller
    }
    
    public func makeNSView(context: Context) -> YLView {
        let view = YLView(frame: .zero)
        
        // 1. Create and associate YLMarkedTextView programmatically
        let markedTextView = YLMarkedTextView(frame: .zero)
        view.setValue(markedTextView, forKey: "_textField")
        view.addSubview(markedTextView)
        
        // 2. Configure the YLView
        view.configure()
        
        // 3. Associate with the controller if provided
        if let controller = controller {
            controller.setValue(view, forKey: "_telnetView")
        }
        
        return view
    }
    
    public func updateNSView(_ nsView: YLView, context: Context) {
        // Drawing and updates are driven by YLTerminal/YLConnection, so we don't need to do anything here.
    }
}
