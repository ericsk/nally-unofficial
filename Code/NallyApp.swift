import SwiftUI

@main
struct NallyApp: App {
    @NSApplicationDelegateAdaptor(NallyAppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            PreferencesView()
        }
        .commands {
            NallyCommands()
        }
    }
}
