import SwiftUI
import SwiftData

struct SitesView: View {
    @Bindable var controller: YLController
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \YLSite.name) private var sites: [YLSite]
    
    @State private var selectedSite: YLSite?
    @State private var searchText: String = ""
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    
    var onConnect: (YLSite) -> Void
    var onClose: () -> Void
    
    private var filteredSites: [YLSite] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return sites
        }
        let query = searchText.lowercased()
        return sites.filter {
            $0.name.lowercased().contains(query) || $0.address.lowercased().contains(query)
        }
    }
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack(spacing: 0) {
                List(selection: $selectedSite) {
                    ForEach(filteredSites) { site in
                        HStack(spacing: 8) {
                            Image(systemName: isSSH(site) ? "lock.shield.fill" : "network")
                                .font(.system(size: 13))
                                .foregroundColor(isSSH(site) ? .blue : .teal)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(site.name.isEmpty ? "Untitled Site" : site.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .lineLimit(1)
                                Text(site.address.isEmpty ? "(address)" : site.address)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            ProtocolBadge(isSSH: isSSH(site))
                        }
                        .padding(.vertical, 2)
                        .tag(site)
                    }
                }
                .listStyle(.sidebar)
                .searchable(text: $searchText, placement: .sidebar, prompt: "Search sites...")
                
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
                    
                    Divider()
                        .frame(height: 12)
                    
                    Button(action: duplicateSelectedSite) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: 28, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(selectedSite == nil ? .secondary.opacity(0.4) : .primary.opacity(0.8))
                    .disabled(selectedSite == nil)
                    .help("Duplicate selected site")
                    
                    Spacer()
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color(NSColor.windowBackgroundColor))
            }
            .navigationTitle("Bookmarks")
        } detail: {
            if let site = selectedSite {
                SiteDetailView(site: site, onConnect: onConnect, onSave: saveChanges)
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
        .frame(minWidth: 620, minHeight: 440)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    saveChanges()
                    onClose()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
        }
        .onAppear {
            if selectedSite == nil && !sites.isEmpty {
                selectedSite = sites.first
            }
        }
    }
    
    private func isSSH(_ site: YLSite) -> Bool {
        return site.address.lowercased().hasPrefix("ssh://")
    }
    
    private func addSite() {
        let newSite = YLSite(name: "New Site", address: "bbs.example.com")
        modelContext.insert(newSite)
        saveChanges()
        selectedSite = newSite
    }
    
    private func deleteSelectedSite() {
        if let site = selectedSite {
            modelContext.delete(site)
            saveChanges()
            selectedSite = nil
        }
    }
    
    private func duplicateSelectedSite() {
        if let site = selectedSite {
            let dup = site.copySite()
            dup.name = "\(site.name) Copy"
            modelContext.insert(dup)
            saveChanges()
            selectedSite = dup
        }
    }
    
    private func saveChanges() {
        try? modelContext.save()
        controller.sitesList = sites
        controller.saveSites()
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
    var onSave: () -> Void
    
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
                    onSave()
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
        .onChange(of: site.name) { _, _ in onSave() }
        .onChange(of: site.address) { _, _ in onSave() }
        .onChange(of: site.account) { _, _ in onSave() }
        .onChange(of: site.password) { _, _ in onSave() }
        .onChange(of: site.encoding) { _, _ in onSave() }
        .onChange(of: site.ansiColorKey) { _, _ in onSave() }
        .onChange(of: site.detectDoubleByte) { _, _ in onSave() }
    }
}
