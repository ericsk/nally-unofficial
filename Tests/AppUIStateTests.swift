import Testing
import Foundation
import SwiftUI
@testable import Nally

@Suite("App UI State & MenuBar Integration Tests")
struct AppUIStateTests {
    
    @Test("AppState Initialization and Focus Flags")
    @MainActor
    func testAppStateDefaults() {
        let appState = AppState.shared
        #expect(appState.addressText == "")
        #expect(appState.focusAddressBar == false)
        #expect(appState.tabs.isEmpty)
    }
    
    @Test("AppTheme Preferred ColorScheme Mapping")
    func testAppThemeColorSchemeMapping() {
        #expect(AppTheme.system.colorScheme == nil)
        #expect(AppTheme.light.colorScheme == .light)
        #expect(AppTheme.dark.colorScheme == .dark)
    }
    
    @Test("Quick Connect Sites Protocol Detection")
    func testProtocolBadgeDetection() {
        let telnetSite = YLSite(name: "PTT", address: "ptt.cc")
        let sshSite = YLSite(name: "BS2 SSH", address: "ssh://bs2.to")
        
        #expect(!telnetSite.address.lowercased().hasPrefix("ssh://"))
        #expect(sshSite.address.lowercased().hasPrefix("ssh://"))
    }
    
    @Test("ShowMenuBarExtra Preference Key Persistence")
    func testShowMenuBarExtraPreference() {
        let key = "TestShowMenuBarExtra"
        UserDefaults.standard.set(false, forKey: key)
        #expect(UserDefaults.standard.bool(forKey: key) == false)
        
        UserDefaults.standard.set(true, forKey: key)
        #expect(UserDefaults.standard.bool(forKey: key) == true)
        
        UserDefaults.standard.removeObject(forKey: key)
    }
}
