//
//  NallyApp.swift
//  Nally
//
//  Created by Yung-Luen Lan on 2026/07/18.
//  Copyright 2026 yllan.org. All rights reserved.
//

import SwiftUI
import Cocoa
import Combine

@Observable
public class AppState: NSObject {
    public static let shared = AppState()
    
    public let controller: YLController
    public let exifController: YLExifController
    
    public var addressText: String = ""
    public var focusAddressBar: Bool = false
    
    public var termWidth: CGFloat = 960
    public var termHeight: CGFloat = 576
    
    // SwiftUI Tab Bar state
    public var tabs: [NSTabViewItem] = []
    public var selectedTab: NSTabViewItem?
    private var connectionCancellables = Set<AnyCancellable>()
    
    public override init() {
        let exif = YLExifController()
        let ctrl = YLController()
        
        ctrl.setValue(exif, forKey: "_exifController")
        
        self.exifController = exif
        self.controller = ctrl
        
        super.init()
        
        // 1. Setup controllers programmatically
        ctrl.setupProgrammatically()
        
        // 2. Precreate YLView & YLMarkedTextView
        let telnetView = YLView(frame: .zero)
        let markedTextView = YLMarkedTextView(frame: .zero)
        telnetView.setValue(markedTextView, forKey: "_textField")
        telnetView.addSubview(markedTextView)
        telnetView.configure()
        ctrl.setValue(telnetView, forKey: "_telnetView")
        
        // Directly set YLController as delegate of the NSTabView
        telnetView.delegate = ctrl
        
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
    
    public func syncTabs(from tabView: NSTabView) {
        self.tabs = tabView.tabViewItems
        self.selectedTab = tabView.selectedTabViewItem
        NSLog("[Nally] syncTabs called. Tab count: \(tabs.count), selectedTab: \(selectedTab?.label ?? "nil")")
        for (i, t) in tabs.enumerated() {
            NSLog("[Nally] Tab \(i): label='\(t.label)', identifier='\(String(describing: t.identifier))'")
        }
        
        // Observe connection state changes (like icon) to refresh the SwiftUI tab bar
        connectionCancellables.removeAll()
        for item in tabs {
            if let conn = item.identifier as? YLConnection {
                conn.publisher(for: \.icon)
                    .sink { [weak self] _ in
                        guard let self = self else { return }
                        self.tabs = tabView.tabViewItems
                    }
                    .store(in: &connectionCancellables)
            }
        }
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

struct NallyTabBarView: View {
    var appState: AppState
    
    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(appState.tabs, id: \.self) { item in
                        let isSelected = appState.selectedTab == item
                        let conn = item.identifier as? YLConnection
                        
                        HStack(spacing: 4) {
                            if let icon = conn?.icon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 13, height: 13)
                            }
                            
                            Text(item.label)
                                .font(.system(size: 11))
                                .foregroundColor(isSelected ? .white : .primary.opacity(0.8))
                                .lineLimit(1)
                            
                            // Close button
                            Button(action: {
                                if let telnetView = appState.controller.telnetView() as? NSTabView {
                                    _ = appState.controller.tabView(telnetView, shouldClose: item)
                                }
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                                    .padding(3)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(isSelected ? Color.blue.opacity(0.8) : Color.primary.opacity(0.05))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let telnetView = appState.controller.telnetView() as? NSTabView {
                                telnetView.selectTabViewItem(item)
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            
            Spacer()
            
            // "+" Button to open a new tab
            Button(action: {
                appState.controller.newTab(nil)
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary.opacity(0.8))
                    .padding(5)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 6)
        }
        .frame(height: 26)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct MainSwiftUIWindowView: View {
    var appState: AppState
    @Bindable var config = YLLGlobalConfig.sharedInstance()
    @FocusState private var isAddressBarFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            NallyTabBarView(appState: appState)
            
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
                    .focused($isAddressBarFocused)
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
        .onChange(of: appState.focusAddressBar) { _, newValue in
            if newValue {
                isAddressBarFocused = true
                appState.focusAddressBar = false
            }
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
