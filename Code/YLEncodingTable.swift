import Foundation

@objc(YLEncodingTable)
@objcMembers
public class YLEncodingTable: NSObject {
    private struct Tables: Sendable {
        let g2u: [UInt16]
        let b2u: [UInt16]
        let u2b: [UInt16]
        let u2g: [UInt16]
    }
    
    private static let tables: Tables = {
        var g2uTable = [UInt16](repeating: 0, count: 32768)
        var b2uTable = [UInt16](repeating: 0, count: 32768)
        var u2bTable = [UInt16](repeating: 0, count: 65536)
        var u2gTable = [UInt16](repeating: 0, count: 65536)
        
        loadTable(name: "g2u", into: &g2uTable)
        loadTable(name: "b2u", into: &b2uTable)
        
        // Build reverse tables
        for i in 0..<32768 {
            let u2bIdx = Int(b2uTable[i])
            u2bTable[u2bIdx] = UInt16(i + 0x8000)
            
            let u2gIdx = Int(g2uTable[i])
            u2gTable[u2gIdx] = UInt16(i + 0x8000)
        }
        
        return Tables(g2u: g2uTable, b2u: b2uTable, u2b: u2bTable, u2g: u2gTable)
    }()
    
    private static func loadTable(name: String, into table: inout [UInt16]) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "bin") else {
            // If running inside unit tests, Bundle.main might not contain the resource, so try bundle for self class
            let testBundle = Bundle(for: YLEncodingTable.self)
            if let testUrl = testBundle.url(forResource: name, withExtension: "bin") {
                loadTableAtUrl(testUrl, into: &table)
            } else {
                NSLog("Failed to locate \(name).bin in any bundle")
            }
            return
        }
        loadTableAtUrl(url, into: &table)
    }
    
    private static func loadTableAtUrl(_ url: URL, into table: inout [UInt16]) {
        do {
            let data = try Data(contentsOf: url)
            data.withUnsafeBytes { buffer in
                if let baseAddress = buffer.baseAddress {
                    let count = min(table.count, buffer.count / 2)
                    let ptr = baseAddress.bindMemory(to: UInt16.self, capacity: count)
                    for i in 0..<count {
                        table[i] = ptr[i]
                    }
                }
            }
        } catch {
            NSLog("Failed to load \(url): \(error)")
        }
    }
    
    public static func ensureLoaded() {
        _ = tables
    }
    
    public static func lookupBig5(_ index: UInt16) -> UInt16 {
        let idx = Int(index)
        let b2u = tables.b2u
        return idx < b2u.count ? b2u[idx] : 0
    }
    
    public static func lookupGBK(_ index: UInt16) -> UInt16 {
        let idx = Int(index)
        let g2u = tables.g2u
        return idx < g2u.count ? g2u[idx] : 0
    }
    
    public static func lookupU2B(_ val: UInt16) -> UInt16 {
        let idx = Int(val)
        let u2b = tables.u2b
        return idx < u2b.count ? u2b[idx] : 0
    }
    
    public static func lookupU2G(_ val: UInt16) -> UInt16 {
        let idx = Int(val)
        let u2g = tables.u2g
        return idx < u2g.count ? u2g[idx] : 0
    }
    
    public static func initTable() {
        ensureLoaded()
    }
}

// Global functions for Swift code
public func lookupBig5(_ index: UInt16) -> UInt16 {
    return YLEncodingTable.lookupBig5(index)
}

public func lookupGBK(_ index: UInt16) -> UInt16 {
    return YLEncodingTable.lookupGBK(index)
}

public func lookupU2B(_ val: UInt16) -> UInt16 {
    return YLEncodingTable.lookupU2B(val)
}

public func lookupU2G(_ val: UInt16) -> UInt16 {
    return YLEncodingTable.lookupU2G(val)
}
