import SwiftUI
import Cocoa

@Observable
public class AppState {
    public static let shared = AppState()
    
    public let controller: YLController
    public let exifController: YLExifController
    
    public var addressText: String = ""
    
    public var termWidth: CGFloat = 960
    public var termHeight: CGFloat = 576
    
    public init() {
        let exif = YLExifController()
        let ctrl = YLController()
        
        ctrl.setValue(exif, forKey: "_exifController")
        
        self.exifController = exif
        self.controller = ctrl
        
        // 1. Setup controllers programmatically
        ctrl.setupProgrammatically()
        
        // 2. Precreate YLView & YLMarkedTextView
        let telnetView = YLView(frame: .zero)
        let markedTextView = YLMarkedTextView(frame: .zero)
        telnetView.setValue(markedTextView, forKey: "_textField")
        telnetView.addSubview(markedTextView)
        telnetView.configure()
        ctrl.setValue(telnetView, forKey: "_telnetView")
        
        // 3. Precreate PSMTabBarControl
        let tabBar = PSMTabBarControl(frame: NSRect(x: 0, y: 0, width: 800, height: 22))
        tabBar.setHideForSingleTab(false)
        tabBar.setCanCloseOnlyTab(true)
        tabBar.setTabView(telnetView)
        tabBar.setPartnerView(telnetView)
        tabBar.setDelegate(ctrl)
        telnetView.perform(NSSelectorFromString("setDelegate:"), with: tabBar)
        ctrl.setValue(tabBar, forKey: "_tab")
        
        updateDimensions()
    }
    
    public func updateDimensions() {
        let globalConfig = YLLGlobalConfig.sharedInstance()
        self.termWidth = globalConfig.cellWidth * CGFloat(globalConfig.column)
        self.termHeight = globalConfig.cellHeight * CGFloat(globalConfig.row)
    }
    
    public func handleURL(_ url: URL) {
        var address = url.absoluteString
        if url.scheme == "bbs" {
            address = address.replacingOccurrences(of: "bbs://", with: "")
        }
        let finalAddress = controller.connect(toAddressString: address)
        self.addressText = finalAddress
    }
}

@main
struct NallyApp: App {
    @NSApplicationDelegateAdaptor(NallyAppDelegate.self) var appDelegate
    @State private var appState = AppState.shared
    
    var body: some Scene {
        Window("Nally", id: "main") {
            MainSwiftUIWindowView(appState: appState)
        }
        .commands {
            NallyCommands()
        }
        
        Settings {
            PreferencesView()
        }
    }
}

struct MainSwiftUIWindowView: View {
    var appState: AppState
    @Bindable var config = YLLGlobalConfig.sharedInstance()
    
    var body: some View {
        VStack(spacing: 0) {
            TabBarRepresentable(controller: appState.controller)
                .frame(height: 22)
            
            MainContentView(controller: appState.controller)
        }
        .background(Color.black)
        .toolbar {
            ToolbarItem(id: "sites") {
                Button(action: {
                    appState.controller.editSites(nil)
                }) {
                    Label("Sites", systemImage: "bookmark")
                }
                .help("Manage Sites")
            }
            
            ToolbarItem(id: "address") {
                HStack {
                    TextField("Go to this address", text: Bindable(appState).addressText, onCommit: {
                        let finalAddress = appState.controller.connect(toAddressString: appState.addressText)
                        appState.addressText = finalAddress
                    })
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 280)
                }
            }
            
            ToolbarItem(id: "doubleByte") {
                Toggle(isOn: $config.detectDoubleByte) {
                    Text("雙")
                        .font(.system(size: 13, weight: .bold))
                }
                .toggleStyle(.button)
                .help("Toggle Double Byte Detection")
                .onChange(of: config.detectDoubleByte) { _, newValue in
                    let btn = NSButton()
                    btn.state = newValue ? .on : .off
                    appState.controller.setDetectDoubleByteAction(btn)
                }
            }
            
            ToolbarItem(id: "showHiddenText") {
                Toggle(isOn: $config.showHiddenText) {
                    Image(systemName: config.showHiddenText ? "eye" : "eye.slash")
                }
                .toggleStyle(.button)
                .help("Toggle Show Hidden Text")
                .onChange(of: config.showHiddenText) { _, newValue in
                    let btn = NSButton()
                    btn.state = newValue ? .on : .off
                    appState.controller.showHiddenText(btn)
                }
            }
            
            ToolbarItem(id: "login") {
                Button(action: {
                    appState.controller.autoLogin(nil)
                }) {
                    Text("L")
                        .font(.system(size: 13, weight: .bold))
                }
                .help("Auto Login")
            }
        }
        .background(WindowAccessor { window in
            appState.controller.setupWindow(window)
        })
        .onOpenURL { url in
            appState.handleURL(url)
        }
    }
}

struct WindowAccessor: NSViewRepresentable {
    var callback: (NSWindow) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                callback(window)
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window {
            callback(window)
        }
    }
}
