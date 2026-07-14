import Cocoa
import SwiftUI
import ImageIO

@objc(YLImagePreviewer)
public class YLImagePreviewer: NSObject, ObservableObject, URLSessionDownloadDelegate {
    private var downloadTask: URLSessionDownloadTask?
    private var downloadedData: Data?
    private var originalUrl: URL
    private var filename: String = "image"
    
    @Published public var downloadProgress: Double = 0.0
    @Published public var isDownloading: Bool = true
    @Published public var image: NSImage? = nil
    @Published public var title: String = "Loading..."
    
    private var window: NSPanel?
    private var exifData: [String: Any]?
    private var tiffData: [String: Any]?
    
    @objc(initWithURL:)
    public init(url: URL) {
        self.originalUrl = url
        self.filename = url.lastPathComponent
        super.init()
        
        // Start downloading using URLSession
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue.main)
        let task = session.downloadTask(with: url)
        self.downloadTask = task
        task.resume()
        
        showLoadingWindow()
    }
    
    private func showLoadingWindow() {
        let style: NSWindow.StyleMask = [.titled, .closable, .utilityWindow, .hudWindow]
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 80),
            styleMask: style,
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = false
        panel.isOpaque = true
        panel.center()
        panel.title = "Loading \(filename)..."
        
        let hostingView = NSHostingView(rootView: ImagePreviewerView(previewer: self))
        panel.contentView = hostingView
        
        self.window = panel
        panel.makeKeyAndOrderFront(nil)
    }
    
    public func closeWindow() {
        window?.close()
        window = nil
        downloadTask?.cancel()
    }
    
    public func saveImage() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = filename
        
        panel.beginSheetModal(for: window ?? NSApp.mainWindow!) { response in
            if response == .OK, let saveUrl = panel.url, let data = self.downloadedData {
                do {
                    try data.write(to: saveUrl, options: .atomic)
                    NSLog("[Nally] Image saved successfully to \(saveUrl.path)")
                } catch {
                    NSLog("[Nally] Failed to save image: \(error.localizedDescription)")
                }
            }
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
            exifController.modelName = makeAndModel.isEmpty ? "Unknown Camera" : makeAndModel
            
            exifController.showExifPanel()
        }
    }
    
    // MARK: - URLSessionDownloadDelegate
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > 0 {
            self.downloadProgress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            self.title = "Loading \(filename)..."
        } else {
            self.downloadProgress = 0.0
            self.title = "Loading..."
        }
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            let data = try Data(contentsOf: location)
            self.downloadedData = data
            
            // Extract suggested filename from response if possible
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
                }
            }
            
            if let downloadedImage = NSImage(data: data) {
                // Resize window and display image
                let imageRep = downloadedImage.representations.first
                let pixelsWide = CGFloat(imageRep?.pixelsWide ?? 0)
                let pixelsHigh = CGFloat(imageRep?.pixelsHigh ?? 0)
                
                var displaySize = pixelsWide > 0 && pixelsHigh > 0 ? NSSize(width: pixelsWide, height: pixelsHigh) : downloadedImage.size
                
                if let screen = NSScreen.main {
                    let visibleSize = screen.visibleFrame.size
                    let maxWidth = visibleSize.width - 40
                    let maxHeight = visibleSize.height - 40
                    
                    let aspect = displaySize.height / displaySize.width
                    if displaySize.width > maxWidth {
                        displaySize.width = maxWidth
                        displaySize.height = maxWidth * aspect
                    }
                    if displaySize.height > maxHeight {
                        displaySize.height = maxHeight
                        displaySize.width = maxHeight / aspect
                    }
                }
                
                downloadedImage.size = displaySize
                
                self.isDownloading = false
                self.image = downloadedImage
                
                // Update window title and size
                if let panel = self.window {
                    panel.title = self.filename
                    
                    let frameSize = panel.frame.size
                    let viewSize = panel.contentView?.frame.size ?? NSZeroSize
                    
                    let newWidth = displaySize.width + (frameSize.width - viewSize.width)
                    let newHeight = displaySize.height + (frameSize.height - viewSize.height)
                    
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
        closeWindow()
    }
}
