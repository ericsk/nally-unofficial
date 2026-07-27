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
        
        let nonImageURL = URL(string: "https://google.com/search")!
        #expect(!manager.isImageURL(nonImageURL))
    }
    
    @Test("YLImagePreviewer Initialization & Reset Zoom")
    @MainActor
    func testPreviewerZoomReset() {
        let url = URL(string: "https://example.com/test.png")!
        let previewer = YLImagePreviewer(url: url)
        
        previewer.zoomScale = 2.5
        previewer.panOffset = CGSize(width: 50, height: 50)
        
        previewer.resetZoom()
        #expect(previewer.zoomScale == 1.0)
        #expect(previewer.panOffset == .zero)
    }
}
