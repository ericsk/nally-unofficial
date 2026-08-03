//
//  YLImagePreviewer.swift
//  Nally
//
//  Created by Antigravity on 2026/7/26.
//

import Cocoa
import SwiftUI
import ImageIO
import UniformTypeIdentifiers

@MainActor
@objc(YLImagePreviewer)
public class YLImagePreviewer: NSObject, ObservableObject, URLSessionDownloadDelegate {
    private var downloadTask: URLSessionDownloadTask?
    private var downloadedData: Data?
    public private(set) var originalUrl: URL
    public private(set) var filename: String = "image"
    private var tempFileURL: URL?
    
    @Published public var downloadProgress: Double = 0.0
    @Published public var isDownloading: Bool = true
    @Published public var image: NSImage? = nil
    @Published public var title: String = "Loading..."
    @Published public var imageSizeText: String = ""
    @Published public var formatName: String = ""
    @Published public var zoomScale: CGFloat = 1.0
    @Published public var panOffset: CGSize = .zero
    
    private var window: NSPanel?
    private var popover: NSPopover?
    private var exifData: [String: Any]?
    private var tiffData: [String: Any]?
    
    @objc(initWithURL:)
    public init(url: URL) {
        self.originalUrl = url
        self.filename = url.lastPathComponent.isEmpty ? "image" : url.lastPathComponent
        super.init()
        
        let pathExt = url.pathExtension.lowercased()
        if !pathExt.isEmpty {
            self.formatName = pathExt.uppercased()
        }
        
        // Start downloading using URLSession
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue.main)
        let task = session.downloadTask(with: url)
        self.downloadTask = task
        task.resume()
        
        let stylePreference = UserDefaults.standard.string(forKey: "ImagePreviewStyle") ?? "popover"
        if stylePreference == "window" {
            showLoadingWindow()
        }
    }
    
    public func showPopover(relativeTo positioningRect: NSRect, of positioningView: NSView, preferredEdge: NSRectEdge = .minY) {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 680, height: 500)
        
        let hostingView = NSHostingView(rootView: ImagePreviewerView(previewer: self))
        popover.contentViewController = NSViewController()
        popover.contentViewController?.view = hostingView
        
        self.popover = popover
        popover.show(relativeTo: positioningRect, of: positioningView, preferredEdge: preferredEdge)
    }
    
    public func showLoadingWindow() {
        if window != nil { return }
        let style: NSWindow.StyleMask = [.titled, .closable, .utilityWindow, .hudWindow]
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 120),
            styleMask: style,
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.isOpaque = true
        panel.center()
        panel.title = "Loading \(filename)..."
        
        let hostingView = NSHostingView(rootView: ImagePreviewerView(previewer: self))
        panel.contentView = hostingView
        
        self.window = panel
        panel.makeKeyAndOrderFront(nil)
    }
    
    public func closePreview() {
        popover?.performClose(nil)
        popover = nil
        window?.close()
        window = nil
        downloadTask?.cancel()
        
        if let temp = tempFileURL {
            try? FileManager.default.removeItem(at: temp)
            tempFileURL = nil
        }
    }
    
    public func copyImageToClipboard() {
        guard let data = downloadedData, let img = NSImage(data: data) else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([img])
    }
    
    public func saveImage() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = filename
        
        let parentWindow = window ?? NSApp.mainWindow
        let completion: (NSApplication.ModalResponse) -> Void = { response in
            if response == .OK, let saveUrl = panel.url, let data = self.downloadedData {
                do {
                    try data.write(to: saveUrl, options: .atomic)
                    NSLog("[Nally] Image saved successfully to \(saveUrl.path)")
                } catch {
                    NSLog("[Nally] Failed to save image: \(error.localizedDescription)")
                }
            }
        }
        
        if let parent = parentWindow {
            panel.beginSheetModal(for: parent, completionHandler: completion)
        } else {
            panel.begin(completionHandler: completion)
        }
    }
    
    @MainActor public func showQuickLook() {
        guard let data = downloadedData else { return }
        if tempFileURL == nil {
            let tempDir = FileManager.default.temporaryDirectory
            let ext = originalUrl.pathExtension.isEmpty ? "png" : originalUrl.pathExtension
            let fileURL = tempDir.appendingPathComponent("nally_preview_\(UUID().uuidString).\(ext)")
            do {
                try data.write(to: fileURL)
                self.tempFileURL = fileURL
            } catch {
                return
            }
        }
        if let temp = tempFileURL {
            YLQuickLookHelper.shared.preview(fileURL: temp)
        }
    }
    
    public func showExifData() {
        guard let exif = exifData else { return }
        
        if let controller = NallyAppDelegate.shared?.controller,
           let exifController = controller.exifController() {
            exifController.exifData = exif as NSDictionary
            
            let make = tiffData?[kCGImagePropertyTIFFMake as String] as? String ?? ""
            let model = tiffData?[kCGImagePropertyTIFFModel as String] as? String ?? ""
            let makeAndModel = "\(make) \(model)".trimmingCharacters(in: .whitespacesAndNewlines)
            exifController.modelName = makeAndModel.isEmpty ? "Camera Info" : makeAndModel
            
            exifController.showExifPanel()
        }
    }
    
    public func resetZoom() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            zoomScale = 1.0
            panOffset = .zero
        }
    }
    
    // MARK: - URLSessionDownloadDelegate
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > 0 {
            self.downloadProgress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            self.title = "Loading \(filename)... (\(Int(downloadProgress * 100))%)"
        } else {
            self.downloadProgress = 0.0
            self.title = "Loading..."
        }
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            let data = try Data(contentsOf: location)
            self.downloadedData = data
            
            if let httpResponse = downloadTask.response as? HTTPURLResponse {
                if let name = httpResponse.suggestedFilename {
                    self.filename = name
                }
            }
            
            // Extract image properties (EXIF / TIFF)
            if let source = CGImageSourceCreateWithData(data as CFData, nil) {
                if let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] {
                    self.exifData = properties[kCGImagePropertyExifDictionary as String] as? [String: Any]
                    self.tiffData = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
                    
                    if let width = properties[kCGImagePropertyPixelWidth as String] as? Int,
                       let height = properties[kCGImagePropertyPixelHeight as String] as? Int {
                        self.imageSizeText = "\(width) × \(height)"
                    }
                }
                
                if let type = CGImageSourceGetType(source) as String? {
                    if let utType = UTType(type) {
                        self.formatName = utType.localizedDescription ?? utType.preferredFilenameExtension?.uppercased() ?? "IMAGE"
                    }
                }
            }
            
            if let downloadedImage = NSImage(data: data) {
                let imageRep = downloadedImage.representations.first
                let pixelsWide = CGFloat(imageRep?.pixelsWide ?? 0)
                let pixelsHigh = CGFloat(imageRep?.pixelsHigh ?? 0)
                
                if imageSizeText.isEmpty {
                    let w = Int(pixelsWide > 0 ? pixelsWide : downloadedImage.size.width)
                    let h = Int(pixelsHigh > 0 ? pixelsHigh : downloadedImage.size.height)
                    self.imageSizeText = "\(w) × \(h)"
                }
                
                var displaySize = pixelsWide > 0 && pixelsHigh > 0 ? NSSize(width: pixelsWide, height: pixelsHigh) : downloadedImage.size
                
                if let screen = NSScreen.main {
                    let visibleSize = screen.visibleFrame.size
                    let maxWidth = visibleSize.width - 80
                    let maxHeight = visibleSize.height - 80
                    
                    let aspect = displaySize.height / (displaySize.width > 0 ? displaySize.width : 1)
                    if displaySize.width > maxWidth {
                        displaySize.width = maxWidth
                        displaySize.height = maxWidth * aspect
                    }
                    if displaySize.height > maxHeight {
                        displaySize.height = maxHeight
                        displaySize.width = maxHeight / (aspect > 0 ? aspect : 1)
                    }
                }
                
                downloadedImage.size = displaySize
                
                self.isDownloading = false
                self.image = downloadedImage
                
                if let pop = self.popover {
                    let targetW = min(880, max(600, displaySize.width + 32))
                    let targetH = min(660, max(440, displaySize.height + 64))
                    pop.contentSize = NSSize(width: targetW, height: targetH)
                }
                
                if let panel = self.window {
                    panel.title = self.filename
                    
                    let frameSize = panel.frame.size
                    let viewSize = panel.contentView?.frame.size ?? NSZeroSize
                    
                    let newWidth = max(640, displaySize.width + (frameSize.width - viewSize.width))
                    let newHeight = max(480, displaySize.height + (frameSize.height - viewSize.height))
                    
                    if let screen = NSScreen.main {
                        let visibleFrame = screen.visibleFrame
                        let originX = visibleFrame.origin.x + (visibleFrame.size.width - newWidth) / 2
                        let originY = visibleFrame.origin.y + (visibleFrame.size.height - newHeight) / 1.618
                        
                        panel.setFrame(NSRect(x: originX, y: originY, width: newWidth, height: newHeight), display: true, animate: true)
                    }
                }
            } else {
                fallbackToBrowser()
            }
        } catch {
            NSLog("[Nally] Error loading downloaded data: \(error.localizedDescription)")
            fallbackToBrowser()
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            NSLog("[Nally] Download failed: \(error.localizedDescription)")
            fallbackToBrowser()
        }
    }
    
    private func fallbackToBrowser() {
        NSWorkspace.shared.open(originalUrl)
        closePreview()
    }
}
