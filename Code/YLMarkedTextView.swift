import Cocoa
import CoreText

@objc(YLMarkedTextView)
public class YLMarkedTextView: NSView {
    private var _string: NSAttributedString?
    private var _markedRange = NSRange(location: 0, length: 0)
    private var _selectedRange = NSRange(location: 0, length: 0)
    private var _defaultFont = NSFont.systemFont(ofSize: 20)
    private var _lineHeight: CGFloat = 24.0
    private var _destination = NSPoint.zero
    
    @objc public var string: NSAttributedString? {
        get { return _string }
        set {
            guard let val = newValue else {
                _string = nil
                setNeedsDisplay(bounds)
                return
            }
            
            let asStr = NSMutableAttributedString(attributedString: val)
            asStr.addAttribute(.font, value: _defaultFont, range: NSRange(location: 0, length: val.length))
            asStr.addAttribute(.foregroundColor, value: NSColor.white, range: NSRange(location: 0, length: val.length))
            _string = asStr
            setNeedsDisplay(bounds)
            
            let line = CTLineCreateWithAttributedString(asStr)
            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            var leading: CGFloat = 0
            let w = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
            
            var size = frame.size
            size.width = CGFloat(w) + 12
            size.height = _lineHeight + 8 + 5
            setFrameSize(size)
        }
    }
    
    @objc public var markedRange: NSRange {
        get { return _markedRange }
        set {
            _markedRange = newValue
            setNeedsDisplay(bounds)
        }
    }
    
    @objc public var selectedRange: NSRange {
        get { return _selectedRange }
        set {
            _selectedRange = newValue
            setNeedsDisplay(bounds)
        }
    }
    
    @objc public var defaultFont: NSFont {
        get { return _defaultFont }
        set {
            _defaultFont = newValue
            _lineHeight = NSLayoutManager().defaultLineHeight(for: newValue)
            setNeedsDisplay(bounds)
        }
    }
    
    @objc public var destination: NSPoint {
        get { return _destination }
        set { _destination = newValue }
    }
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        if let font = NSFont(name: "Lucida Grande", size: 20) {
            _defaultFont = font
        } else {
            _defaultFont = NSFont.systemFont(ofSize: 20)
        }
        _lineHeight = NSLayoutManager().defaultLineHeight(for: _defaultFont)
    }
    
    public override var isOpaque: Bool {
        return false
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState()
        
        let half = frame.size.height / 2.0
        let fromTop = _destination.y > half
        
        ctx.translateBy(x: 1.0, y: 1.0)
        if !fromTop {
            ctx.translateBy(x: 0.0, y: 5.0)
        }
        
        var dest = _destination
        dest.x -= 1.0
        dest.y -= 1.0
        if !fromTop {
            dest.y -= 5.0
        }
        
        ctx.saveGState()
        let ovalSize: CGFloat = 6.0
        ctx.translateBy(x: 1.0, y: 1.0)
        
        let fw = bounds.size.width - 3
        let fh = bounds.size.height - 3 - 5
        
        ctx.beginPath()
        ctx.move(to: CGPoint(x: 0, y: fh - ovalSize))
        ctx.addArc(tangent1End: CGPoint(x: 0, y: fh), tangent2End: CGPoint(x: ovalSize, y: fh), radius: ovalSize)
        
        if fromTop {
            var left = dest.x - 2.5
            var right = left + 5.0
            if left < ovalSize {
                left = ovalSize
                right = left + 5.0
            } else if right > fw - ovalSize {
                right = fw - ovalSize
                left = right - 5.0
            }
            ctx.addLine(to: CGPoint(x: left, y: fh))
            ctx.addLine(to: CGPoint(x: dest.x, y: dest.y))
            ctx.addLine(to: CGPoint(x: right, y: fh))
        }
        
        ctx.addArc(tangent1End: CGPoint(x: fw, y: fh), tangent2End: CGPoint(x: fw, y: fh - ovalSize), radius: ovalSize)
        ctx.addArc(tangent1End: CGPoint(x: fw, y: 0), tangent2End: CGPoint(x: fw - ovalSize, y: 0), radius: ovalSize)
        
        if !fromTop {
            var left = dest.x - 2.5
            var right = left + 5.0
            if left < ovalSize {
                left = ovalSize
                right = left + 5.0
            } else if right > fw - ovalSize {
                right = fw - ovalSize
                left = right - 5.0
            }
            ctx.addLine(to: CGPoint(x: right, y: 0))
            ctx.addLine(to: CGPoint(x: dest.x, y: dest.y))
            ctx.addLine(to: CGPoint(x: left, y: 0))
        }
        
        ctx.addArc(tangent1End: CGPoint(x: 0, y: 0), tangent2End: CGPoint(x: 0, y: ovalSize), radius: ovalSize)
        ctx.closePath()
        
        ctx.setFillColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0)
        ctx.setLineWidth(2.0)
        ctx.setStrokeColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        
        ctx.drawPath(using: .fillStroke)
        ctx.restoreGState()
        
        ctx.translateBy(x: 4.0, y: 3.0)
        if let str = _string {
            str.draw(at: NSZeroPoint)
            
            let line = CTLineCreateWithAttributedString(str)
            let offset = CTLineGetOffsetForStringIndex(line, _selectedRange.location, nil)
            NSColor.white.set()
            NSBezierPath.defaultLineWidth = 1.0
            NSBezierPath.strokeLine(from: NSPoint(x: offset, y: 0), to: NSPoint(x: offset, y: _lineHeight))
        }
        
        ctx.restoreGState()
    }
}
