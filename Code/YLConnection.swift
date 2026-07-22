//
//  YLConnection.swift
//  Nally
//
//  Created by Antigravity on 2026/7/14.
//  Copyright 2026 yllan.org. All rights reserved.
//

import Cocoa

@objc(YLConnectionProtocol)
public protocol YLConnectionProtocol: NSObjectProtocol {
    func close()
    func reconnect()
    @objc(connectToSite:) func connect(to site: YLSite) -> Bool
    @objc(connectToAddress:) func connect(toAddress addr: String) -> Bool
    @objc(connectToAddress:port:) func connect(toAddress addr: String, port: UInt32) -> Bool
    @objc(receiveBytes:length:) func receiveBytes(_ bytes: UnsafePointer<UInt8>, length: Int)
    @objc(sendBytes:length:) func sendBytes(_ msg: UnsafePointer<UInt8>, length: Int)
    @objc(sendData:) func sendData(_ msg: Data)
    
    var terminal: YLTerminal? { get set }
    var connected: Bool { get set }
    var connectionName: String? { get set }
    var connectionAddress: String? { get set }
    var icon: NSImage? { get set }
    var isProcessing: Bool { get set }
    var site: YLSite? { get set }
    func lastTouchDate() -> Date?
}

@objc(YLConnection)
public class YLConnection: NSObject, YLConnectionProtocol {
    @objc(connectionWithAddress:)
    public class func connection(withAddress addr: String) -> YLConnection {
        NSLog("YLConnection: connectionWithAddress called with: \(addr)")
        if addr.hasPrefix("ssh://") {
            NSLog("YLConnection: returning YLSSH")
            return YLSSH()
        } else {
            NSLog("YLConnection: returning YLTelnet")
            return YLTelnet()
        }
    }
    
    private var _terminal: YLTerminal?
    @objc public var terminal: YLTerminal? {
        get { return _terminal }
        set {
            if _terminal !== newValue {
                _terminal = newValue
                _terminal?.connection = self
            }
        }
    }
    
    public override init() {
        super.init()
        self.icon = NSImage(named: "offline.pdf")
    }
    
    public static let stateDidChangeNotification = Notification.Name("YLConnectionStateDidChangeNotification")

    @objc public dynamic var connected: Bool = false {
        didSet {
            if connected {
                icon = NSImage(named: "connect.pdf")
            } else {
                terminal?.hasMessage = false
                icon = NSImage(named: "offline.pdf")
            }
            NotificationCenter.default.post(name: YLConnection.stateDidChangeNotification, object: self)
        }
    }
    
    @objc public dynamic var connectionName: String?
    @objc public dynamic var connectionAddress: String?
    @objc public dynamic var icon: NSImage? {
        didSet {
            NotificationCenter.default.post(name: YLConnection.stateDidChangeNotification, object: self)
        }
    }
    @objc public dynamic var isProcessing: Bool = false
    @objc public var site: YLSite?
    
    @objc public var lastTouchDateValue: Date?
    
    @objc public func lastTouchDate() -> Date? {
        return lastTouchDateValue
    }
    
    @objc public func close() {}
    @objc public func reconnect() {}
    
    @objc(connectToSite:)
    public func connect(to site: YLSite) -> Bool {
        self.site = site
        return connect(toAddress: site.address)
    }
    
    @objc(connectToAddress:)
    public func connect(toAddress addr: String) -> Bool {
        return true
    }
    
    @objc(connectToAddress:port:)
    public func connect(toAddress addr: String, port: UInt32) -> Bool {
        return true
    }
    
    @objc(receiveBytes:length:)
    public func receiveBytes(_ bytes: UnsafePointer<UInt8>, length: Int) {}
    
    @objc(sendBytes:length:)
    public func sendBytes(_ msg: UnsafePointer<UInt8>, length: Int) {}
    
    @objc(sendData:)
    public func sendData(_ msg: Data) {}
}
