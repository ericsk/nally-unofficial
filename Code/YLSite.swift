import Foundation
import Observation

@Observable
@objc(YLSite)
@objcMembers
public class YLSite: NSObject, NSCopying, Codable {
    public dynamic var name: String = "Site Name"
    public dynamic var address: String = "(your.site.org)"
    public dynamic var account: String = ""
    public dynamic var password: String = ""
    public dynamic var encoding: YLEncoding = .YLBig5Encoding
    public dynamic var ansiColorKey: YLANSIColorKey = .YLCtrlUANSIColorKey
    public dynamic var detectDoubleByte: Bool = true
    
    enum CodingKeys: String, CodingKey {
        case name
        case address
        case account
        case password
        case encoding
        case ansiColorKey
        case detectDoubleByte
    }
    
    public override init() {
        super.init()
    }
    
    public required init(from decoder: Decoder) throws {
        super.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        address = try container.decode(String.self, forKey: .address)
        account = try container.decodeIfPresent(String.self, forKey: .account) ?? ""
        password = try container.decodeIfPresent(String.self, forKey: .password) ?? ""
        encoding = try container.decode(YLEncoding.self, forKey: .encoding)
        ansiColorKey = try container.decode(YLANSIColorKey.self, forKey: .ansiColorKey)
        detectDoubleByte = try container.decode(Bool.self, forKey: .detectDoubleByte)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(address, forKey: .address)
        try container.encode(account, forKey: .account)
        try container.encode(password, forKey: .password)
        try container.encode(encoding, forKey: .encoding)
        try container.encode(ansiColorKey, forKey: .ansiColorKey)
        try container.encode(detectDoubleByte, forKey: .detectDoubleByte)
    }
    
    public class func site() -> YLSite {
        return YLSite()
    }
    
    public class func site(withDictionary dict: [String: Any]) -> YLSite {
        let s = YLSite()
        s.name = dict["name"] as? String ?? ""
        s.address = dict["address"] as? String ?? ""
        s.account = dict["account"] as? String ?? ""
        s.password = dict["password"] as? String ?? ""
        
        if let enc = dict["encoding"] as? NSNumber {
            s.encoding = YLEncoding(rawValue: enc.uint16Value) ?? .YLBig5Encoding
        }
        if let colorKey = dict["ansicolorkey"] as? NSNumber {
            s.ansiColorKey = YLANSIColorKey(rawValue: colorKey.uint16Value) ?? .YLCtrlUANSIColorKey
        }
        if let detect = dict["detectdoublebyte"] as? Bool {
            s.detectDoubleByte = detect
        }
        return s
    }
    
    public func dictionaryOfSite() -> [String: Any] {
        var dict: [String: Any] = [:]
        dict["name"] = name
        dict["address"] = address
        dict["encoding"] = NSNumber(value: encoding.rawValue)
        dict["ansicolorkey"] = NSNumber(value: ansiColorKey.rawValue)
        dict["detectdoublebyte"] = NSNumber(value: detectDoubleByte)
        return dict
    }
    
    public override var description: String {
        return "\(name):\(address)"
    }
    
    public func copy(with zone: NSZone? = nil) -> Any {
        let s = YLSite()
        s.name = name
        s.address = address
        s.encoding = encoding
        s.ansiColorKey = ansiColorKey
        s.detectDoubleByte = detectDoubleByte
        s.account = account
        s.password = password
        return s
    }
}
