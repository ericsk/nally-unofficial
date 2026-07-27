import Cocoa

@MainActor
@objc(YLContextualMenuManager)
public class YLContextualMenuManager: NSObject {
    @objc public static let sharedInstance = YLContextualMenuManager()
    
    private var urlsToOpen: [String] = []
    
    private override init() {
        super.init()
    }
    
    private func extractShortURL(from s: String) -> String {
        return s.filter { $0 >= "!" && $0 <= "~" }
    }
    
    private func extractLongURL(from s: String) -> String {
        return s.replacingOccurrences(of: "\\\r", with: "")
    }
    
    private func isUrlLike(_ s: String) -> Bool {
        let comps = s.components(separatedBy: ".")
        var count = 0
        for comp in comps {
            if !comp.isEmpty {
                count += 1
            } else {
                return false
            }
            if count > 1 {
                return true
            }
        }
        return false
    }
    
    private func protocolPrefixAppendedUrlString(_ s: String) -> String {
        let protocols = ["http://", "https://", "ftp://", "telnet://", "bbs://", "ssh://", "mailto:"]
        for p in protocols {
            if s.hasPrefix(p) {
                return s
            }
        }
        return "http://" + s
    }
    
    @objc public func isImageURL(_ url: URL) -> Bool {
        let pathExt = url.pathExtension.lowercased()
        let imageExtensions = ["png", "jpg", "jpeg", "gif", "webp", "avif", "heic", "heif", "bmp", "svg", "tiff"]
        if imageExtensions.contains(pathExt) {
            return true
        }
        let host = url.host?.lowercased() ?? ""
        if host.contains("imgur.com") || host.contains("postimg.cc") || host.contains("upload.cc") || host.contains("i.red.it") {
            return !url.path.isEmpty && url.path != "/"
        }
        return false
    }
    
    @objc public func extractPTTAID(from string: String) -> String? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        let pattern = "(#1[0-9a-zA-Z_\\-]{7,8})|(\\b1[0-9a-zA-Z_\\-]{7,8}\\b)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let nsString = trimmed as NSString
        let results = regex.matches(in: trimmed, options: [], range: NSRange(location: 0, length: nsString.length))
        
        if let match = results.first {
            let matchedStr = nsString.substring(with: match.range)
            return matchedStr.hasPrefix("#") ? matchedStr : "#" + matchedStr
        }
        return nil
    }
    
    @objc public func availableMenuItemForSelectionString(_ selectedString: String) -> [NSMenuItem] {
        var items: [NSMenuItem] = []
        let shortURL = extractShortURL(from: selectedString)
        let longURL = extractLongURL(from: selectedString)
        
        if let aid = extractPTTAID(from: selectedString) {
            let jumpTitle = String(format: NSLocalizedString("Jump to PTT Article (%@)", comment: "Menu"), aid)
            let jumpItem = NSMenuItem(title: jumpTitle, action: #selector(jumpToPTTAID(_:)), keyEquivalent: "")
            jumpItem.target = self
            jumpItem.representedObject = aid
            items.append(jumpItem)
            
            let copyAidTitle = String(format: NSLocalizedString("Copy PTT AID (%@)", comment: "Menu"), aid)
            let copyAidItem = NSMenuItem(title: copyAidTitle, action: #selector(copyPTTAID(_:)), keyEquivalent: "")
            copyAidItem.target = self
            copyAidItem.representedObject = aid
            items.append(copyAidItem)
            
            items.append(NSMenuItem.separator())
        }
        
        if isUrlLike(longURL) {
            let seps = CharacterSet(charactersIn: " \r\n")
            let blocks = longURL.components(separatedBy: seps)
            var urls: [String] = []
            for block in blocks {
                if isUrlLike(block) {
                    urls.append(protocolPrefixAppendedUrlString(block))
                }
            }
            
            if !urls.isEmpty {
                var title = ""
                if urls.count > 1 {
                    title = NSLocalizedString("Open mutiple URLs", comment: "Open mutiple URLs")
                } else if urls.count == 1 {
                    title = urls[0]
                }
                
                self.urlsToOpen = urls
                let item = NSMenuItem(title: title, action: #selector(openURL(_:)), keyEquivalent: "")
                item.target = self
                items.append(item)
            }
        }
        
        let isAllDigit: (String) -> Bool = { s in
            let nonNumbers = CharacterSet.decimalDigits.inverted
            return s.rangeOfCharacter(from: nonNumbers) == nil
        }
        
        let addShortenedURLMenuItem: (String, String) -> Void = { [weak self] title, actualURLString in
            guard let self = self else { return }
            self.urlsToOpen = [actualURLString]
            let item = NSMenuItem(title: title, action: #selector(openURL(_:)), keyEquivalent: "")
            item.target = self
            items.append(item)
        }
        
        if shortURL.hasPrefix("sm") && shortURL.count <= 10 && isAllDigit(String(shortURL.dropFirst(2))) {
            addShortenedURLMenuItem("NicoNico/\(shortURL)", "http://www.nicovideo.jp/watch/\(shortURL)")
        } else if shortURL.hasPrefix("id=") && shortURL.count <= 12 && isAllDigit(String(shortURL.dropFirst(3))) {
            addShortenedURLMenuItem("pixiv_illust/\(shortURL)", "http://www.pixiv.net/member_illust.php?mode=medium&illust_\(shortURL)")
        } else if shortURL.hasPrefix("mid=") && shortURL.count <= 12 && isAllDigit(String(shortURL.dropFirst(4))) {
            let idStr = String(shortURL.dropFirst(4))
            addShortenedURLMenuItem("pixiv_member/\(idStr)", "http://www.pixiv.net/member.php?id=\(idStr)")
        } else if shortURL.hasSuffix(".jpg") || shortURL.hasSuffix(".jpeg") {
            addShortenedURLMenuItem("Image search by GOOGLE", "https://www.google.com/searchbyimage?&image_url=\(shortURL)")
        } else if shortURL.count == 4 {
            addShortenedURLMenuItem("ppt.cc/\(shortURL)", "http://ppt.cc/\(shortURL)")
        } else if shortURL.count == 5 {
            addShortenedURLMenuItem("0rz.tw/\(shortURL)", "http://0rz.tw/\(shortURL)")
        } else if shortURL.count == 6 || shortURL.count == 7 {
            addShortenedURLMenuItem("tinyurl.com/\(shortURL)", "http://tinyurl.com/\(shortURL)")
        }
        
        if !selectedString.isEmpty {
            let googleItem = NSMenuItem(title: "Google", action: #selector(google(_:)), keyEquivalent: "")
            googleItem.target = self
            googleItem.representedObject = selectedString
            items.append(googleItem)
            
            let dictItem = NSMenuItem(title: NSLocalizedString("Lookup in Dictionary", comment: "Menu"), action: #selector(lookupDictionary(_:)), keyEquivalent: "")
            dictItem.target = self
            dictItem.representedObject = selectedString
            items.append(dictItem)
            
            let copyItem = NSMenuItem(title: NSLocalizedString("Copy", comment: "Menu"), action: NSSelectorFromString("copy:"), keyEquivalent: "")
            copyItem.target = NSApp.keyWindow?.firstResponder
            copyItem.representedObject = selectedString
            items.append(copyItem)
        } else {
            if let clippedString = NSPasteboard.general.string(forType: .string),
               let url = URL(string: clippedString),
               url.scheme != nil,
               url.host != nil {
                let tinyurlItem = NSMenuItem(title: NSLocalizedString("Paste tinyurl", comment: "Menu"), action: #selector(tinyurl(_:)), keyEquivalent: "")
                tinyurlItem.target = self
                tinyurlItem.representedObject = clippedString
                items.append(tinyurlItem)
            }
        }
        
        return items
    }
    
    @objc public func jumpToPTTAID(_ sender: Any?) {
        guard let item = sender as? NSMenuItem, let rawAid = item.representedObject as? String else { return }
        let cleanAid = rawAid.hasPrefix("#") ? String(rawAid.dropFirst()) : rawAid
        if let delegate = NSApp.delegate as? NallyAppDelegate,
           let controller = delegate.controller,
           let telnetView = controller.telnetView() as? YLView {
            telnetView.insertText("#" + cleanAid + "\r", replacementRange: NSRange(location: NSNotFound, length: 0))
        }
    }
    
    @objc public func copyPTTAID(_ sender: Any?) {
        guard let item = sender as? NSMenuItem, let aid = item.representedObject as? String else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(aid, forType: .string)
    }
    
    @objc public func openURL(_ sender: Any?) {
        for u in urlsToOpen {
            let appended = protocolPrefixAppendedUrlString(u)
            if let escaped = appended.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let url = URL(string: escaped) {
                NSWorkspace.shared.open(url)
            }
        }
        urlsToOpen.removeAll()
    }
    
    @objc public func google(_ sender: Any?) {
        guard let item = sender as? NSMenuItem, let query = item.representedObject as? String else { return }
        if let escaped = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "http://www.google.com/search?q=\(escaped)") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc public func lookupDictionary(_ sender: Any?) {
        guard let item = sender as? NSMenuItem, let text = item.representedObject as? String else { return }
        let spb = NSPasteboard(name: .init(rawValue: UUID().uuidString))
        spb.declareTypes([.string], owner: self)
        spb.setString(text, forType: .string)
        NSPerformService("Look Up in Dictionary", spb)
    }
    
    @objc public func tinyurl(_ sender: Any?) {
        guard let item = sender as? NSMenuItem, let u = item.representedObject as? String else { return }
        let apiRequestString = "http://tinyurl.com/api-create.php?url=\(u)"
        guard let url = URL(string: apiRequestString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                   let result = String(data: data, encoding: .utf8) {
                    if let delegate = NSApp.delegate as? NallyAppDelegate,
                       let controller = delegate.controller,
                       let telnetView = controller.telnetView() as? YLView {
                        telnetView.insertText(result, replacementRange: NSRange(location: NSNotFound, length: 0))
                    }
                }
            } catch {
                NSLog("tinyurl error: \(error)")
            }
        }
    }
}
