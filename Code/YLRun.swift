import Foundation

@objc(YLRunType)
public enum YLRunType: Int {
    case string = 0
    case space
    case tab
    case newLine
}

@objc(YLRun)
public class YLRun: NSObject {
    @objc public var encoding: YLEncoding
    @objc public var type: YLRunType
    @objc public var string: String
    
    @objc public init(string: String, type: YLRunType, encoding: YLEncoding) {
        self.string = string
        self.type = type
        self.encoding = encoding
        super.init()
    }
    
    @objc public static func run(withString string: String, type: YLRunType, encoding: YLEncoding) -> YLRun {
        return YLRun(string: string, type: type, encoding: encoding)
    }
    
    @objc public var length: Int {
        if type == .space { return 1 }
        if type == .tab { return 1 } // matches original C comment: not correct!
        
        var length = 0
        for char in string.utf16 {
            if char > 0x0020 && char < 0x0080 {
                length += 1
            } else if char >= 0x0080 {
                // Call low-level mapping functions (bridged from encoding.h)
                let lookupVal = (encoding == .YLBig5Encoding) ? lookupU2B(char) : lookupU2G(char)
                if lookupVal != 0x0000 {
                    length += 2
                }
            }
        }
        return length
    }
    
    @objc public func appendString(_ string: String) {
        assert(self.type == .string, "You can only append run to a string.")
        self.string += string
    }
    
    @objc public func forceSplitToMaxLength(_ maxLength: Int) -> [YLRun] {
        assert(self.type == .string, "You can only split a string.")
        var length = 0
        var firstString = ""
        var secondString = ""
        
        for char in string {
            guard let utf16Val = char.utf16.first else { continue }
            if utf16Val > 0x0020 && utf16Val < 0x0080 {
                length += 1
            } else if utf16Val >= 0x0080 {
                let lookupVal = (encoding == .YLBig5Encoding) ? lookupU2B(utf16Val) : lookupU2G(utf16Val)
                if lookupVal != 0x0000 {
                    length += 2
                }
            }
            
            if length <= maxLength {
                firstString.append(char)
            } else {
                secondString.append(char)
            }
        }
        
        if firstString.isEmpty || secondString.isEmpty {
            return [self]
        }
        
        return [
            YLRun(string: firstString, type: .string, encoding: encoding),
            YLRun(string: secondString, type: .string, encoding: encoding)
        ]
    }
    
    @objc public func shouldBeAvoidAtBeginOfLine() -> Bool {
        if type == .space || type == .tab { return true }
        if type != .string { return false }
        
        let forbiddenTokens = ["，", "。", "、", "：", "；", "？", "！", "」", "』", "》", "〉", "】", "〕", "）", ",", ".", ":", ";", "!", ")", "]", "}", "-", "–"]
        for token in forbiddenTokens {
            if string.hasPrefix(token) {
                return true
            }
        }
        return false
    }
    
    @objc public func shouldBeAvoidAtEndOfLine() -> Bool {
        let forbiddenTokens = ["「", "『", "《", "〈", "【", "〔", "（", "(", "[", "{", "'", "\""]
        for token in forbiddenTokens {
            if string.hasSuffix(token) {
                return true
            }
        }
        return false
    }
}
