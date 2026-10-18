//
//  YLPluginLoader.swift
//  Nally
//
//  Created by Antigravity on 2026/7/14.
//  Copyright 2026 Jjgod Jiang. All rights reserved.
//

import Foundation

@MainActor
@objc(YLPluginLoader)
public class YLPluginLoader: NSObject {
    public var bundleInstanceList: [AnyObject] = []
    
    @objc override public init() {
        super.init()
        Task { @MainActor [weak self] in
            self?.startSearch()
        }
    }
    
    @objc public func startSearch() {
        var bundleSearchPaths = [String]()
        
        if let builtInPlugInsPath = Bundle.main.builtInPlugInsPath {
            bundleSearchPaths.append(builtInPlugInsPath)
        }
        
        let librarySearchPaths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        for url in librarySearchPaths {
            let processName = ProcessInfo.processInfo.processName
            let pluginPath = url.appendingPathComponent("\(processName)/PlugIns").path
            bundleSearchPaths.append(pluginPath)
        }
        
        let fileManager = FileManager.default
        for currPath in bundleSearchPaths {
            guard fileManager.fileExists(atPath: currPath) else { continue }
            
            if let bundleEnum = fileManager.enumerator(atPath: currPath) {
                while let currBundlePath = bundleEnum.nextObject() as? String {
                    if currBundlePath.hasSuffix(".bundle") {
                        let fullPath = (currPath as NSString).appendingPathComponent(currBundlePath)
                        if let bundleInstance = self.loadBundle(atPath: fullPath) {
                            self.bundleInstanceList.append(bundleInstance)
                        }
                    }
                }
            }
        }
    }
    
    @objc public func loadBundle(atPath path: String) -> AnyObject? {
        guard let currBundle = Bundle(path: path) else { return nil }
        guard let bundleId = currBundle.bundleIdentifier else { return nil }
        
        let prefix = "org.yllan.Nally.Plugin"
        
        if bundleId.count >= prefix.count {
            let bundleIdPrefix = bundleId[bundleId.startIndex..<bundleId.index(bundleId.startIndex, offsetBy: prefix.count)]
            if bundleIdPrefix == prefix {
                // load and startup our bundle
                if let currPrincipalClass = currBundle.principalClass as? NSObject.Type {
                    let currInstance = currPrincipalClass.init()
                    return currInstance
                }
            }
        }
        
        return nil
    }
    
    @objc public func feedData(_ data: Data) {
        // Empty implementation matching original
    }
}
