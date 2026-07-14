//
//  YLPluginLoader.swift
//  Nally
//
//  Created by Antigravity on 2026/7/14.
//  Copyright 2026 Jjgod Jiang. All rights reserved.
//

import Foundation

@objc(YLPluginLoader)
public class YLPluginLoader: NSObject {
    @objc public var bundleInstanceList = NSMutableArray()
    
    @objc override public init() {
        super.init()
        Thread.detachNewThreadSelector(#selector(startSearch), toTarget: self, with: nil)
    }
    
    @objc public func startSearch() {
        autoreleasepool {
            var bundleSearchPaths = [String]()
            
            // our built bundles are found inside the app's "PlugIns" folder
            if let builtInPlugInsPath = Bundle.main.builtInPlugInsPath {
                bundleSearchPaths.append(builtInPlugInsPath)
            }
            
            // Search other locations for bundles
            // (i.e. $(HOME)/Library/Application Support/Nally/PlugIns)
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
                                self.bundleInstanceList.add(bundleInstance)
                            }
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
