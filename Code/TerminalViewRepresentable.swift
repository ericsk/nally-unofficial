import SwiftUI
import Cocoa

public struct TerminalViewRepresentable: NSViewRepresentable {
    public typealias NSViewType = YLView
    
    private weak var controller: YLController?
    
    public init(controller: YLController) {
        self.controller = controller
    }
    
    public func makeNSView(context: Context) -> YLView {
        if let view = controller?.telnetView() as? YLView {
            return view
        }
        
        let view = YLView(frame: .zero)
        
        // 1. Create and associate YLMarkedTextView programmatically
        let markedTextView = YLMarkedTextView(frame: .zero)
        view._textField = markedTextView
        view.addSubview(markedTextView)
        
        // 2. Configure the YLView
        view.configure()
        
        // 3. Associate with the controller if provided
        if let controller = controller {
            controller._telnetView = view
        }
        
        return view
    }
    
    public func updateNSView(_ nsView: YLView, context: Context) {
        // Drawing and updates are driven by YLTerminal/YLConnection, so we don't need to do anything here.
    }
}
