import Foundation
import SwiftData

@Model
public final class YLSite: Identifiable, Codable {
    @Attribute(.unique) public var id: UUID = UUID()
    public var name: String = "Site Name"
    public var address: String = "(your.site.org)"
    public var account: String = ""
    public var password: String = ""
    public var encoding: YLEncoding = YLEncoding.YLBig5Encoding
    public var ansiColorKey: YLANSIColorKey = YLANSIColorKey.YLCtrlUANSIColorKey
    public var detectDoubleByte: Bool = true
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case address
        case account
        case password
        case encoding
        case ansiColorKey
        case detectDoubleByte
    }
    
    public init(
        id: UUID = UUID(),
        name: String = "Site Name",
        address: String = "(your.site.org)",
        account: String = "",
        password: String = "",
        encoding: YLEncoding = .YLBig5Encoding,
        ansiColorKey: YLANSIColorKey = .YLCtrlUANSIColorKey,
        detectDoubleByte: Bool = true
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.account = account
        self.password = password
        self.encoding = encoding
        self.ansiColorKey = ansiColorKey
        self.detectDoubleByte = detectDoubleByte
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.address = try container.decode(String.self, forKey: .address)
        self.account = try container.decodeIfPresent(String.self, forKey: .account) ?? ""
        self.password = try container.decodeIfPresent(String.self, forKey: .password) ?? ""
        self.encoding = try container.decode(YLEncoding.self, forKey: .encoding)
        self.ansiColorKey = try container.decode(YLANSIColorKey.self, forKey: .ansiColorKey)
        self.detectDoubleByte = try container.decode(Bool.self, forKey: .detectDoubleByte)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(address, forKey: .address)
        try container.encode(account, forKey: .account)
        try container.encode(password, forKey: .password)
        try container.encode(encoding, forKey: .encoding)
        try container.encode(ansiColorKey, forKey: .ansiColorKey)
        try container.encode(detectDoubleByte, forKey: .detectDoubleByte)
    }
    
    public static func site() -> YLSite {
        return YLSite()
    }
    
    public static func site(withDictionary dict: [String: Any]) -> YLSite {
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
    
    public var description: String {
        return "\(name):\(address)"
    }
    
    public func copySite() -> YLSite {
        return YLSite(
            name: name,
            address: address,
            account: account,
            password: password,
            encoding: encoding,
            ansiColorKey: ansiColorKey,
            detectDoubleByte: detectDoubleByte
        )
    }
}
