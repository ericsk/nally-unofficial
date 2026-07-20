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
        .frame(width: 620, height: 480)
        .padding(8)
    }
}

// MARK: - Tab Views

struct GeneralPreferencesView: View {
    @Bindable var config: YLLGlobalConfig
    @Binding var confirmOnClose: Bool
    @Binding var restoreConnection: Bool
    
    var body: some View {
        Form {
            Section(header: Label("Window & Sessions", systemImage: "macwindow")) {
                Toggle("Confirm when closing windows", isOn: $confirmOnClose)
                Toggle("Restore last connections on startup", isOn: $restoreConnection)
            }
            
            Section(header: Label("Terminal Behavior", systemImage: "display")) {
                Toggle("Prefer internal image previewer", isOn: $config.shouldPreferImagePreviewer)
                Toggle("Repeat dock icon bounce animation", isOn: $config.repeatBounce)
            }
        }
        .formStyle(.grouped)
    }
}

struct ConnectionPreferencesView: View {
    @Bindable var config: YLLGlobalConfig
    
    var body: some View {
        Form {
            Section(header: Label("Protocol Defaults", systemImage: "network")) {
                Picker("Default Encoding:", selection: $config.defaultEncoding) {
                    Text("Big5 (Traditional Chinese)").tag(YLEncoding.YLBig5Encoding)
                    Text("GBK (Simplified Chinese)").tag(YLEncoding.YLGBKEncoding)
                }
                
                Picker("ANSI Color Key:", selection: $config.defaultANSIColorKey) {
                    Text("Ctrl-U").tag(YLANSIColorKey.YLCtrlUANSIColorKey)
                    Text("Esc + Esc").tag(YLANSIColorKey.YLEscEscEscANSIColorKey)
                }
                
                Toggle("Enable Double-Byte Character Detection", isOn: $config.detectDoubleByte)
            }
            
            Section(header: Label("Default URL Scheme Handlers", systemImage: "arrow.triangle.branch")) {
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
            Section(header: Label("Chinese Font Settings", systemImage: "character")) {
                FontSettingsRow(
                    fontName: $config.chineseFontName,
                    fontSize: $config.chineseFontSize,
                    paddingLeft: $config.chineseFontPaddingLeft,
                    paddingBottom: $config.chineseFontPaddingBottom,
                    sampleText: "華康中文字體 123"
                )
            }
            
            Section(header: Label("English Font Settings", systemImage: "textformat")) {
                FontSettingsRow(
                    fontName: $config.englishFontName,
                    fontSize: $config.englishFontSize,
                    paddingLeft: $config.englishFontPaddingLeft,
                    paddingBottom: $config.englishFontPaddingBottom,
                    sampleText: "Monaco 123 ABC"
                )
            }
            
            Section(header: Label("Grid Layout & Font Rendering", systemImage: "square.grid.2x2")) {
                VStack(spacing: 8) {
                    HStack {
                        Text("Cell Width:")
                            .frame(width: 100, alignment: .leading)
                        Slider(value: $config.cellWidth, in: 6...30, step: 0.5)
                        Text(String(format: "%.1f px", config.cellWidth))
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 55, alignment: .trailing)
                    }
                    
                    HStack {
                        Text("Cell Height:")
                            .frame(width: 100, alignment: .leading)
                        Slider(value: $config.cellHeight, in: 12...60, step: 0.5)
                        Text(String(format: "%.1f px", config.cellHeight))
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 55, alignment: .trailing)
                    }
                }
                .padding(.vertical, 2)
                
                Toggle("Enable Font Anti-Aliasing & Smoothing", isOn: $config.shouldSmoothFonts)
            }
        }
        .formStyle(.grouped)
    }
}

struct ColorPreferencesView: View {
    @Bindable var config: YLLGlobalConfig
    
    var body: some View {
        Form {
            Section(header: Label("ANSI Color Palette", systemImage: "paintpalette.fill")) {
                ColorPickerGrid(config: config)
            }
            
            Section(header: Label("Canvas Background", systemImage: "square.fill")) {
                ColorPickerRow(label: "Terminal Background:", nsColor: $config.colorBG)
            }
        }
        .formStyle(.grouped)
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
    let sampleText: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(fontName) - \(Int(fontSize))pt")
                        .font(.system(size: 13, weight: .semibold))
                    
                    Text(sampleText)
                        .font(.custom(fontName, size: max(10, fontSize)))
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.85))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                }
                
                Spacer()
                
                Button("Choose Font...") {
                    openFontPanel()
                }
                .buttonStyle(.bordered)
            }
            
            VStack(spacing: 6) {
                HStack {
                    Text("Left Offset:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 90, alignment: .leading)
                    Slider(value: $paddingLeft, in: -10...10, step: 0.5)
                    Text(String(format: "%.1f", paddingLeft))
                        .font(.system(.caption, design: .monospaced))
                        .frame(width: 40, alignment: .trailing)
                }
                
                HStack {
                    Text("Bottom Offset:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 90, alignment: .leading)
                    Slider(value: $paddingBottom, in: -10...10, step: 0.5)
                    Text(String(format: "%.1f", paddingBottom))
                        .font(.system(.caption, design: .monospaced))
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
        .padding(.vertical, 4)
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
            HStack(spacing: 6) {
                Circle()
                    .fill(nsColor != nil ? Color(nsColor!) : Color.black)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(Color.secondary.opacity(0.5), lineWidth: 1))
                
                Text(label)
                    .font(.system(size: 12))
            }
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
        LazyVGrid(columns: columns, spacing: 10) {
            Group {
                ColorPickerRow(label: "Black", nsColor: $config.colorBlack)
                ColorPickerRow(label: "Black (Bright)", nsColor: $config.colorBlackHilite)
                
                ColorPickerRow(label: "Red", nsColor: $config.colorRed)
                ColorPickerRow(label: "Red (Bright)", nsColor: $config.colorRedHilite)
                
                ColorPickerRow(label: "Green", nsColor: $config.colorGreen)
                ColorPickerRow(label: "Green (Bright)", nsColor: $config.colorGreenHilite)
                
                ColorPickerRow(label: "Yellow", nsColor: $config.colorYellow)
                ColorPickerRow(label: "Yellow (Bright)", nsColor: $config.colorYellowHilite)
            }
            
            Group {
                ColorPickerRow(label: "Blue", nsColor: $config.colorBlue)
                ColorPickerRow(label: "Blue (Bright)", nsColor: $config.colorBlueHilite)
                
                ColorPickerRow(label: "Magenta", nsColor: $config.colorMagenta)
                ColorPickerRow(label: "Magenta (Bright)", nsColor: $config.colorMagentaHilite)
                
                ColorPickerRow(label: "Cyan", nsColor: $config.colorCyan)
                ColorPickerRow(label: "Cyan (Bright)", nsColor: $config.colorCyanHilite)
                
                ColorPickerRow(label: "White", nsColor: $config.colorWhite)
                ColorPickerRow(label: "White (Bright)", nsColor: $config.colorWhiteHilite)
            }
        }
        .padding(.vertical, 4)
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
