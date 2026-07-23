import Testing
import Foundation
import SwiftData
@testable import Nally

@Suite("SwiftData Site Management Tests")
struct SiteDataTests {
    
    @Test("YLSite Model Creation and Defaults Initialization")
    func testSiteInitialization() {
        let site = YLSite(name: "PTT 批踢踢實業坊", address: "ptt.cc")
        #expect(site.name == "PTT 批踢踢實業坊")
        #expect(site.address == "ptt.cc")
        #expect(site.encoding == YLEncoding.YLBig5Encoding)
        #expect(site.ansiColorKey == YLANSIColorKey.YLCtrlUANSIColorKey)
        #expect(site.detectDoubleByte == true)
        #expect(site.account == "")
        #expect(site.password == "")
    }
    
    @Test("SwiftData ModelContainer Insertion, Querying, and Deletion")
    @MainActor
    func testModelContainerCRUD() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: YLSite.self, configurations: config)
        let context = container.mainContext
        
        let ptt = YLSite(name: "PTT", address: "ptt.cc")
        let bs2 = YLSite(name: "BS2", address: "bs2.to")
        
        context.insert(ptt)
        context.insert(bs2)
        try context.save()
        
        let descriptor = FetchDescriptor<YLSite>(sortBy: [SortDescriptor(\.name)])
        let sites = try context.fetch(descriptor)
        
        #expect(sites.count == 2)
        #expect(sites.map(\.name).contains("PTT"))
        #expect(sites.map(\.name).contains("BS2"))
        
        context.delete(bs2)
        try context.save()
        
        let updatedSites = try context.fetch(descriptor)
        #expect(updatedSites.count == 1)
        #expect(updatedSites.first?.name == "PTT")
    }
    
    @Test("YLSite Copy Method Creates Distinct Instance")
    func testSiteCopy() {
        let original = YLSite(name: "Test Site", address: "test.org", account: "user123")
        let copy = original.copySite()
        
        #expect(copy.name == original.name)
        #expect(copy.address == original.address)
        #expect(copy.account == original.account)
        #expect(copy.id != original.id)
        
        copy.name = "Modified Name"
        #expect(original.name == "Test Site")
    }
}
