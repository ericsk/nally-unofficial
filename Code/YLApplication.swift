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
        return (try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: theData))
    }
}

private let gLeftString = String(UnicodeScalar(NSLeftArrowFunctionKey)!)
private let gRightString = String(UnicodeScalar(NSRightArrowFunctionKey)!)

@objc(YLApplication)
public class YLApplication: NSApplication {
    @objc public dynamic weak var _controller: YLController?

    public override init() {
        super.init()
        NSColorPanel.shared.showsAlpha = true
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        NSColorPanel.shared.showsAlpha = true
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
        }
        
        super.sendEvent(event)
    }
}
