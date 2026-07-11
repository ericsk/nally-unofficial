import Foundation
import Observation

@Observable
@objc(SitesManager)
@objcMembers
public class SitesManager: NSObject {
    public var sites: [YLSite] = []
    private weak var controller: YLController?
    
    public init(controller: YLController) {
        self.controller = controller
        super.init()
        reload()
    }
    
    public func reload() {
        guard let controller = controller else { return }
        self.sites = (controller.sites() as? [YLSite]) ?? []
    }
    
    public func addSite() {
        guard let controller = controller else { return }
        let newSite = YLSite()
        newSite.name = "New Site"
        newSite.address = "bbs.example.com"
        controller.insert(newSite, inSitesAt: controller.countOfSites())
        reload()
    }
    
    public func removeSite(at index: Int) {
        guard let controller = controller else { return }
        controller.removeObjectFromSites(at: UInt32(index))
        reload()
    }
    
    public func save() {
        guard let controller = controller else { return }
        controller.saveSites()
    }
}
