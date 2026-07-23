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
import SwiftData
import UniformTypeIdentifiers

public struct TabInfo: Hashable, Identifiable {
    public var id: ObjectIdentifier {
        ObjectIdentifier(tabItem)
    }
    public let label: String
    public let icon: NSImage?
    public let isSelected: Bool
    public let tabItem: NSTabViewItem
    
    public static func == (lhs: TabInfo, rhs: TabInfo) -> Bool {
        return lhs.tabItem == rhs.tabItem &&
               lhs.label == rhs.label &&
               lhs.icon == rhs.icon &&
               lhs.isSelected == rhs.isSelected
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(tabItem)
        hasher.combine(label)
        hasher.combine(icon)
        hasher.combine(isSelected)
    }
}

@MainActor
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
    public var tabs: [TabInfo] = []
    public var selectedTab: NSTabViewItem?
    private var connectionCancellables = Set<AnyCancellable>()
    
    public override init() {
        let exif = YLExifController()
        let ctrl = YLController()
        
        ctrl._exifController = exif
        
        self.exifController = exif
        self.controller = ctrl
        
        super.init()
        
        // 1. Setup controllers programmatically
        ctrl.setupProgrammatically()
        
        // 2. Precreate YLView & YLMarkedTextView
        let telnetView = YLView(frame: .zero)
        let markedTextView = YLMarkedTextView(frame: .zero)
        telnetView._textField = markedTextView
        telnetView.addSubview(markedTextView)
        telnetView.configure()
        ctrl._telnetView = telnetView
        
        // Directly set YLController as delegate of the NSTabView
        telnetView.delegate = ctrl
        
        updateDimensions()
        
        NotificationCenter.default.publisher(for: YLConnection.stateDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, let tv = self.controller.telnetView() as? YLView else { return }
                self.syncTabs(from: tv)
            }
            .store(in: &connectionCancellables)
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
    
    public func syncTabs(from telnetView: YLView) {
        let items = telnetView.tabViewItems
        let selected = telnetView.selectedTabViewItem
        
        self.tabs = items.map { item in
            let conn = item.identifier as? YLConnection
            return TabInfo(
                label: item.label,
                icon: conn?.icon,
                isSelected: item == selected,
                tabItem: item
            )
        }
        self.selectedTab = selected
        
        if let conn = selected?.identifier as? YLConnection {
            self.addressText = conn.connectionAddress ?? ""
        }
        
        NSLog("[Nally] syncTabs called. Tab count: \(tabs.count), selectedTab: \(selected?.label ?? "nil")")

    }
}

@main
struct NallyApp: App {
    @NSApplicationDelegateAdaptor(NallyAppDelegate.self) var appDelegate
    @State private var appState = AppState.shared
    @AppStorage("AppTheme") var appThemeRaw: String = AppTheme.system.rawValue
    @AppStorage("ShowMenuBarExtra") var showMenuBarExtra: Bool = true
    
    var body: some Scene {
        Window("Nally", id: "main") {
            MainSwiftUIWindowView(appState: appState)
                .preferredColorScheme(AppTheme(rawValue: appThemeRaw)?.colorScheme)
        }
        .modelContainer(for: YLSite.self)
        .commands {
            NallyCommands()
        }
        
        Window("Bookmarks", id: "sites") {
            SitesView(
                controller: appState.controller,
                onConnect: { site in
                    appState.controller.newConnection(with: site)
                },
                onClose: {}
            )
            .preferredColorScheme(AppTheme(rawValue: appThemeRaw)?.colorScheme)
        }
        .modelContainer(for: YLSite.self)
        .windowResizability(.contentSize)
        
        Settings {
            PreferencesView()
                .preferredColorScheme(AppTheme(rawValue: appThemeRaw)?.colorScheme)
        }
        
        MenuBarExtra("Nally", systemImage: "terminal.fill", isInserted: $showMenuBarExtra) {
            MenuBarQuickConnectView(appState: appState)
        }
    }
}

struct MenuBarQuickConnectView: View {
    var appState: AppState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Nally Quick Connect")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.top, 4)
            
            Divider()
            
            ForEach(appState.controller.sitesList) { site in
                Button(action: {
                    NSApp.activate(ignoringOtherApps: true)
                    appState.controller.newConnection(with: site)
                }) {
                    HStack {
                        Image(systemName: site.address.lowercased().hasPrefix("ssh://") ? "lock.shield.fill" : "network")
                        Text(site.name.isEmpty ? site.address : site.name)
                    }
                }
            }
            
            Divider()
            
            Button(action: {
                NSApp.activate(ignoringOtherApps: true)
                if let window = appState.controller._mainWindow {
                    window.makeKeyAndOrderFront(nil)
                }
            }) {
                Label("Open Main Window", systemImage: "macwindow")
            }
            
            Button(action: {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "sites")
            }) {
                Label("Bookmarks (Cmd+B)", systemImage: "bookmark")
            }
            
            Button(action: {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            }) {
                Label("Preferences... (Cmd+,)", systemImage: "gearshape")
            }
            
            Divider()
            
            Button(action: {
                NSApp.terminate(nil)
            }) {
                Label("Quit Nally", systemImage: "power")
            }
        }
    }
}

struct NallyTabBarView: View {
    var appState: AppState
    @State private var draggedTab: TabInfo?
    
    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 3) {
                    ForEach(Array(appState.tabs.enumerated()), id: \.element.id) { index, tab in
                        SingleTabItemView(tab: tab, appState: appState)
                            .onDrag {
                                self.draggedTab = tab
                                return NSItemProvider(object: tab.label as NSString)
                            }
                            .onDrop(of: [UTType.text], delegate: TabDropDelegate(item: tab, tabs: appState.tabs, draggedItem: $draggedTab, controller: appState.controller))
                    }
                }
                .padding(.horizontal, 4)
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
            .help("New Connection (Cmd+T)")
        }
        .frame(height: 26)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct SingleTabItemView: View {
    let tab: TabInfo
    var appState: AppState
    @State private var isHovered = false
    
    var body: some View {
        let isSelected = tab.isSelected
        let conn = tab.tabItem.identifier as? YLConnection
        let hasMessage = conn?.terminal?.hasMessage ?? false
        
        HStack(spacing: 4) {
            // Message dot or connection icon
            if hasMessage {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 6, height: 6)
            } else if let icon = tab.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 13, height: 13)
            }
            
            Text(tab.label)
                .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                .foregroundColor(isSelected ? .white : (isHovered ? .primary : .primary.opacity(0.8)))
                .lineLimit(1)
            
            // Close button
            Button(action: {
                appState.controller.closeTabViewItem(tab.tabItem)
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : (isHovered ? .primary : .secondary))
                    .padding(3)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isSelected ? Color.accentColor.opacity(0.85) : (isHovered ? Color.primary.opacity(0.12) : Color.primary.opacity(0.04)))
        )
        .onHover { hover in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hover
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if let telnetView = appState.controller.telnetView() as? YLView {
                telnetView.selectTabViewItem(tab.tabItem)
            }
        }
        .contextMenu {
            Button(action: {
                conn?.reconnect()
            }) {
                Label("Reconnect", systemImage: "arrow.clockwise")
            }
            
            Button(action: {
                appState.controller.closeTabViewItem(tab.tabItem)
            }) {
                Label("Close Tab", systemImage: "xmark.circle")
            }
            
            Button(action: {
                appState.controller.closeOtherTabs(except: tab.tabItem)
            }) {
                Label("Close Other Tabs", systemImage: "xmark.circle.fill")
            }
            
            Divider()
            
            if let addr = conn?.connectionAddress, !addr.isEmpty {
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(addr, forType: .string)
                }) {
                    Label("Copy Address", systemImage: "doc.on.doc")
                }
            }
        }
    }
}

struct TabDropDelegate: DropDelegate {
    let item: TabInfo
    let tabs: [TabInfo]
    @Binding var draggedItem: TabInfo?
    let controller: YLController
    
    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let dragged = draggedItem,
              dragged != item,
              let fromIndex = tabs.firstIndex(of: dragged),
              let toIndex = tabs.firstIndex(of: item) else { return }
        
        withAnimation(.default) {
            controller.moveTab(fromIndex: fromIndex, toIndex: toIndex)
        }
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
        DispatchQueue.main.async {
            if let window = nsView.window {
                callback(window)
            }
        }
    }
}
