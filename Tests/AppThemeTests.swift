import Testing
import Cocoa
import SwiftUI
@testable import Nally

@Suite("App Theme Preference & Appearance Tests")
struct AppThemeTests {
    @Test("AppTheme Conversion to NSAppearance")
    func testNSAppearanceMapping() {
        #expect(AppTheme.system.nsAppearance == nil)
        #expect(AppTheme.light.nsAppearance?.name == .aqua)
        #expect(AppTheme.dark.nsAppearance?.name == .darkAqua)
    }
    
    @Test("AppTheme Conversion to ColorScheme")
    func testColorSchemeMapping() {
        #expect(AppTheme.system.colorScheme == nil)
        #expect(AppTheme.light.colorScheme == .light)
        #expect(AppTheme.dark.colorScheme == .dark)
    }
    
    @Test("AppTheme RawValue Initialization and Fallbacks")
    func testRawValueInit() {
        #expect(AppTheme(rawValue: "System") == .system)
        #expect(AppTheme(rawValue: "Light") == .light)
        #expect(AppTheme(rawValue: "Dark") == .dark)
        #expect(AppTheme(rawValue: "Invalid") == nil)
    }
}
