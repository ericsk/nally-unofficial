import SwiftUI

struct SitesView: View {
    @Bindable var controller: YLController
    @State private var selectedSite: YLSite?
    
    var onConnect: (YLSite) -> Void
    var onClose: () -> Void
    
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack(spacing: 0) {
                List(selection: $selectedSite) {
                    ForEach(controller.sitesList, id: \.self) { site in
                        HStack(spacing: 8) {
                            Image(systemName: isSSH(site) ? "lock.shield.fill" : "network")
                                .font(.system(size: 13))
                                .foregroundColor(isSSH(site) ? .blue : .teal)
                            
                            Text(site.name.isEmpty ? "Untitled Site" : site.name)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                            
                            Spacer()
                            
                            ProtocolBadge(isSSH: isSSH(site))
                        }
                        .padding(.vertical, 3)
                        .tag(site)
                    }
                }
                .listStyle(.sidebar)
                
                Divider()
                
                HStack(spacing: 0) {
                    Button(action: addSite) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: 28, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.primary.opacity(0.8))
                    .help("Add new site")
                    
                    Divider()
                        .frame(height: 12)
                    
                    Button(action: deleteSelectedSite) {
                        Image(systemName: "minus")
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: 28, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(selectedSite == nil ? .secondary.opacity(0.4) : .primary.opacity(0.8))
                    .disabled(selectedSite == nil)
                    .help("Remove selected site")
                    
                    Spacer()
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color(NSColor.windowBackgroundColor))
            }
            .navigationTitle("Bookmarks")
        } detail: {
            if let site = selectedSite {
                SiteDetailView(site: site, onConnect: onConnect)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "bookmark.circle")
                        .font(.system(size: 48, weight: .ultraLight))
                        .foregroundColor(.secondary.opacity(0.7))
                    
                    Text("Select a site from the sidebar to view or edit details.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 580, minHeight: 400)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    onClose()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
        }
    }
    
    private func isSSH(_ site: YLSite) -> Bool {
        return site.address.lowercased().hasPrefix("ssh://")
    }
    
    private func addSite() {
        let newSite = YLSite()
        newSite.name = "New Site"
        newSite.address = "bbs.example.com"
        controller.sitesList.append(newSite)
        controller.saveSites()
        selectedSite = newSite
    }
    
    private func deleteSelectedSite() {
        if let site = selectedSite, let index = controller.sitesList.firstIndex(of: site) {
            controller.sitesList.remove(at: index)
            controller.saveSites()
            selectedSite = nil
        }
    }
}

struct ProtocolBadge: View {
    let isSSH: Bool
    
    var body: some View {
        Text(isSSH ? "SSH" : "TELNET")
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(isSSH ? Color.blue.opacity(0.15) : Color.teal.opacity(0.15))
            .foregroundColor(isSSH ? .blue : .teal)
            .clipShape(Capsule())
    }
}

struct SiteDetailView: View {
    @Bindable var site: YLSite
    var onConnect: (YLSite) -> Void
    
    var body: some View {
        Form {
            Section(header: Label("Site Identification", systemImage: "globe")) {
                TextField("Name:", text: $site.name)
                    .textFieldStyle(.roundedBorder)
                TextField("Address:", text: $site.address)
                    .textFieldStyle(.roundedBorder)
            }
            
            Section(header: Label("Credentials (Optional Auto-login)", systemImage: "key.fill")) {
                TextField("Account:", text: $site.account)
                    .textFieldStyle(.roundedBorder)
                SecureField("Password:", text: $site.password)
                    .textFieldStyle(.roundedBorder)
            }
            
            Section(header: Label("Connection Parameters", systemImage: "slider.horizontal.3")) {
                Picker("Encoding:", selection: $site.encoding) {
                    Text("Big5 (Taiwan)").tag(YLEncoding.YLBig5Encoding)
                    Text("GBK (China)").tag(YLEncoding.YLGBKEncoding)
                }
                
                Picker("ANSI Color Key:", selection: $site.ansiColorKey) {
                    Text("Ctrl-U").tag(YLANSIColorKey.YLCtrlUANSIColorKey)
                    Text("Esc + Esc").tag(YLANSIColorKey.YLEscEscEscANSIColorKey)
                }
                
                Toggle("Detect Double-Byte Characters", isOn: $site.detectDoubleByte)
            }
            
            Section {
                Button(action: {
                    onConnect(site)
                }) {
                    HStack {
                        Spacer()
                        Image(systemName: "bolt.fill")
                        Text("Connect Now")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
        }
        .formStyle(.grouped)
    }
}
