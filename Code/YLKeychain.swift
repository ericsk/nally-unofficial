import Foundation
import Security

@objc(YLKeychain)
@objcMembers
public class YLKeychain: NSObject {
    
    public static func accounts(forService service: String) -> [[String: Any]]? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let items = result as? [[String: Any]] else {
            return nil
        }
        
        // Map keys to match SSKeychain's output format ("acct" -> account)
        return items.map { item in
            var dict = [String: Any]()
            if let account = item[kSecAttrAccount as String] as? String {
                dict["acct"] = account
            }
            return dict
        }
    }
    
    public static func password(forService service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
        
        return nil
    }
    
    public static func setPassword(_ password: String, forService service: String, account: String) throws {
        guard let data = password.data(using: .utf8) else {
            throw NSError(domain: "YLKeychain", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid password encoding"])
        }
        
        // First delete any existing password to avoid duplicate items
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            throw NSError(domain: "YLKeychain", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "SecItemAdd failed with status: \(status)"])
        }
    }
}
