# Nally Unofficial 100% Swift 移植計畫書 (`SWIFT_MIGRATION.md`)

本文件記錄了 Nally Unofficial 專案最後階段的 Swift 移植計畫，目標是移除所有剩餘的 Objective-C 檔案與 C 橋接結構，使專案成為 100% 純 Swift 實作的 macOS 應用程式，並完全廢除 Bridging Header 混編機制。

---

## 📋 移植追蹤清單 (Migration Checklist)

- [x] **階段 1：改寫 Keychain 模組為純 Swift**
  - [x] 建立 [YLKeychain.swift](file:///Users/ericsk/Projects/Nally-Unofficial/Code/YLKeychain.swift)，直接呼叫 Apple `Security` 框架（`SecItemCopyMatching`、`SecItemAdd` 等 API）管理金鑰庫。
  - [x] 修改 [YLController.swift](file:///Users/ericsk/Projects/Nally-Unofficial/Code/YLController.swift) 中對 `SSKeychain` 的引用。
  - [x] 自專案中移除 `SSKeychain.h/m` 與 `SSKeychainQuery.h/m` 檔案與編譯目標。
- [x] **階段 2：改寫字元編碼對照表 (Encoding Tables)**
  - [x] 編寫轉換腳本，將 [encoding.m](file:///Users/ericsk/Projects/Nally-Unofficial/Code/encoding.m) 內巨大的對照陣列（`B2U`、`G2U`、`U2B`、`U2G`）匯出為 `.bin` 二進位資源檔。
  - [x] 將產生的二進位資料檔加入 Xcode 專案 Resources。
  - [x] 建立 `YLEncodingTable.swift` 實作非同步/延遲載入並讀取上述 binary table。
  - [x] 自專案中移除 [encoding.h](file:///Users/ericsk/Projects/Nally-Unofficial/Code/encoding.h) 與 [encoding.m](file:///Users/ericsk/Projects/Nally-Unofficial/Code/encoding.m)。
- [ ] **階段 3：重構核心資料結構為純 Swift**
  - [ ] 重構 [CommonType.swift](file:///Users/ericsk/Projects/Nally-Unofficial/Code/CommonType.swift)，使其定義的 `TerminalAttribute` 與 `TerminalCell` 成為第一等公民，廢除對 C `cell` 與 `attribute` 結構的依賴與轉型代碼。
  - [ ] 修改 [YLTerminal.swift](file:///Users/ericsk/Projects/Nally-Unofficial/Code/YLTerminal.swift) 的字元快取緩衝區與繪圖層 [YLViewDrawing.swift](file:///Users/ericsk/Projects/Nally-Unofficial/Code/YLViewDrawing.swift) 等，全面直接使用 Swift 原生 Struct。
  - [ ] 自專案中移除 [CommonType.h](file:///Users/ericsk/Projects/Nally-Unofficial/Code/CommonType.h) 與 [CommonType.m](file:///Users/ericsk/Projects/Nally-Unofficial/Code/CommonType.m)。
  - [ ] **完全刪除 [Nally-Bridging-Header.h](file:///Users/ericsk/Projects/Nally-Unofficial/Code/Nally-Bridging-Header.h)！**
- [ ] **階段 4：測試模組與編譯清理**
  - [x] 將單元測試 [TextSuiteTests.m](file:///Users/ericsk/Projects/Nally-Unofficial/Tests/TextSuiteTests.m) 與 [TextSuiteTests.h](file:///Users/ericsk/Projects/Nally-Unofficial/Tests/TextSuiteTests.h) 重寫為 Swift 版本的 `TextSuiteTests.swift`。
  - [ ] 進行專案的 Release 與 Debug 完整編譯與功能手動測試。

---

## 🛠️ 各模組移植技術分析

### 1. Keychain 模組
舊代碼採用 `SSKeychain` (基於 Objective-C)。
在 Swift 中，可以使用如下 structure 進行重構，僅需呼叫 `Security` 底層功能：
```swift
import Foundation
import Security

public class YLKeychain {
    public static func password(forService service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    // ... 其他 setPassword 與 accounts 讀取實作
}
```

### 2. 字元編碼對照表 (Encoding Tables)
[encoding.m](file:///Users/ericsk/Projects/Nally-Unofficial/Code/encoding.m) 包含大量靜態陣列，這在 Swift 中若宣告為大陣列會嚴重拖累編譯器效能。
**最佳解決方案**：
將陣列寫入二進位檔，例如 `b2u.bin`（大小為 $32768 \times 2 = 64\text{ KB}$）。在 Swift 中用 `Data(contentsOf:)` 載入：
```swift
let url = Bundle.main.url(forResource: "b2u", withExtension: "bin")!
let data = try Data(contentsOf: url)
let b2uTable = data.withUnsafeBytes { Array($0.bindMemory(to: UInt16.self)) }
```
如此一來，查詢 `lookupBig5(index)` 僅需 `b2uTable[Int(index)]`，速度極快且編譯極速。

### 3. 核心資料結構
原來的 `cell` 及 `attribute` 為 C 的 bitfield 聯集，導致 Swift 需透過屬性包裝。移除 C 標頭檔後，可以直接在 [CommonType.swift](file:///Users/ericsk/Projects/Nally-Unofficial/Code/CommonType.swift) 內將 `TerminalAttribute` 重構為：
```swift
public struct TerminalAttribute {
    public var fgColor: UInt8 // 4 bits
    public var bgColor: UInt8 // 4 bits
    public var bold: Bool
    public var underline: Bool
    public var blink: Bool
    public var reverse: Bool
    public var doubleByte: UInt8
    public var url: Bool
}
```
不再需要與 `rawValue` / `attribute` 橋接，大幅提升程式碼可讀性與效能。
