import Cocoa

extension UserDefaults {
    @objc public func setMyColor(_ aColor: NSColor?, forKey aKey: String) {
        guard let aColor = aColor else {
            self.removeObject(forKey: aKey)
            return
        }
        do {
            let theData = try NSKeyedArchiver.archivedData(withRootObject: aColor, requiringSecureCoding: false)
            self.set(theData, forKey: aKey)
        } catch {
            NSLog("[Nally] Failed to archive color: \(error)")
        }
    }

    @objc public func myColor(forKey aKey: String) -> NSColor? {
        guard let theData = self.data(forKey: aKey) else { return nil }
        do {
            if let color = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: theData) {
                return color
            }
        } catch {
            // Fallback to legacy unarchiver
        }
        return NSUnarchiver.unarchiveObject(with: theData) as? NSColor
    }
}

private let gLeftString = String(UnicodeScalar(NSLeftArrowFunctionKey)!)
private let gRightString = String(UnicodeScalar(NSRightArrowFunctionKey)!)

@objc(YLApplication)
public class YLApplication: NSApplication {
    @IBOutlet @objc public dynamic weak var _controller: YLController?

    public override init() {
        super.init()
        NSColor.ignoresAlpha = false
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        NSColor.ignoresAlpha = false
    }

    public override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            
            // Cmd + Shift + Right Arrow
            if flags == [.command, .shift] && event.charactersIgnoringModifiers == gRightString {
                if let modifiedEvent = NSEvent.keyEvent(
                    with: event.type,
                    location: event.locationInWindow,
                    modifierFlags: event.modifierFlags.subtracting(.shift),
                    timestamp: event.timestamp,
                    windowNumber: event.windowNumber,
                    context: nil,
                    characters: gRightString,
                    charactersIgnoringModifiers: gRightString,
                    isARepeat: event.isARepeat,
                    keyCode: event.keyCode
                ) {
                    super.sendEvent(modifiedEvent)
                    return
                }
            }
            
            // Cmd + Shift + Left Arrow
            if flags == [.command, .shift] && event.charactersIgnoringModifiers == gLeftString {
                if let modifiedEvent = NSEvent.keyEvent(
                    with: event.type,
                    location: event.locationInWindow,
                    modifierFlags: event.modifierFlags.subtracting(.shift),
                    timestamp: event.timestamp,
                    windowNumber: event.windowNumber,
                    context: nil,
                    characters: gLeftString,
                    charactersIgnoringModifiers: gLeftString,
                    isARepeat: event.isARepeat,
                    keyCode: event.keyCode
                ) {
                    super.sendEvent(modifiedEvent)
                    return
                }
            }
            
            // Cmd + Number (1-9) -> Select Tab
            if flags == .command {
                if let chars = event.charactersIgnoringModifiers, let val = Int(chars), val > 0 && val < 10 {
                    NSLog("[YLApplication] Cmd + \(val) detected. Selector targeting: \(_controller != nil ? "valid" : "nil")")
                    _controller?.selectTabNumber(Int32(val))
                    return
                }
            }
            
            // Cmd + N -> Edit Sites
            if flags == .command {
                if event.characters == "n" {
                    _controller?.editSites(self)
                    return
                }
            }
        }
        
        super.sendEvent(event)
    }
}
