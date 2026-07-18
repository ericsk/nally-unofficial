import SwiftUI

public struct MainContentView: View {
    let controller: YLController
    @Bindable var config = YLLGlobalConfig.sharedInstance()
    
    public init(controller: YLController) {
        self.controller = controller
    }
    
    public var body: some View {
        TerminalViewRepresentable(controller: controller)
            .frame(
                width: CGFloat(config.cellWidth) * CGFloat(config.column),
                height: CGFloat(config.cellHeight) * CGFloat(config.row)
            )
            .background(Color.black)
    }
}
