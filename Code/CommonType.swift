//
//  CommonType.swift
//  Nally
//
//  Created by Antigravity on 2026/7/14.
//  Copyright 2026 yllan.org. All rights reserved.
//

import Foundation

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
        self.init(v: terminalAttribute.rawValue)
    }
}

extension cell {
    public var terminalCell: TerminalCell {
        return TerminalCell(byte: self.byte, attr: self.attr.terminalAttribute)
    }

    public init(_ terminalCell: TerminalCell) {
        self.init(byte: terminalCell.byte, attr: attribute(terminalCell.attr))
    }
}
