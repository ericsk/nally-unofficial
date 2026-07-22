import Cocoa
import SwiftUI

public enum AppTheme: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    public var id: String { rawValue }
    
    public var localizedName: String {
        switch self {
        case .system:
            return NSLocalizedString("System", comment: "Theme System Default")
        case .light:
            return NSLocalizedString("Light", comment: "Theme Light Mode")
        case .dark:
            return NSLocalizedString("Dark", comment: "Theme Dark Mode")
        }
    }
    
    public var nsAppearance: NSAppearance? {
        switch self {
        case .system:
            return nil
        case .light:
            return NSAppearance(named: .aqua)
        case .dark:
            return NSAppearance(named: .darkAqua)
        }
    }
    
    public var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
    
    @MainActor
    public static func applyTheme(rawValue: String) {
        let theme = AppTheme(rawValue: rawValue) ?? .system
        NSApp.appearance = theme.nsAppearance
    }
}
