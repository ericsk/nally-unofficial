//
//  YLQuickLookHelper.swift
//  Nally
//
//  Created by Antigravity on 2026/7/26.
//

import Cocoa
import QuickLookUI

public class YLQuickLookHelper: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    @MainActor public static let shared = YLQuickLookHelper()
    
    private var previewURL: URL?
    
    @MainActor public func preview(fileURL: URL) {
        self.previewURL = fileURL
        if let panel = QLPreviewPanel.shared() {
            panel.dataSource = self
            panel.delegate = self
            panel.makeKeyAndOrderFront(nil)
            panel.reloadData()
        }
    }
    
    // MARK: - QLPreviewPanelDataSource
    
    public func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return previewURL != nil ? 1 : 0
    }
    
    public func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        return previewURL as QLPreviewItem?
    }
    
    // MARK: - QLPreviewPanelDelegate
    
    public func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        if event.type == .keyDown && event.keyCode == 53 { // ESC
            panel.orderOut(nil)
            return true
        }
        return false
    }
}
