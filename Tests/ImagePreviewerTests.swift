//
//  ImagePreviewerTests.swift
//  Nally
//
//  Created by Antigravity on 2026/7/26.
//

import Testing
import Foundation
import AppKit
@testable import Nally

@Suite("Modern Image Previewer & Format Detection Tests")
@MainActor
struct ImagePreviewerTests {
    
    @Test("Image Extension Recognition for Modern Formats")
    @MainActor
    func testImageURLRecognition() {
        let manager = YLContextualMenuManager.sharedInstance
        
        let webpURL = URL(string: "https://example.com/photo.webp")!
        #expect(manager.isImageURL(webpURL))
        
        let avifURL = URL(string: "https://example.com/picture.avif")!
        #expect(manager.isImageURL(avifURL))
        
        let heicURL = URL(string: "https://example.com/shot.heic")!
        #expect(manager.isImageURL(heicURL))
        
        let pngURL = URL(string: "https://example.com/banner.PNG")!
        #expect(manager.isImageURL(pngURL))
    }
    
    @Test("Popular Image Host Domain Recognition")
    @MainActor
    func testImageHostRecognition() {
        let manager = YLContextualMenuManager.sharedInstance
        
        let imgurURL = URL(string: "https://imgur.com/aB1c2d3")!
        #expect(manager.isImageURL(imgurURL))
        
        let postimgURL = URL(string: "https://postimg.cc/xyz123")!
        #expect(manager.isImageURL(postimgURL))
        
        let meeeURL = URL(string: "https://meee.com.tw/abcXYZ")!
        #expect(manager.isImageURL(meeeURL))
        
        let nonImageURL = URL(string: "https://google.com/search")!
        #expect(!manager.isImageURL(nonImageURL))
    }
    
    @Test("YLImagePreviewer Initialization, Reset Zoom, and Resource Cleanup")
    @MainActor
    func testPreviewerZoomReset() {
        let url = URL(string: "https://example.com/test.png")!
        let previewer = YLImagePreviewer(url: url, allowBrowserFallback: false, startDownload: false)
        
        previewer.zoomScale = 2.5
        previewer.panOffset = CGSize(width: 50, height: 50)
        
        previewer.resetZoom()
        #expect(previewer.zoomScale == 1.0)
        #expect(previewer.panOffset == .zero)
        
        previewer.closePreview()
        #expect(previewer.isPresented == false)
    }
    
    @Test("Cmd + Hover URL Preview Scheduling and Cancellation")
    @MainActor
    func testCmdHoverPreviewEvaluation() {
        let config = YLLGlobalConfig.sharedInstance()
        let prevPrefer = config.shouldPreferImagePreviewer
        let prevHover = UserDefaults.standard.object(forKey: "EnableCmdHoverPreview")
        defer {
            config.shouldPreferImagePreviewer = prevPrefer
            if let prevHover = prevHover {
                UserDefaults.standard.set(prevHover, forKey: "EnableCmdHoverPreview")
            } else {
                UserDefaults.standard.removeObject(forKey: "EnableCmdHoverPreview")
            }
        }
        
        config.shouldPreferImagePreviewer = true
        UserDefaults.standard.set(true, forKey: "EnableCmdHoverPreview")
        
        let view = YLView(frame: NSRect(x: 0, y: 0, width: 960, height: 576))
        view.configure()
        let conn = YLConnection()
        let term = YLTerminal()
        conn.terminal = term
        let tabItem = NSTabViewItem(identifier: conn)
        view.addTabViewItem(tabItem)
        view.selectTabViewItem(tabItem)
        
        // Feed an HTTPS image URL at row 0, col 0
        term.feedData(Data("https://i.imgur.com/test123.png".utf8), connection: conn)
        
        // Row 0 is at the top of the non-flipped YLView (y near height - fontHeight/2)
        let hoverPoint = NSPoint(x: view.fontWidth * 2, y: CGFloat(config.row - 1) * view.fontHeight + 4)
        
        // Hovering WITH Command schedules preview task
        view.evaluateCmdHoverPreview(at: hoverPoint, modifierFlags: [.command])
        #expect(view.hoveredPreviewURL == "https://i.imgur.com/test123.png")
        #expect(view.hoverPreviewTask != nil)
        
        // Releasing Command cancels pending preview task
        view.evaluateCmdHoverPreview(at: hoverPoint, modifierFlags: [])
        #expect(view.hoveredPreviewURL == nil)
        #expect(view.hoverPreviewTask == nil)
        
        // Disabling EnableCmdHoverPreview prevents scheduling
        UserDefaults.standard.set(false, forKey: "EnableCmdHoverPreview")
        view.evaluateCmdHoverPreview(at: hoverPoint, modifierFlags: [.command])
        #expect(view.hoverPreviewTask == nil)
    }
}
