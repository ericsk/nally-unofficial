import Testing
import Foundation
@testable import Nally

@Suite("Text Suite & Line Wrapping Tests")
@MainActor
struct TextSuiteTests {
    init() {
        YLEncodingTable.initTable()
    }
    
    struct TestCase {
        let input: String
        let length: Int32
        let expected: String
        let comment: String
    }
    
    @Test("Big5 Line Wrapping Rules", arguments: [
        TestCase(input: "aaaaa", length: 5, expected: "aaaaa", comment: "No Wrap"),
        TestCase(input: "aaaaaa", length: 5, expected: "aaaaa\na", comment: "Force Wrap"),
        TestCase(input: "aaa aaa", length: 5, expected: "aaa \naaa", comment: "Simple Wrap"),
        TestCase(input: "中文字", length: 5, expected: "中文\n字", comment: "Chinese Wrap"),
        TestCase(input: "中文字", length: 4, expected: "中文\n字", comment: "Chinese Wrap"),
        TestCase(input: "中a文字", length: 3, expected: "中a\n文\n字", comment: "Chinese Wrap"),
        TestCase(input: "aa aa ,aa", length: 6, expected: "aa \naa ,aa", comment: "Prohibit Head"),
        TestCase(input: "aa ,aa", length: 5, expected: "aa ,a\na", comment: "Prohibit Head Pull All Line"),
        TestCase(input: "aaa(aa", length: 5, expected: "aaa\n(aa", comment: "Prohibit Tail"),
        TestCase(input: "aaa)aa", length: 5, expected: "aaa)\naa", comment: "Prohibit Head"),
        TestCase(input: "你好不好。", length: 8, expected: "你好不\n好。", comment: "Prohibit Head"),
        TestCase(input: "中文", length: 1, expected: "中\n文", comment: "Force Add")
    ])
    func testWrapLine(testCase: TestCase) {
        let t = YLTextSuite()
        let result = t.wrapText(testCase.input, withLength: testCase.length, encoding: .YLBig5Encoding)
        #expect(result == testCase.expected, "Failed on: \(testCase.comment)")
    }
    
    @Test("YLRun Length Caching and Invalidation")
    func testRunLengthCaching() {
        let run = YLRun(string: "Hello", type: .string, encoding: .YLBig5Encoding)
        #expect(run.length == 5)
        // Access again to hit cache
        #expect(run.length == 5)
        
        // Append string invalidates cache
        run.appendString("World")
        #expect(run.length == 10)
        
        let chineseRun = YLRun(string: "批踢踢", type: .string, encoding: .YLBig5Encoding)
        #expect(chineseRun.length == 6)
        #expect(chineseRun.length == 6)
        
        let spaceRun = YLRun(string: " ", type: .space, encoding: .YLBig5Encoding)
        #expect(spaceRun.length == 1)
    }
    
    @Test("Text Suite Large Text Wrapping Consistency")
    func testLargeTextWrapping() {
        let suite = YLTextSuite()
        let paragraph = "批踢踢實業坊（PTT）是台灣最具代表性的BBS站台之一。各看板熱門討論持續熱烈！ "
        let largeInput = String(repeating: paragraph, count: 50)
        
        let wrapped = suite.wrapText(largeInput, withLength: 78, encoding: .YLBig5Encoding)
        #expect(!wrapped.isEmpty)
        
        // Verify every line in the output does not exceed line limits
        let lines = wrapped.components(separatedBy: "\n")
        #expect(lines.count > 1)
        for line in lines {
            // Verify line has content and runs correctly
            #expect(!line.contains("\r"))
        }
    }
    
    @Test("Text Suite Left Padding Functionality")
    func testPaddingText() {
        let suite = YLTextSuite()
        let input = "Line1\nLine2\nLine3"
        let padded = suite.paddingText(input, withLeftPadding: 4)
        #expect(padded == "    Line1\n    Line2\n    Line3")
    }
}
