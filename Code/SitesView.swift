import SwiftUI

struct SitesView: View {
    @Bindable var manager: SitesManager
    @State private var selectedSite: YLSite?
    
    var onConnect: (YLSite) -> Void
    var onClose: () -> Void
    
    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(selection: $selectedSite) {
                    ForEach(manager.sites, id: \.self) { site in
                        Text(site.name)
                            .tag(site)
                    }
                }
                .listStyle(.sidebar)
                
                Divider()
                
                HStack(spacing: 12) {
                    Button(action: addSite) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)
                    
                    Button(action: deleteSelectedSite) {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(.borderless)
                    .disabled(selectedSite == nil)
                    
                    Spacer()
                }
                .padding(8)
                .background(Color(NSColor.windowBackgroundColor))
            }
            .navigationTitle("Sites")
        } detail: {
            if let site = selectedSite {
                SiteDetailView(site: site, onConnect: onConnect)
            } else {
                Text("Select a site to view or edit details.")
                    .foregroundColor(.secondary)
            }
        }
        .frame(minWidth: 550, minHeight: 380)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    onClose()
                }
            }
        }
    }
    
    private func addSite() {
        manager.addSite()
        if let last = manager.sites.last {
            selectedSite = last
        }
    }
    
    private func deleteSelectedSite() {
        if let site = selectedSite, let index = manager.sites.firstIndex(of: site) {
            manager.removeSite(at: index)
            selectedSite = nil
        }
    }
}

struct SiteDetailView: View {
    @Bindable var site: YLSite
    var onConnect: (YLSite) -> Void
    
    var body: some View {
        Form {
            Section("Site Identification") {
                TextField("Name:", text: $site.name)
                TextField("Address:", text: $site.address)
            }
            
            Section("Credentials") {
                TextField("Account:", text: $site.account)
                SecureField("Password:", text: $site.password)
            }
            
            Section("Connection Settings") {
                Picker("Encoding:", selection: $site.encoding) {
                    Text("Big5").tag(YLEncoding.YLBig5Encoding)
                    Text("GBK").tag(YLEncoding.YLGBKEncoding)
                }
                
                Picker("ANSI Color Key:", selection: $site.ansiColorKey) {
                    Text("Ctrl-U").tag(YLANSIColorKey.YLCtrlUANSIColorKey)
                    Text("Esc + Esc").tag(YLANSIColorKey.YLEscEscEscANSIColorKey)
                }
                
                Toggle("Double Byte Detection", isOn: $site.detectDoubleByte)
            }
            
            Section {
                Button("Connect") {
                    onConnect(site)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .formStyle(.grouped)
    }
}
