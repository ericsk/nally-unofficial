import Cocoa
import SwiftUI

@objc(YLExifController)
@Observable
public class YLExifController: NSObject {
    @objc public var exifData: NSDictionary?
    @objc public var modelName: String?
    
    public var isoSpeed: String?
    public var exposureTime: String?
    public var fNumber: String?
    public var focalLength: String?
    public var date: String?
    
    private var windowController: NSWindowController?
    
    @objc public func showExifPanel() {
        if let exif = exifData {
            if let isoArray = exif["ISOSpeedRatings"] as? [NSNumber], let iso = isoArray.first {
                self.isoSpeed = iso.stringValue
            } else if let iso = exif["ISOSpeedRatings"] as? NSNumber {
                self.isoSpeed = iso.stringValue
            } else {
                self.isoSpeed = getString(for: "ISOSpeedRatings")
            }
            
            if let eTime = exif["ExposureTime"] as? NSNumber {
                let val = eTime.doubleValue
                if val < 1 && val != 0 {
                    self.exposureTime = String(format: "1/%g", 1.0 / val)
                } else {
                    self.exposureTime = eTime.stringValue
                }
            } else {
                self.exposureTime = nil
            }
            
            self.fNumber = getString(for: "FNumber")
            self.focalLength = getString(for: "FocalLength")
            self.date = getString(for: "DateTimeOriginal")
        } else {
            self.isoSpeed = nil
            self.exposureTime = nil
            self.fNumber = nil
            self.focalLength = nil
            self.date = nil
        }
        
        if windowController == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 320, height: 220),
                styleMask: [.titled, .closable, .utilityWindow, .hudWindow],
                backing: .buffered,
                defer: false
            )
            panel.title = "EXIF Data"
            panel.center()
            panel.isFloatingPanel = true
            panel.hidesOnDeactivate = false
            
            let hostView = NSHostingView(rootView: ExifView(controller: self))
            panel.contentView = hostView
            
            windowController = NSWindowController(window: panel)
        }
        
        windowController?.window?.makeKeyAndOrderFront(nil)
    }
    
    private func getString(for key: String) -> String? {
        guard let exif = exifData else { return nil }
        if let val = exif[key] {
            if let num = val as? NSNumber {
                return num.stringValue
            }
            return String(describing: val)
        }
        return nil
    }
}

struct ExifView: View {
    let controller: YLExifController
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("EXIF Metadata")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.bottom, 2)
            
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                GridRow {
                    Text("Model:").bold().foregroundColor(.secondary)
                    Text(controller.modelName ?? "Unknown").foregroundColor(.white)
                }
                GridRow {
                    Text("Exposure:").bold().foregroundColor(.secondary)
                    Text(controller.exposureTime ?? "Unknown").foregroundColor(.white)
                }
                GridRow {
                    Text("ISO:").bold().foregroundColor(.secondary)
                    Text(controller.isoSpeed ?? "Unknown").foregroundColor(.white)
                }
                GridRow {
                    Text("F-Number:").bold().foregroundColor(.secondary)
                    Text(controller.fNumber ?? "Unknown").foregroundColor(.white)
                }
                GridRow {
                    Text("Focal Length:").bold().foregroundColor(.secondary)
                    Text(controller.focalLength ?? "Unknown").foregroundColor(.white)
                }
                GridRow {
                    Text("Date:").bold().foregroundColor(.secondary)
                    Text(controller.date ?? "Unknown").foregroundColor(.white)
                }
            }
            .font(.system(.body, design: .monospaced))
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
