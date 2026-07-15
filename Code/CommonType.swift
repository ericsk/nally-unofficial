//
//  CommonType.swift
//  Nally
//
//  Created by Antigravity on 2026/7/14.
//  Copyright 2026 yllan.org. All rights reserved.
//

import Foundation

@objc(YLEncoding)
public enum YLEncoding: UInt16 {
    case YLBig5Encoding = 0
    case YLGBKEncoding = 1
}

@objc(YLANSIColorKey)
public enum YLANSIColorKey: UInt16 {
    case YLCtrlUANSIColorKey = 0
    case YLEscEscEscANSIColorKey = 1
}

public enum ASCII_CODE: Int {
    case C0, INTERMEDIATE, ALPHABETIC, DELETE, C1, G1, SPECIAL, ERROR
}

// Simulating C union/struct attribute
public struct attribute: Equatable, Hashable {
    public var v: UInt16 = 0
    
    public init(v: UInt16 = 0) {
        self.v = v
    }
    
    public struct Fields {
        private var val: UInt16
        
        init(val: UInt16) {
            self.val = val
        }
        
        public var rawValue: UInt16 {
            return val
        }
        
        public var fgColor: UInt32 {
            get { UInt32(val & 0xF) }
            set { val = (val & ~0xF) | UInt16(newValue & 0xF) }
        }
        
        public var bgColor: UInt32 {
            get { UInt32((val >> 4) & 0xF) }
            set { val = (val & ~(0xF << 4)) | (UInt16(newValue & 0xF) << 4) }
        }
        
        public var bold: UInt32 {
            get { UInt32((val >> 8) & 1) }
            set { val = (val & ~(1 << 8)) | (UInt16(newValue & 1) << 8) }
        }
        
        public var underline: UInt32 {
            get { UInt32((val >> 9) & 1) }
            set { val = (val & ~(1 << 9)) | (UInt16(newValue & 1) << 9) }
        }
        
        public var blink: UInt32 {
            get { UInt32((val >> 10) & 1) }
            set { val = (val & ~(1 << 10)) | (UInt16(newValue & 1) << 10) }
        }
        
        public var reverse: UInt32 {
            get { UInt32((val >> 11) & 1) }
            set { val = (val & ~(1 << 11)) | (UInt16(newValue & 1) << 11) }
        }
        
        public var doubleByte: UInt32 {
            get { UInt32((val >> 12) & 3) }
            set { val = (val & ~(3 << 12)) | (UInt16(newValue & 3) << 12) }
        }
        
        public var url: UInt32 {
            get { UInt32((val >> 14) & 1) }
            set { val = (val & ~(1 << 14)) | (UInt16(newValue & 1) << 14) }
        }
        
        public var nothing: UInt32 {
            get { UInt32((val >> 15) & 1) }
            set { val = (val & ~(1 << 15)) | (UInt16(newValue & 1) << 15) }
        }
    }
    
    public var f: Fields {
        get { Fields(val: v) }
        set { v = newValue.rawValue }
    }
}

// Simulating C struct cell
public struct cell: Equatable, Hashable {
    public var byte: UInt8 = 0
    public var attr: attribute = attribute(v: 0)
    
    public init(byte: UInt8 = 0, attr: attribute = attribute(v: 0)) {
        self.byte = byte
        self.attr = attr
    }
}

public struct TerminalAttribute: Equatable, Hashable {
    public var fgColor: Int      // 0..15
    public var bgColor: Int      // 0..15
    public var bold: Bool
    public var underline: Bool
    public var blink: Bool
    public var reverse: Bool
    public var doubleByte: Int   // 0: single-byte, 1: double-byte first, 2: double-byte second
    public var url: Bool

    public init(
        fgColor: Int = 0,
        bgColor: Int = 0,
        bold: Bool = false,
        underline: Bool = false,
        blink: Bool = false,
        reverse: Bool = false,
        doubleByte: Int = 0,
        url: Bool = false
    ) {
        self.fgColor = fgColor
        self.bgColor = bgColor
        self.bold = bold
        self.underline = underline
        self.blink = blink
        self.reverse = reverse
        self.doubleByte = doubleByte
        self.url = url
    }

    public init(rawValue: UInt16) {
        self.fgColor = Int(rawValue & 0xF)
        self.bgColor = Int((rawValue >> 4) & 0xF)
        self.bold = ((rawValue >> 8) & 1) != 0
        self.underline = ((rawValue >> 9) & 1) != 0
        self.blink = ((rawValue >> 10) & 1) != 0
        self.reverse = ((rawValue >> 11) & 1) != 0
        self.doubleByte = Int((rawValue >> 12) & 3)
        self.url = ((rawValue >> 14) & 1) != 0
    }

    public var rawValue: UInt16 {
        var v: UInt16 = 0
        v |= UInt16(fgColor & 0xF)
        v |= UInt16(bgColor & 0xF) << 4
        if bold { v |= 1 << 8 }
        if underline { v |= 1 << 9 }
        if blink { v |= 1 << 10 }
        if reverse { v |= 1 << 11 }
        v |= UInt16(doubleByte & 3) << 12
        if url { v |= 1 << 14 }
        return v
    }

    // Helper properties mapping to CommonType.m functions
    public var isHidden: Bool {
        return !bold && (fgColor == bgColor || (fgColor == 0 && bgColor == 9))
    }

    public var bgColorIndex: Int {
        return reverse ? fgColor : bgColor
    }

    public var fgColorIndex: Int {
        return reverse ? bgColor : fgColor
    }

    public var bgBold: Bool {
        return reverse && bold
    }

    public var fgBold: Bool {
        return !reverse && bold
    }
}

public struct TerminalCell: Equatable, Hashable {
    public var byte: UInt8
    public var attr: TerminalAttribute

    public init(byte: UInt8 = 0, attr: TerminalAttribute = TerminalAttribute()) {
        self.byte = byte
        self.attr = attr
    }

    public var isBlink: Bool {
        return attr.blink && (attr.doubleByte != 0 || (byte != 32 && byte != 0)) // 32 is ASCII space ' '
    }
}

// MARK: - C Bridge Extensions
extension attribute {
    public var terminalAttribute: TerminalAttribute {
        return TerminalAttribute(rawValue: self.v)
    }

    public init(_ terminalAttribute: TerminalAttribute) {
        self.v = terminalAttribute.rawValue
    }
}

extension cell {
    public var terminalCell: TerminalCell {
        return TerminalCell(byte: self.byte, attr: self.attr.terminalAttribute)
    }

    public init(_ terminalCell: TerminalCell) {
        self.byte = terminalCell.byte
        self.attr = attribute(terminalCell.attr)
    }
}

// MARK: - Global Helper Functions
public func isHiddenAttribute(_ a: attribute) -> Int32 {
    let bold = a.f.bold
    let fg = a.f.fgColor
    let bg = a.f.bgColor
    return (bold == 0 && (fg == bg || (fg == 0 && bg == 9))) ? 1 : 0
}

public func isBlinkCell(_ c: cell) -> Int32 {
    let blink = c.attr.f.blink
    let doubleByte = c.attr.f.doubleByte
    let byte = c.byte
    if blink != 0 && (doubleByte != 0 || (byte != 32 && byte != 0)) {
        return 1
    }
    return 0
}

public func bgColorIndexOfAttribute(_ a: attribute) -> Int32 {
    return a.f.reverse != 0 ? Int32(a.f.fgColor) : Int32(a.f.bgColor)
}

public func fgColorIndexOfAttribute(_ a: attribute) -> Int32 {
    return a.f.reverse != 0 ? Int32(a.f.bgColor) : Int32(a.f.fgColor)
}

public func bgBoldOfAttribute(_ a: attribute) -> Int32 {
    return (a.f.reverse != 0 && a.f.bold != 0) ? 1 : 0
}

public func fgBoldOfAttribute(_ a: attribute) -> Int32 {
    return (a.f.reverse == 0 && a.f.bold != 0) ? 1 : 0
}

public func underlineOfAttribute(_ a: attribute) -> Int32 {
    return Int32(a.f.underline)
}

public func doubleByteOfAttribute(_ a: attribute) -> Int32 {
    return Int32(a.f.doubleByte)
}

public func urlOfAttribute(_ a: attribute) -> Int32 {
    return Int32(a.f.url)
}
