import Foundation

@objc(YLTextSuite)
public class YLTextSuite: NSObject {
    
    private let space: UInt16 = 0x0020
    private let tab: UInt16 = 0x0009
    private let lf: UInt16 = 0x000a
    private let cr: UInt16 = 0x000d
    
    private func isGluingCharacter(_ c: Character) -> Bool {
        guard let utf16Val = c.utf16.first else { return false }
        if utf16Val >= 65 && utf16Val <= 90 { return true } // A-Z
        if utf16Val >= 97 && utf16Val <= 122 { return true } // a-z
        if utf16Val >= 48 && utf16Val <= 57 { return true } // 0-9
        
        let punctuation = "'\".,;:*&^#@~`="
        return punctuation.contains(c)
    }
    
    @objc public func wrapText(_ text: String, withLength length: Int32, encoding: YLEncoding) -> String {
        let spaceRun = YLRun(string: " ", type: .space, encoding: encoding)
        let tabRun = YLRun(string: "\t", type: .tab, encoding: encoding)
        let lineRun = YLRun(string: "\n", type: .newLine, encoding: encoding)
        
        var bufferRun = YLRun(string: "", type: .string, encoding: encoding)
        var runs: [YLRun] = []
        
        let commitBufferRun = {
            if !bufferRun.string.isEmpty {
                runs.append(bufferRun)
                bufferRun = YLRun(string: "", type: .string, encoding: encoding)
            }
        }
        
        /* Create runs from the text */
        for char in text {
            guard let utf16Val = char.utf16.first else { continue }
            if utf16Val == space {
                commitBufferRun()
                runs.append(spaceRun)
                continue
            }
            if utf16Val == tab {
                commitBufferRun()
                runs.append(tabRun)
                continue
            }
            if utf16Val == cr || utf16Val == lf {
                commitBufferRun()
                runs.append(lineRun)
                continue
            }
            
            let s = String(char)
            if !isGluingCharacter(char) {
                commitBufferRun()
                runs.append(YLRun(string: s, type: .string, encoding: encoding))
            } else {
                bufferRun.appendString(s)
            }
        }
        commitBufferRun()
        
        var result: [String] = []
        let len = Int(length)
        var line = YLLine(width: len)
        var queue = RunQueue(runs: runs)
        
        /* Layout the run */
        while !queue.isEmpty {
            guard let run = queue.popFirst() else { break }
            
            if run.type == .newLine {
                result.append(line.description)
                line = YLLine(width: len)
                continue
            }
            
            if line.hasRoomForRun(run) {
                line.addRun(run)
                continue
            }
            
            // if the line is empty, split the run
            if line.runs.isEmpty {
                let splittedRuns = run.forceSplitToMaxLength(len)
                if splittedRuns.count > 1 {
                    queue.prepend(contentsOf: splittedRuns)
                } else {
                    line.addRun(run)
                }
                continue
            }
            
            // create a new line
            queue.prepend(run)
            if run.shouldBeAvoidAtBeginOfLine() || (line.lastStringRun()?.shouldBeAvoidAtEndOfLine() ?? false) {
                if let poppedRuns = line.popRunsToWrapLine(), !poppedRuns.isEmpty {
                    queue.prepend(contentsOf: poppedRuns)
                } else if line.length < line.width { // can't pop, force split
                    let first = queue.popFirst()!
                    queue.prepend(contentsOf: first.forceSplitToMaxLength(line.width - line.length))
                    continue
                }
            }
            
            result.append(line.description)
            line = YLLine(width: len)
        }
        
        if !line.runs.isEmpty {
            result.append(line.description)
        }
        
        return result.joined(separator: "\n")
    }
    
    @objc public func paddingText(_ text: String, withLeftPadding leftPadding: Int32) -> String {
        let paddingString = String(repeating: " ", count: Int(leftPadding))
        var result = ""
        
        for (i, char) in text.enumerated() {
            if char.utf16.first == lf {
                result.append(char)
                result.append(paddingString)
            } else if i == 0 {
                result.append(paddingString)
                result.append(char)
            } else {
                result.append(char)
            }
        }
        
        return result
    }
}

private struct RunQueue {
    private let originalRuns: [YLRun]
    private var headIndex: Int = 0
    private var prependStack: [YLRun] = []
    
    init(runs: [YLRun]) {
        self.originalRuns = runs
    }
    
    var isEmpty: Bool {
        return prependStack.isEmpty && headIndex >= originalRuns.count
    }
    
    mutating func popFirst() -> YLRun? {
        if let run = prependStack.popLast() {
            return run
        }
        if headIndex < originalRuns.count {
            let run = originalRuns[headIndex]
            headIndex += 1
            return run
        }
        return nil
    }
    
    mutating func prepend(_ run: YLRun) {
        prependStack.append(run)
    }
    
    mutating func prepend(contentsOf runs: [YLRun]) {
        for run in runs.reversed() {
            prependStack.append(run)
        }
    }
}

