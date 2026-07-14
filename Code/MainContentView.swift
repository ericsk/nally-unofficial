import SwiftUI

public struct MainContentView: View {
    private let controller: YLController
    private let width: CGFloat
    private let height: CGFloat
    
    public init(controller: YLController) {
        self.controller = controller
        let config = YLLGlobalConfig.sharedInstance()
        self.width = CGFloat(config.cellWidth) * CGFloat(config.column)
        self.height = CGFloat(config.cellHeight) * CGFloat(config.row)
    }
    
    public var body: some View {
        TerminalViewRepresentable(controller: controller)
            .frame(width: width, height: height)
            .background(Color.black)
    }
}
