import SwiftUI
import CoreServices

struct PreferencesView: View {
    @Bindable var config = YLLGlobalConfig.sharedInstance()
    
    // Bind to AppStorage for standard Cocoa UserDefaults keys
    @AppStorage("ConfirmOnClose") var confirmOnClose: Bool = true
    @AppStorage("RestoreConnection") var restoreConnection: Bool = false
    
    var body: some View {
        TabView {
            GeneralPreferencesView(config: config, confirmOnClose: $confirmOnClose, restoreConnection: $restoreConnection)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
            
            ConnectionPreferencesView(config: config)
                .tabItem {
                    Label("Connection", systemImage: "network")
                }
            
            FontPreferencesView(config: config)
                .tabItem {
                    Label("Fonts", systemImage: "textformat")
                }
            
            ColorPreferencesView(config: config)
                .tabItem {
                    Label("Colors", systemImage: "paintpalette")
                }
        }
        .frame(width: 580, height: 460)
        .padding()
    }
}

// MARK: - Tab Views

struct GeneralPreferencesView: View {
    @Bindable var config: YLLGlobalConfig
    @Binding var confirmOnClose: Bool
    @Binding var restoreConnection: Bool
    
    var body: some View {
        Form {
            Section("Window & Sessions") {
                Toggle("Confirm when closing windows", isOn: $confirmOnClose)
                Toggle("Restore last connections on startup", isOn: $restoreConnection)
            }
            
            Section("Terminal Behavior") {
                Toggle("Prefer image previewer", isOn: $config.shouldPreferImagePreviewer)
                Toggle("Repeat bounce animation", isOn: $config.repeatBounce)
            }
        }
        .formStyle(.grouped)
    }
}

struct ConnectionPreferencesView: View {
    @Bindable var config: YLLGlobalConfig
    
    var body: some View {
        Form {
            Section("Protocol Defaults") {
                Picker("Encoding:", selection: $config.defaultEncoding) {
                    Text("Big5").tag(YLEncoding.YLBig5Encoding)
                    Text("GBK").tag(YLEncoding.YLGBKEncoding)
                }
                
                Picker("ANSI Color Key:", selection: $config.defaultANSIColorKey) {
                    Text("Ctrl-U").tag(YLANSIColorKey.YLCtrlUANSIColorKey)
                    Text("Esc + Esc").tag(YLANSIColorKey.YLEscEscEscANSIColorKey)
                }
                
                Toggle("Double Byte Detection", isOn: $config.detectDoubleByte)
            }
            
            Section("Default Client Handler") {
                AppPicker(scheme: "telnet")
                AppPicker(scheme: "ssh")
            }
        }
        .formStyle(.grouped)
    }
}

struct FontPreferencesView: View {
    @Bindable var config: YLLGlobalConfig
    
    var body: some View {
        Form {
            Section("Chinese Font") {
                FontSettingsRow(
                    fontName: $config.chineseFontName,
                    fontSize: $config.chineseFontSize,
                    paddingLeft: $config.chineseFontPaddingLeft,
                    paddingBottom: $config.chineseFontPaddingBottom
                )
            }
            
            Section("English Font") {
                FontSettingsRow(
                    fontName: $config.englishFontName,
                    fontSize: $config.englishFontSize,
                    paddingLeft: $config.englishFontPaddingLeft,
                    paddingBottom: $config.englishFontPaddingBottom
                )
            }
            
            Section("Grid Layout & Font Rendering") {
                HStack {
                    Slider(value: $config.cellWidth, in: 6...30, step: 0.5) {
                        Text("Cell Width:")
                    } minimumValueLabel: {
                        Text("6")
                    } maximumValueLabel: {
                        Text("30")
                    }
                    Text(String(format: "%.1f", config.cellWidth))
                        .frame(width: 40)
                }
                
                HStack {
                    Slider(value: $config.cellHeight, in: 12...60, step: 0.5) {
                        Text("Cell Height:")
                    } minimumValueLabel: {
                        Text("12")
                    } maximumValueLabel: {
                        Text("60")
                    }
                    Text(String(format: "%.1f", config.cellHeight))
                        .frame(width: 40)
                }
                
                Toggle("Enable font smoothing", isOn: $config.shouldSmoothFonts)
            }
        }
        .formStyle(.grouped)
    }
}

struct ColorPreferencesView: View {
    @Bindable var config: YLLGlobalConfig
    
    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Terminal Colors") {
                    ColorPickerGrid(config: config)
                }
                
                Section("Background") {
                    ColorPickerRow(label: "Terminal Background:", nsColor: $config.colorBG)
                }
            }
            .formStyle(.grouped)
        }
    }
}

// MARK: - Helper Subviews

struct AppPicker: View {
    let scheme: String
    @State private var apps: [(id: String, name: String)] = []
    @State private var selectedAppId: String = ""
    
    var body: some View {
        Picker(selection: $selectedAppId) {
            ForEach(apps, id: \.id) { app in
                Text(app.name).tag(app.id)
            }
        } label: {
            Text("\(scheme.capitalized) Client:")
        }
        .onChange(of: selectedAppId) { oldValue, newValue in
            LSSetDefaultHandlerForURLScheme(scheme as CFString, newValue as CFString)
        }
        .onAppear {
            loadApps()
        }
    }
    
    private func loadApps() {
        let schemeCF = scheme as CFString
        var list: [(id: String, name: String)] = []
        if let handlers = LSCopyAllHandlersForURLScheme(schemeCF)?.takeRetainedValue() as? [String] {
            let ws = NSWorkspace.shared
            for handler in handlers {
                if let appURL = ws.urlForApplication(withBundleIdentifier: handler) {
                    let name = (try? appURL.resourceValues(forKeys: [.localizedNameKey]).localizedName) ?? appURL.deletingPathExtension().lastPathComponent
                    list.append((id: handler, name: name))
                }
            }
        }
        
        let nallyId = Bundle.main.bundleIdentifier ?? ""
        if !list.contains(where: { $0.id.lowercased() == nallyId.lowercased() }) {
            list.append((id: nallyId, name: "Nally"))
        }
        
        self.apps = list
        
        if let defaultHandler = LSCopyDefaultHandlerForURLScheme(schemeCF)?.takeRetainedValue() as String? {
            self.selectedAppId = defaultHandler
        } else {
            self.selectedAppId = nallyId
        }
    }
}

struct FontSettingsRow: View {
    @Binding var fontName: String
    @Binding var fontSize: CGFloat
    @Binding var paddingLeft: CGFloat
    @Binding var paddingBottom: CGFloat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(fontName) - \(Int(fontSize))pt")
                    .font(.subheadline)
                    .frame(minWidth: 200, alignment: .leading)
                
                Button("Select...") {
                    openFontPanel()
                }
            }
            
            HStack {
                Slider(value: $paddingLeft, in: -10...10, step: 0.5) {
                    Text("Left Padding:")
                } minimumValueLabel: {
                    Text("-10")
                } maximumValueLabel: {
                    Text("10")
                }
                Text(String(format: "%.1f", paddingLeft))
                    .frame(width: 40)
            }
            
            HStack {
                Slider(value: $paddingBottom, in: -10...10, step: 0.5) {
                    Text("Bottom Padding:")
                } minimumValueLabel: {
                    Text("-10")
                } maximumValueLabel: {
                    Text("10")
                }
                Text(String(format: "%.1f", paddingBottom))
                    .frame(width: 40)
            }
        }
    }
    
    private func openFontPanel() {
        let fontManager = NSFontManager.shared
        fontManager.target = FontPanelBridge.shared
        fontManager.action = #selector(FontPanelBridge.changeFont(_:))
        FontPanelBridge.shared.activeFontNameBinding = $fontName
        FontPanelBridge.shared.activeFontSizeBinding = $fontSize
        
        if let font = NSFont(name: fontName, size: fontSize) {
            fontManager.setSelectedFont(font, isMultiple: false)
        }
        NSFontPanel.shared.makeKeyAndOrderFront(nil)
    }
}

struct ColorPickerRow: View {
    let label: String
    @Binding var nsColor: NSColor?
    
    var body: some View {
        ColorPicker(selection: Binding<Color>(
            get: {
                if let c = nsColor {
                    return Color(c)
                }
                return Color.black
            },
            set: { newColor in
                nsColor = NSColor(newColor)
            }
        )) {
            Text(label)
        }
    }
}

struct ColorPickerGrid: View {
    @Bindable var config: YLLGlobalConfig
    
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            Group {
                ColorPickerRow(label: "Black", nsColor: $config.colorBlack)
                ColorPickerRow(label: "Black Hilite", nsColor: $config.colorBlackHilite)
                
                ColorPickerRow(label: "Red", nsColor: $config.colorRed)
                ColorPickerRow(label: "Red Hilite", nsColor: $config.colorRedHilite)
                
                ColorPickerRow(label: "Green", nsColor: $config.colorGreen)
                ColorPickerRow(label: "Green Hilite", nsColor: $config.colorGreenHilite)
                
                ColorPickerRow(label: "Yellow", nsColor: $config.colorYellow)
                ColorPickerRow(label: "Yellow Hilite", nsColor: $config.colorYellowHilite)
            }
            
            Group {
                ColorPickerRow(label: "Blue", nsColor: $config.colorBlue)
                ColorPickerRow(label: "Blue Hilite", nsColor: $config.colorBlueHilite)
                
                ColorPickerRow(label: "Magenta", nsColor: $config.colorMagenta)
                ColorPickerRow(label: "Magenta Hilite", nsColor: $config.colorMagentaHilite)
                
                ColorPickerRow(label: "Cyan", nsColor: $config.colorCyan)
                ColorPickerRow(label: "Cyan Hilite", nsColor: $config.colorCyanHilite)
                
                ColorPickerRow(label: "White", nsColor: $config.colorWhite)
                ColorPickerRow(label: "White Hilite", nsColor: $config.colorWhiteHilite)
            }
        }
    }
}

// MARK: - Font Panel Bridge Implementation

@objcMembers
class FontPanelBridge: NSObject {
    static let shared = FontPanelBridge()
    
    var activeFontNameBinding: Binding<String>?
    var activeFontSizeBinding: Binding<CGFloat>?
    
    @objc func changeFont(_ sender: Any?) {
        guard let fontManager = sender as? NSFontManager else { return }
        let selectedFont = fontManager.selectedFont ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let converted = fontManager.convert(selectedFont)
        
        activeFontNameBinding?.wrappedValue = converted.fontName
        activeFontSizeBinding?.wrappedValue = converted.pointSize
        
        YLLGlobalConfig.sharedInstance().refreshFont()
    }
}
