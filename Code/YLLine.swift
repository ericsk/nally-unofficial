import Foundation

@objc(YLLine)
public class YLLine: NSObject {
    @objc public var width: Int
    @objc public var runs: [YLRun] = []
    
    private let tabSize = 4
    
    @objc public init(width: Int) {
        self.width = width
        super.init()
    }
    
    @objc public static func line(withWidth width: Int) -> YLLine {
        return YLLine(width: width)
    }
    
    @objc public var length: Int {
        var length = 0
        for run in runs {
            if length >= width && run.type == .space { continue }
            
            if run.type == .tab {
                length += (tabSize - (length % tabSize))
                if length >= width {
                    length = width
                }
                continue
            }
            length += run.length
        }
        return length
    }
    
    @objc public func hasRoomForRun(_ run: YLRun) -> Bool {
        if run.type == .space { return true }
        if run.type == .tab { return true }
        if run.type == .newLine { return false }
        
        return run.length + self.length <= self.width
    }
    
    @objc public func addRun(_ run: YLRun) {
        runs.append(run)
    }
    
    @objc public func lastStringRun() -> YLRun? {
        for run in runs.reversed() {
            if run.type == .string {
                return run
            }
        }
        return nil
    }
    
    @objc public func popRunsToWrapLine() -> [YLRun]? {
        let originRuns = runs
        var poppedRuns: [YLRun] = []
        
        while !runs.isEmpty {
            let run = runs.removeLast()
            poppedRuns.insert(run, at: 0)
            
            if !runs.isEmpty && !runs.last!.shouldBeAvoidAtEndOfLine() && !run.shouldBeAvoidAtBeginOfLine() {
                return poppedRuns
            }
        }
        
        runs = originRuns
        return nil
    }
    
    @objc public override var description: String {
        var result = ""
        var length = 0
        
        for run in runs {
            if length >= width && run.type == .space { continue }
            
            if run.type == .tab {
                var numberOfSpaces = (tabSize - (length % tabSize))
                while numberOfSpaces > 0 {
                    if length >= width { break }
                    result.append(" ")
                    numberOfSpaces -= 1
                    length += 1
                }
                continue
            }
            
            result.append(run.string)
            length += run.length
        }
        return result
    }
}
