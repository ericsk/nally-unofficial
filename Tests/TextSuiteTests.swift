import Testing
import Foundation
@testable import Nally

@Suite("Text Suite & Line Wrapping Tests")
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
}
