import Foundation
import Observation
import Cocoa

@Observable
@objc(YLLGlobalConfig)
@objcMembers
public class YLLGlobalConfig: NSObject {
    private static var sSharedInstance: YLLGlobalConfig?
    
    public class func sharedInstance() -> YLLGlobalConfig {
        if sSharedInstance == nil {
            sSharedInstance = YLLGlobalConfig()
        }
        return sSharedInstance!
    }
    
    // Internal instance variables
    public var _messageCount: Int32 = 0
    public var _row: Int32 = 24
    public var _column: Int32 = 80
    public var _cellWidth: CGFloat = 12.0
    public var _cellHeight: CGFloat = 24.0
    
    public var _bgColorIndex: Int32 = 9
    public var _fgColorIndex: Int32 = 7
    
    public var _showHiddenText: Bool = false
    public var _blinkTicker: Bool = false
    public var _shouldSmoothFonts: Bool = false
    public var _detectDoubleByte: Bool = false
    public var _repeatBounce: Bool = false
    public var _shouldPreferImagePreviewer: Bool = true
    public var _defaultEncoding: YLEncoding = .YLBig5Encoding
    public var _defaultANSIColorKey: YLANSIColorKey = .YLCtrlUANSIColorKey
    
    public var _chineseFontSize: CGFloat = 22.0
    public var _englishFontSize: CGFloat = 18.0
    public var _chineseFontPaddingLeft: CGFloat = 1.0
    public var _englishFontPaddingLeft: CGFloat = 1.0
    public var _chineseFontPaddingBottom: CGFloat = 1.0
    public var _englishFontPaddingBottom: CGFloat = 2.0
    public var _chineseFontName: String = "HiraKakuPro-W3"
    public var _englishFontName: String = "Monaco"
    
    public var _cCTFont: CTFont?
    public var _eCTFont: CTFont?
    public var _cCGFont: CGFont?
    public var _eCGFont: CGFont?
    
    // Store 2x10 color tables
    // 0 is normal, 1 is hilite
    private var colorTable: [[NSColor]] = Array(repeating: Array(repeating: NSColor.black, count: 10), count: 2)
    
    // Store 2x10 CoreText attributes
    private var cCTAttribute: [[CFDictionary?]] = Array(repeating: Array(repeating: nil, count: 10), count: 2)
    private var eCTAttribute: [[CFDictionary?]] = Array(repeating: Array(repeating: nil, count: 10), count: 2)
    
    // Helper properties for Objective-C++ direct member access:
    public var chineseCTFont: CTFont? { return _cCTFont }
    public var englishCTFont: CTFont? { return _eCTFont }
    
    public func chineseAttribute(withHilite hilite: Int, index: Int) -> CFDictionary? {
        guard index >= 0 && index < 10 && hilite >= 0 && hilite < 2 else { return nil }
        return cCTAttribute[hilite][index]
    }
    
    public func englishAttribute(withHilite hilite: Int, index: Int) -> CFDictionary? {
        guard index >= 0 && index < 10 && hilite >= 0 && hilite < 2 else { return nil }
        return eCTAttribute[hilite][index]
    }
    
    public override init() {
        super.init()
        let defaults = UserDefaults.standard
        
        _showHiddenText = defaults.bool(forKey: "ShowHiddenText")
        _shouldSmoothFonts = defaults.bool(forKey: "ShouldSmoothFonts")
        _detectDoubleByte = defaults.bool(forKey: "DetectDoubleByte")
        _defaultEncoding = YLEncoding(rawValue: UInt16(defaults.integer(forKey: "DefaultEncoding"))) ?? .YLBig5Encoding
        _defaultANSIColorKey = YLANSIColorKey(rawValue: UInt16(defaults.integer(forKey: "DefaultANSIColorKey"))) ?? .YLCtrlUANSIColorKey
        _repeatBounce = defaults.bool(forKey: "RepeatBounce")
        
        if defaults.object(forKey: "ShouldPreferImagePreviewer") != nil {
            _shouldPreferImagePreviewer = defaults.bool(forKey: "ShouldPreferImagePreviewer")
        } else {
            _shouldPreferImagePreviewer = true
        }
        
        _row = 24
        _column = 80
        
        let width = defaults.float(forKey: "CellWidth")
        _cellWidth = width == 0 ? 12.0 : CGFloat(width)
        
        let height = defaults.float(forKey: "CellHeight")
        _cellHeight = height == 0 ? 24.0 : CGFloat(height)
        
        _chineseFontName = defaults.string(forKey: "ChineseFontName") ?? "HiraKakuPro-W3"
        _englishFontName = defaults.string(forKey: "EnglishFontName") ?? "Monaco"
        
        let cSize = defaults.float(forKey: "ChineseFontSize")
        _chineseFontSize = cSize == 0 ? 22.0 : CGFloat(cSize)
        
        let eSize = defaults.float(forKey: "EnglishFontSize")
        _englishFontSize = eSize == 0 ? 18.0 : CGFloat(eSize)
        
        if defaults.object(forKey: "ChinesePaddingLeft") != nil {
            _chineseFontPaddingLeft = CGFloat(defaults.float(forKey: "ChinesePaddingLeft"))
        } else {
            _chineseFontPaddingLeft = 1.0
        }
        
        if defaults.object(forKey: "EnglishPaddingLeft") != nil {
            _englishFontPaddingLeft = CGFloat(defaults.float(forKey: "EnglishPaddingLeft"))
        } else {
            _englishFontPaddingLeft = 1.0
        }
        
        if defaults.object(forKey: "ChinesePaddingBottom") != nil {
            _chineseFontPaddingBottom = CGFloat(defaults.float(forKey: "ChinesePaddingBottom"))
        } else {
            _chineseFontPaddingBottom = 1.0
        }
        
        if defaults.object(forKey: "EnglishPaddingBottom") != nil {
            _englishFontPaddingBottom = CGFloat(defaults.float(forKey: "EnglishPaddingBottom"))
        } else {
            _englishFontPaddingBottom = 2.0
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
        
        _bgColorIndex = 9
        _fgColorIndex = 7
        
        defaults.synchronize()
        refreshFont()
    }
    
    private func loadColor(index: Int, key: String, hilite: Bool = false, defaultColor: NSColor) {
        let h = hilite ? 1 : 0
        if let c = UserDefaults.standard.myColor(forKey: key) {
            colorTable[h][index] = c.usingColorSpaceName(.calibratedRGB) ?? c
        } else {
            colorTable[h][index] = defaultColor
        }
    }
    
    private func saveColor(index: Int, key: String, hilite: Bool = false, color: NSColor?) {
        let h = hilite ? 1 : 0
        let c = color ?? NSColor.black
        colorTable[h][index] = c.usingColorSpaceName(.calibratedRGB) ?? c
        UserDefaults.standard.setMyColor(c, forKey: key)
    }
    
    public func refreshFont() {
        _cCTFont = CTFontCreateWithName(_chineseFontName as CFString, _chineseFontSize, nil)
        _eCTFont = CTFontCreateWithName(_englishFontName as CFString, _englishFontSize, nil)
        _cCGFont = CTFontCopyGraphicsFont(_cCTFont!, nil)
        _eCGFont = CTFontCopyGraphicsFont(_eCTFont!, nil)
        
        let zero: Int = 0
        let number = NSNumber(value: zero)
        
        for i in 0..<10 {
            for j in 0..<2 {
                // Use Swift Dictionary to build the attributes dictionary cleanly
                let cDict: [CFString: Any] = [
                    kCTFontAttributeName: _cCTFont!,
                    kCTForegroundColorAttributeName: colorTable[j][i],
                    kCTLigatureAttributeName: number
                ]
                cCTAttribute[j][i] = cDict as CFDictionary
                
                let eDict: [CFString: Any] = [
                    kCTFontAttributeName: _eCTFont!,
                    kCTForegroundColorAttributeName: colorTable[j][i],
                    kCTLigatureAttributeName: number
                ]
                eCTAttribute[j][i] = eDict as CFDictionary
            }
        }
    }
    
    // KVO Properties
    public dynamic var messageCount: Int32 {
        get { return _messageCount }
        set { _messageCount = newValue }
    }
    
    public dynamic var row: Int32 {
        get { return _row }
        set { _row = newValue }
    }
    
    public dynamic var column: Int32 {
        get { return _column }
        set { _column = newValue }
    }
    
    public dynamic var cellWidth: CGFloat {
        get { return _cellWidth }
        set {
            let val = newValue == 0 ? 12.0 : newValue
            _cellWidth = val
            UserDefaults.standard.set(Float(val), forKey: "CellWidth")
        }
    }
    
    public dynamic var cellHeight: CGFloat {
        get { return _cellHeight }
        set {
            let val = newValue == 0 ? 24.0 : newValue
            _cellHeight = val
            UserDefaults.standard.set(Float(val), forKey: "CellHeight")
        }
    }
    
    public dynamic var showHiddenText: Bool {
        get { return _showHiddenText }
        set {
            _showHiddenText = newValue
            UserDefaults.standard.set(newValue, forKey: "ShowHiddenText")
        }
    }
    
    public dynamic var shouldSmoothFonts: Bool {
        get { return _shouldSmoothFonts }
        set {
            _shouldSmoothFonts = newValue
            UserDefaults.standard.set(newValue, forKey: "ShouldSmoothFonts")
        }
    }
    
    public dynamic var repeatBounce: Bool {
        get { return _repeatBounce }
        set {
            _repeatBounce = newValue
            UserDefaults.standard.set(newValue, forKey: "RepeatBounce")
        }
    }
    
    public dynamic var detectDoubleByte: Bool {
        get { return _detectDoubleByte }
        set {
            _detectDoubleByte = newValue
            UserDefaults.standard.set(newValue, forKey: "DetectDoubleByte")
        }
    }
    
    public dynamic var shouldPreferImagePreviewer: Bool {
        get { return _shouldPreferImagePreviewer }
        set {
            _shouldPreferImagePreviewer = newValue
            UserDefaults.standard.set(newValue, forKey: "ShouldPreferImagePreviewer")
        }
    }
    
    public dynamic var defaultEncoding: YLEncoding {
        get { return _defaultEncoding }
        set {
            _defaultEncoding = newValue
            UserDefaults.standard.set(Int(newValue.rawValue), forKey: "DefaultEncoding")
        }
    }
    
    public dynamic var defaultANSIColorKey: YLANSIColorKey {
        get { return _defaultANSIColorKey }
        set {
            _defaultANSIColorKey = newValue
            UserDefaults.standard.set(Int(newValue.rawValue), forKey: "DefaultANSIColorKey")
        }
    }
    
    public dynamic var blinkTicker: Bool {
        get { return _blinkTicker }
        set { _blinkTicker = newValue }
    }
    
    public func updateBlinkTicker() {
        blinkTicker = !blinkTicker
    }
    
    public dynamic var chineseFontSize: CGFloat {
        get { return _chineseFontSize }
        set {
            let val = newValue == 0 ? 22.0 : newValue
            _chineseFontSize = val
            UserDefaults.standard.set(Float(val), forKey: "ChineseFontSize")
        }
    }
    
    public dynamic var englishFontSize: CGFloat {
        get { return _englishFontSize }
        set {
            let val = newValue == 0 ? 18.0 : newValue
            _englishFontSize = val
            UserDefaults.standard.set(Float(val), forKey: "EnglishFontSize")
        }
    }
    
    public dynamic var chineseFontPaddingLeft: CGFloat {
        get { return _chineseFontPaddingLeft }
        set {
            _chineseFontPaddingLeft = newValue
            UserDefaults.standard.set(Float(newValue), forKey: "ChinesePaddingLeft")
        }
    }
    
    public dynamic var englishFontPaddingLeft: CGFloat {
        get { return _englishFontPaddingLeft }
        set {
            _englishFontPaddingLeft = newValue
            UserDefaults.standard.set(Float(newValue), forKey: "EnglishPaddingLeft")
        }
    }
    
    public dynamic var chineseFontPaddingBottom: CGFloat {
        get { return _chineseFontPaddingBottom }
        set {
            _chineseFontPaddingBottom = newValue
            UserDefaults.standard.set(Float(newValue), forKey: "ChinesePaddingBottom")
        }
    }
    
    public dynamic var englishFontPaddingBottom: CGFloat {
        get { return _englishFontPaddingBottom }
        set {
            _englishFontPaddingBottom = newValue
            UserDefaults.standard.set(Float(newValue), forKey: "EnglishPaddingBottom")
        }
    }
    
    public dynamic var chineseFontName: String {
        get { return _chineseFontName }
        set {
            _chineseFontName = newValue
            UserDefaults.standard.set(newValue, forKey: "ChineseFontName")
        }
    }
    
    public dynamic var englishFontName: String {
        get { return _englishFontName }
        set {
            _englishFontName = newValue
            UserDefaults.standard.set(newValue, forKey: "EnglishFontName")
        }
    }
    
    public dynamic var bgColorIndex: Int32 {
        get { return _bgColorIndex }
        set { _bgColorIndex = newValue }
    }
    
    public dynamic var fgColorIndex: Int32 {
        get { return _fgColorIndex }
        set { _fgColorIndex = newValue }
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
            colorTable[hIdx][Int(i)] = color.usingColorSpaceName(.calibratedRGB) ?? color
        }
    }
    
    // Color Properties
    public dynamic var colorBlack: NSColor? {
        get { return colorTable[0][0] }
        set { saveColor(index: 0, key: "ColorBlack", color: newValue) }
    }
    public dynamic var colorBlackHilite: NSColor? {
        get { return colorTable[1][0] }
        set { saveColor(index: 0, key: "ColorBlackHilite", hilite: true, color: newValue) }
    }
    public dynamic var colorRed: NSColor? {
        get { return colorTable[0][1] }
        set { saveColor(index: 1, key: "ColorRed", color: newValue) }
    }
    public dynamic var colorRedHilite: NSColor? {
        get { return colorTable[1][1] }
        set { saveColor(index: 1, key: "ColorRedHilite", hilite: true, color: newValue) }
    }
    public dynamic var colorGreen: NSColor? {
        get { return colorTable[0][2] }
        set { saveColor(index: 2, key: "ColorGreen", color: newValue) }
    }
    public dynamic var colorGreenHilite: NSColor? {
        get { return colorTable[1][2] }
        set { saveColor(index: 2, key: "ColorGreenHilite", hilite: true, color: newValue) }
    }
    public dynamic var colorYellow: NSColor? {
        get { return colorTable[0][3] }
        set { saveColor(index: 3, key: "ColorYellow", color: newValue) }
    }
    public dynamic var colorYellowHilite: NSColor? {
        get { return colorTable[1][3] }
        set { saveColor(index: 3, key: "ColorYellowHilite", hilite: true, color: newValue) }
    }
    public dynamic var colorBlue: NSColor? {
        get { return colorTable[0][4] }
        set { saveColor(index: 4, key: "ColorBlue", color: newValue) }
    }
    public dynamic var colorBlueHilite: NSColor? {
        get { return colorTable[1][4] }
        set { saveColor(index: 4, key: "ColorBlueHilite", hilite: true, color: newValue) }
    }
    public dynamic var colorMagenta: NSColor? {
        get { return colorTable[0][5] }
        set { saveColor(index: 5, key: "ColorMagenta", color: newValue) }
    }
    public dynamic var colorMagentaHilite: NSColor? {
        get { return colorTable[1][5] }
        set { saveColor(index: 5, key: "ColorMagentaHilite", hilite: true, color: newValue) }
    }
    public dynamic var colorCyan: NSColor? {
        get { return colorTable[0][6] }
        set { saveColor(index: 6, key: "ColorCyan", color: newValue) }
    }
    public dynamic var colorCyanHilite: NSColor? {
        get { return colorTable[1][6] }
        set { saveColor(index: 6, key: "ColorCyanHilite", hilite: true, color: newValue) }
    }
    public dynamic var colorWhite: NSColor? {
        get { return colorTable[0][7] }
        set { saveColor(index: 7, key: "ColorWhite", color: newValue) }
    }
    public dynamic var colorWhiteHilite: NSColor? {
        get { return colorTable[1][7] }
        set { saveColor(index: 7, key: "ColorWhiteHilite", hilite: true, color: newValue) }
    }
    public dynamic var colorBG: NSColor? {
        get { return colorTable[0][9] }
        set { saveColor(index: 9, key: "ColorBG", color: newValue) }
    }
    public dynamic var colorBGHilite: NSColor? {
        get { return colorTable[1][9] }
        set { saveColor(index: 9, key: "ColorBGHilite", hilite: true, color: newValue) }
    }
}
