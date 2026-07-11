import SwiftUI

struct NallyCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Tab") {
                if let controller = NSApp.delegate as? YLController {
                    controller.newTab(nil)
                }
            }
            .keyboardShortcut("t", modifiers: .command)
            
            Button("Open Location...") {
                if let controller = NSApp.delegate as? YLController {
                    controller.openLocation(nil)
                }
            }
            .keyboardShortcut("l", modifiers: .command)
            
            Button("Close Tab") {
                if let controller = NSApp.delegate as? YLController {
                    controller.closeTab(nil)
                }
            }
            .keyboardShortcut("w", modifiers: .command)
        }
        
        CommandGroup(after: .pasteboard) {
            Button("Paste Wrap") {
                NSApp.sendAction(#selector(YLView.pasteWrap(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])
            
            Button("Paste Color") {
                NSApp.sendAction(#selector(YLView.pasteColor(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("v", modifiers: [.command, .option])
            
            Divider()
            
            Button("Customize Toolbar...") {
                if let window = NSApp.mainWindow {
                    window.runToolbarCustomizationPalette(nil)
                }
            }
        }
        
        CommandGroup(before: .sidebar) {
            ViewMenuCommands()
            
            EncodingPicker()
            
            Divider()
        }
        
        CommandMenu("Sites") {
            Button("Edit Sites...") {
                if let controller = NSApp.delegate as? YLController {
                    controller.editSites(nil)
                }
            }
            .keyboardShortcut("b", modifiers: .command)
            
            Divider()
            
            DynamicSitesMenu()
        }
        
        CommandMenu("Plugins") {
            // Keep empty; YLPluginLoader dynamically inserts items here
            EmptyView()
        }
        
        CommandGroup(after: .windowList) {
            Button("Select Next Tab") {
                if let controller = NSApp.delegate as? YLController {
                    controller.selectNextTab(nil)
                }
            }
            .keyboardShortcut("}", modifiers: .command)
            
            Button("Select Previous Tab") {
                if let controller = NSApp.delegate as? YLController {
                    controller.selectPrevTab(nil)
                }
            }
            .keyboardShortcut("{", modifiers: .command)
        }
    }
}

struct ViewMenuCommands: View {
    @Bindable var config = YLLGlobalConfig.sharedInstance()
    
    var body: some View {
        Toggle("Show Hidden Text", isOn: $config.showHiddenText)
        Toggle("Detect Double Byte", isOn: $config.detectDoubleByte)
    }
}

struct EncodingPicker: View {
    @Bindable var config = YLLGlobalConfig.sharedInstance()
    @State private var currentEncoding: YLEncoding = .YLBig5Encoding
    
    var body: some View {
        Picker("Encoding", selection: $currentEncoding) {
            Text("Big5").tag(YLEncoding.YLBig5Encoding)
            Text("GBK").tag(YLEncoding.YLGBKEncoding)
        }
        .onChange(of: currentEncoding) { _, newValue in
            setEncoding(Int(newValue.rawValue))
        }
        .onAppear {
            updateCurrentEncoding()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NSTabViewDidChangeSelectionNotification"))) { _ in
            updateCurrentEncoding()
        }
    }
    
    private func updateCurrentEncoding() {
        if let controller = NSApp.delegate as? YLController,
           let telnetView = controller.telnetView() as? YLView,
           let terminal = telnetView.swiftFrontMostTerminal() as? NSObject {
            self.currentEncoding = terminal.encoding()
        }
    }
    
    private func setEncoding(_ tag: Int) {
        if let controller = NSApp.delegate as? YLController {
            let item = NSMenuItem()
            item.tag = tag
            controller.setEncoding(item)
        }
    }
}

struct DynamicSitesMenu: View {
    @State private var reloadTrigger = false
    
    var body: some View {
        Group {
            if let controller = NSApp.delegate as? YLController,
               let sites = controller.sites() as? [YLSite] {
                ForEach(sites, id: \.self) { site in
                    Button(site.name) {
                        controller.newConnection(with: site)
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            reloadTrigger.toggle()
        }
    }
}
