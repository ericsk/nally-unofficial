import Foundation
import Observation
import Cocoa

@MainActor
@Observable
@objc(YLLGlobalConfig)
public class YLLGlobalConfig: NSObject {
    private static var sSharedInstance: YLLGlobalConfig?
    
    @objc public class func sharedInstance() -> YLLGlobalConfig {
        if sSharedInstance == nil {
            sSharedInstance = YLLGlobalConfig()
        }
        return sSharedInstance!
    }
    
    @ObservationIgnored private var isInitializing = true
    @ObservationIgnored public var onAppearanceChange: (() -> Void)?
    @ObservationIgnored public var onLayoutChange: (() -> Void)?
    @ObservationIgnored public var onMessageCountChange: ((Int32) -> Void)?
    
    // Store 2x10 color tables
    // 0 is normal, 1 is hilite
    private var colorTable: [[NSColor]] = Array(repeating: Array(repeating: NSColor.black, count: 10), count: 2)
    
    // Store 2x10 CoreText attributes
    @ObservationIgnored private var cCTAttribute: [[CFDictionary?]] = Array(repeating: Array(repeating: nil, count: 10), count: 2)
    @ObservationIgnored private var eCTAttribute: [[CFDictionary?]] = Array(repeating: Array(repeating: nil, count: 10), count: 2)
    
    public var chineseCTFont: CTFont?
    public var englishCTFont: CTFont?
    
    public func chineseAttribute(withHilite hilite: Int, index: Int) -> CFDictionary? {
        guard index >= 0 && index < 10 && hilite >= 0 && hilite < 2 else { return nil }
        return cCTAttribute[hilite][index]
    }
    
    public func englishAttribute(withHilite hilite: Int, index: Int) -> CFDictionary? {
        guard index >= 0 && index < 10 && hilite >= 0 && hilite < 2 else { return nil }
        return eCTAttribute[hilite][index]
    }
    
    // Modern Observable Properties
    public var messageCount: Int32 = 0 {
        didSet {
            guard !isInitializing else { return }
            onMessageCountChange?(messageCount)
        }
    }
    public var row: Int32 = 24
    public var column: Int32 = 80
    public var cellWidth: CGFloat = 12.0 {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(Float(cellWidth), forKey: "CellWidth")
            onLayoutChange?()
        }
    }
    public var cellHeight: CGFloat = 24.0 {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(Float(cellHeight), forKey: "CellHeight")
            onLayoutChange?()
        }
    }
    public var showHiddenText: Bool = false {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(showHiddenText, forKey: "ShowHiddenText")
        }
    }
    public var shouldSmoothFonts: Bool = false {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(shouldSmoothFonts, forKey: "ShouldSmoothFonts")
            onAppearanceChange?()
        }
    }
    public var repeatBounce: Bool = false {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(repeatBounce, forKey: "RepeatBounce")
        }
    }
    public var detectDoubleByte: Bool = false {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(detectDoubleByte, forKey: "DetectDoubleByte")
        }
    }
    public var shouldPreferImagePreviewer: Bool = true {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(shouldPreferImagePreviewer, forKey: "ShouldPreferImagePreviewer")
        }
    }
    public var defaultEncoding: YLEncoding = .YLBig5Encoding {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(Int(defaultEncoding.rawValue), forKey: "DefaultEncoding")
        }
    }
    public var defaultANSIColorKey: YLANSIColorKey = .YLCtrlUANSIColorKey {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(Int(defaultANSIColorKey.rawValue), forKey: "DefaultANSIColorKey")
        }
    }
    public var blinkTicker: Bool = false
    
    public var chineseFontSize: CGFloat = 22.0 {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(Float(chineseFontSize), forKey: "ChineseFontSize")
            refreshFont()
            onAppearanceChange?()
        }
    }
    public var englishFontSize: CGFloat = 18.0 {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(Float(englishFontSize), forKey: "EnglishFontSize")
            refreshFont()
            onAppearanceChange?()
        }
    }
    public var chineseFontPaddingLeft: CGFloat = 1.0 {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(Float(chineseFontPaddingLeft), forKey: "ChinesePaddingLeft")
            onAppearanceChange?()
        }
    }
    public var englishFontPaddingLeft: CGFloat = 1.0 {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(Float(englishFontPaddingLeft), forKey: "EnglishPaddingLeft")
            onAppearanceChange?()
        }
    }
    public var chineseFontPaddingBottom: CGFloat = 1.0 {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(Float(chineseFontPaddingBottom), forKey: "ChinesePaddingBottom")
            onAppearanceChange?()
        }
    }
    public var englishFontPaddingBottom: CGFloat = 2.0 {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(Float(englishFontPaddingBottom), forKey: "EnglishPaddingBottom")
            onAppearanceChange?()
        }
    }
    public var chineseFontName: String = "HiraKakuPro-W3" {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(chineseFontName, forKey: "ChineseFontName")
            refreshFont()
            onAppearanceChange?()
        }
    }
    public var englishFontName: String = "Monaco" {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(englishFontName, forKey: "EnglishFontName")
            refreshFont()
            onAppearanceChange?()
        }
    }
    public var bgColorIndex: Int32 = 9
    public var fgColorIndex: Int32 = 7
    
    public override init() {
        super.init()
        defer { isInitializing = false }
        let defaults = UserDefaults.standard
        
        showHiddenText = defaults.bool(forKey: "ShowHiddenText")
        shouldSmoothFonts = defaults.bool(forKey: "ShouldSmoothFonts")
        detectDoubleByte = defaults.bool(forKey: "DetectDoubleByte")
        defaultEncoding = YLEncoding(rawValue: UInt16(defaults.integer(forKey: "DefaultEncoding"))) ?? .YLBig5Encoding
        defaultANSIColorKey = YLANSIColorKey(rawValue: UInt16(defaults.integer(forKey: "DefaultANSIColorKey"))) ?? .YLCtrlUANSIColorKey
        repeatBounce = defaults.bool(forKey: "RepeatBounce")
        
        if defaults.object(forKey: "ShouldPreferImagePreviewer") != nil {
            shouldPreferImagePreviewer = defaults.bool(forKey: "ShouldPreferImagePreviewer")
        } else {
            shouldPreferImagePreviewer = true
        }
        
        row = 24
        column = 80
        
        let width = defaults.float(forKey: "CellWidth")
        cellWidth = width == 0 ? 12.0 : CGFloat(width)
        
        let height = defaults.float(forKey: "CellHeight")
        cellHeight = height == 0 ? 24.0 : CGFloat(height)
        
        chineseFontName = defaults.string(forKey: "ChineseFontName") ?? "HiraKakuPro-W3"
        englishFontName = defaults.string(forKey: "EnglishFontName") ?? "Monaco"
        
        let cSize = defaults.float(forKey: "ChineseFontSize")
        chineseFontSize = cSize == 0 ? 22.0 : CGFloat(cSize)
        
        let eSize = defaults.float(forKey: "EnglishFontSize")
        englishFontSize = eSize == 0 ? 18.0 : CGFloat(eSize)
        
        if defaults.object(forKey: "ChinesePaddingLeft") != nil {
            chineseFontPaddingLeft = CGFloat(defaults.float(forKey: "ChinesePaddingLeft"))
        } else {
            chineseFontPaddingLeft = 1.0
        }
        
        if defaults.object(forKey: "EnglishPaddingLeft") != nil {
            englishFontPaddingLeft = CGFloat(defaults.float(forKey: "EnglishPaddingLeft"))
        } else {
            englishFontPaddingLeft = 1.0
        }
        
        if defaults.object(forKey: "ChinesePaddingBottom") != nil {
            chineseFontPaddingBottom = CGFloat(defaults.float(forKey: "ChinesePaddingBottom"))
        } else {
            chineseFontPaddingBottom = 1.0
        }
        
        if defaults.object(forKey: "EnglishPaddingBottom") != nil {
            englishFontPaddingBottom = CGFloat(defaults.float(forKey: "EnglishPaddingBottom"))
        } else {
            englishFontPaddingBottom = 2.0
        }
        
        // Colors init from user defaults or standard defaults
        loadColor(index: 0, key: "ColorBlack", defaultColor: NSColor(calibratedRed: 0.00, green: 0.00, blue: 0.00, alpha: 1.0))
        loadColor(index: 0, key: "ColorBlackHilite", hilite: true, defaultColor: NSColor(calibratedRed: 0.25, green: 0.25, blue: 0.25, alpha: 1.0))
        loadColor(index: 1, key: "ColorRed", defaultColor: NSColor(calibratedRed: 0.50, green: 0.00, blue: 0.00, alpha: 1.0))
        loadColor(index: 1, key: "ColorRedHilite", hilite: true, defaultColor: NSColor(calibratedRed: 1.00, green: 0.00, blue: 0.00, alpha: 1.0))
        loadColor(index: 2, key: "ColorGreen", defaultColor: NSColor(calibratedRed: 0.00, green: 0.50, blue: 0.00, alpha: 1.0))
        loadColor(index: 2, key: "ColorGreenHilite", hilite: true, defaultColor: NSColor(calibratedRed: 0.00, green: 1.00, blue: 0.00, alpha: 1.0))
        loadColor(index: 3, key: "ColorYellow", defaultColor: NSColor(calibratedRed: 0.50, green: 0.50, blue: 0.00, alpha: 1.0))
        loadColor(index: 3, key: "ColorYellowHilite", hilite: true, defaultColor: NSColor(calibratedRed: 1.00, green: 1.00, blue: 0.00, alpha: 1.0))
        loadColor(index: 4, key: "ColorBlue", defaultColor: NSColor(calibratedRed: 0.00, green: 0.00, blue: 0.50, alpha: 1.0))
        loadColor(index: 4, key: "ColorBlueHilite", hilite: true, defaultColor: NSColor(calibratedRed: 0.00, green: 0.00, blue: 1.00, alpha: 1.0))
        loadColor(index: 5, key: "ColorMagenta", defaultColor: NSColor(calibratedRed: 0.50, green: 0.00, blue: 0.50, alpha: 1.0))
        loadColor(index: 5, key: "ColorMagentaHilite", hilite: true, defaultColor: NSColor(calibratedRed: 1.00, green: 0.00, blue: 1.00, alpha: 1.0))
        loadColor(index: 6, key: "ColorCyan", defaultColor: NSColor(calibratedRed: 0.00, green: 0.50, blue: 0.50, alpha: 1.0))
        loadColor(index: 6, key: "ColorCyanHilite", hilite: true, defaultColor: NSColor(calibratedRed: 0.00, green: 1.00, blue: 1.00, alpha: 1.0))
        loadColor(index: 7, key: "ColorWhite", defaultColor: NSColor(calibratedRed: 0.50, green: 0.50, blue: 0.50, alpha: 1.0))
        loadColor(index: 7, key: "ColorWhiteHilite", hilite: true, defaultColor: NSColor(calibratedRed: 1.00, green: 1.00, blue: 1.00, alpha: 1.0))
        
        colorTable[0][8] = NSColor(calibratedRed: 0.75, green: 0.75, blue: 0.75, alpha: 1.0)
        colorTable[1][8] = NSColor(calibratedRed: 1.00, green: 1.00, blue: 1.00, alpha: 1.0)
        
        loadColor(index: 9, key: "ColorBG", defaultColor: NSColor(calibratedRed: 0.00, green: 0.00, blue: 0.00, alpha: 1.0))
        loadColor(index: 9, key: "ColorBGHilite", hilite: true, defaultColor: NSColor(calibratedRed: 0.00, green: 0.00, blue: 0.00, alpha: 1.0))
        
        bgColorIndex = 9
        fgColorIndex = 7
        
        refreshFont()
    }
    
    private func loadColor(index: Int, key: String, hilite: Bool = false, defaultColor: NSColor) {
        let h = hilite ? 1 : 0
        if let c = UserDefaults.standard.myColor(forKey: key) {
            colorTable[h][index] = c.usingColorSpace(.sRGB) ?? c
        } else {
            colorTable[h][index] = defaultColor
        }
    }
    
    private func saveColor(index: Int, key: String, hilite: Bool = false, color: NSColor?) {
        let h = hilite ? 1 : 0
        let c = color ?? NSColor.black
        colorTable[h][index] = c.usingColorSpace(.sRGB) ?? c
        UserDefaults.standard.setMyColor(c, forKey: key)
        if !isInitializing {
            refreshFont()
            onAppearanceChange?()
        }
    }
    
    public func refreshFont() {
        chineseCTFont = CTFontCreateWithName(chineseFontName as CFString, chineseFontSize, nil)
        englishCTFont = CTFontCreateWithName(englishFontName as CFString, englishFontSize, nil)
        
        let zero: Int = 0
        let number = NSNumber(value: zero)
        
        for i in 0..<10 {
            for j in 0..<2 {
                let cDict: [CFString: Any] = [
                    kCTFontAttributeName: chineseCTFont!,
                    kCTForegroundColorAttributeName: colorTable[j][i],
                    kCTLigatureAttributeName: number
                ]
                cCTAttribute[j][i] = cDict as CFDictionary
                
                let eDict: [CFString: Any] = [
                    kCTFontAttributeName: englishCTFont!,
                    kCTForegroundColorAttributeName: colorTable[j][i],
                    kCTLigatureAttributeName: number
                ]
                eCTAttribute[j][i] = eDict as CFDictionary
            }
        }
    }
    
    public func updateBlinkTicker() {
        blinkTicker = !blinkTicker
    }
    
    public func colorAtIndex(_ i: Int32, hilite h: Bool) -> NSColor {
        let hIdx = h ? 1 : 0
        if i >= 0 && i < 10 {
            return colorTable[hIdx][Int(i)]
        }
        return colorTable[0][9]
    }
    
    public func setColor(_ c: NSColor?, hilite h: Bool, atIndex i: Int32) {
        let hIdx = h ? 1 : 0
        if i >= 0 && i < 10 {
            let color = c ?? NSColor.black
            colorTable[hIdx][Int(i)] = color.usingColorSpace(.sRGB) ?? color
            if !isInitializing {
                refreshFont()
                onAppearanceChange?()
            }
        }
    }
    
    // Color Properties
    public var colorBlack: NSColor? {
        get { return colorTable[0][0] }
        set { saveColor(index: 0, key: "ColorBlack", color: newValue) }
    }
    public var colorBlackHilite: NSColor? {
        get { return colorTable[1][0] }
        set { saveColor(index: 0, key: "ColorBlackHilite", hilite: true, color: newValue) }
    }
    public var colorRed: NSColor? {
        get { return colorTable[0][1] }
        set { saveColor(index: 1, key: "ColorRed", color: newValue) }
    }
    public var colorRedHilite: NSColor? {
        get { return colorTable[1][1] }
        set { saveColor(index: 1, key: "ColorRedHilite", hilite: true, color: newValue) }
    }
    public var colorGreen: NSColor? {
        get { return colorTable[0][2] }
        set { saveColor(index: 2, key: "ColorGreen", color: newValue) }
    }
    public var colorGreenHilite: NSColor? {
        get { return colorTable[1][2] }
        set { saveColor(index: 2, key: "ColorGreenHilite", hilite: true, color: newValue) }
    }
    public var colorYellow: NSColor? {
        get { return colorTable[0][3] }
        set { saveColor(index: 3, key: "ColorYellow", color: newValue) }
    }
    public var colorYellowHilite: NSColor? {
        get { return colorTable[1][3] }
        set { saveColor(index: 3, key: "ColorYellowHilite", hilite: true, color: newValue) }
    }
    public var colorBlue: NSColor? {
        get { return colorTable[0][4] }
        set { saveColor(index: 4, key: "ColorBlue", color: newValue) }
    }
    public var colorBlueHilite: NSColor? {
        get { return colorTable[1][4] }
        set { saveColor(index: 4, key: "ColorBlueHilite", hilite: true, color: newValue) }
    }
    public var colorMagenta: NSColor? {
        get { return colorTable[0][5] }
        set { saveColor(index: 5, key: "ColorMagenta", color: newValue) }
    }
    public var colorMagentaHilite: NSColor? {
        get { return colorTable[1][5] }
        set { saveColor(index: 5, key: "ColorMagentaHilite", hilite: true, color: newValue) }
    }
    public var colorCyan: NSColor? {
        get { return colorTable[0][6] }
        set { saveColor(index: 6, key: "ColorCyan", color: newValue) }
    }
    public var colorCyanHilite: NSColor? {
        get { return colorTable[1][6] }
        set { saveColor(index: 6, key: "ColorCyanHilite", hilite: true, color: newValue) }
    }
    public var colorWhite: NSColor? {
        get { return colorTable[0][7] }
        set { saveColor(index: 7, key: "ColorWhite", color: newValue) }
    }
    public var colorWhiteHilite: NSColor? {
        get { return colorTable[1][7] }
        set { saveColor(index: 7, key: "ColorWhiteHilite", hilite: true, color: newValue) }
    }
    public var colorBG: NSColor? {
        get { return colorTable[0][9] }
        set { saveColor(index: 9, key: "ColorBG", color: newValue) }
    }
    public var colorBGHilite: NSColor? {
        get { return colorTable[1][9] }
        set { saveColor(index: 9, key: "ColorBGHilite", hilite: true, color: newValue) }
    }
    
    // MARK: - Dynamic Scaling & Zoom
    @MainActor
    public func applyCellSize(width: CGFloat, height: CGFloat) {
        let clampedWidth = max(6.0, min(30.0, (width * 2.0).rounded() / 2.0))
        let clampedHeight = max(12.0, min(60.0, (height * 2.0).rounded() / 2.0))
        guard clampedWidth != cellWidth || clampedHeight != cellHeight else { return }
        
        let scale = clampedHeight / 24.0
        isInitializing = true
        cellWidth = clampedWidth
        cellHeight = clampedHeight
        chineseFontSize = max(10.0, (22.0 * scale).rounded())
        englishFontSize = max(9.0, (18.0 * scale).rounded())
        isInitializing = false
        
        let defaults = UserDefaults.standard
        defaults.set(Float(cellWidth), forKey: "CellWidth")
        defaults.set(Float(cellHeight), forKey: "CellHeight")
        defaults.set(Float(chineseFontSize), forKey: "ChineseFontSize")
        defaults.set(Float(englishFontSize), forKey: "EnglishFontSize")
        
        refreshFont()
        onLayoutChange?()
    }
    
    @MainActor
    public func zoomIn() {
        applyCellSize(width: cellWidth + 1.0, height: cellHeight + 2.0)
    }
    
    @MainActor
    public func zoomOut() {
        applyCellSize(width: cellWidth - 1.0, height: cellHeight - 2.0)
    }
    
    @MainActor
    public func resetZoom() {
        applyCellSize(width: 12.0, height: 24.0)
    }
}
