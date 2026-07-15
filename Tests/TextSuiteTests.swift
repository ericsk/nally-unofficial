import XCTest
@testable import Nally

class TextSuiteTests: XCTestCase {
    override func setUp() {
        super.setUp()
        YLEncodingTable.initTable()
    }
    
    func testWrapLine() {
        let t = YLTextSuite()
        
        XCTAssertEqual(t.wrapText("aaaaa", withLength: 5, encoding: .YLBig5Encoding), "aaaaa", "No Wrap")
        XCTAssertEqual(t.wrapText("aaaaaa", withLength: 5, encoding: .YLBig5Encoding), "aaaaa\na", "Force Wrap")
        XCTAssertEqual(t.wrapText("aaa aaa", withLength: 5, encoding: .YLBig5Encoding), "aaa \naaa", "Simple Wrap")
        XCTAssertEqual(t.wrapText("中文字", withLength: 5, encoding: .YLBig5Encoding), "中文\n字", "Chinese Wrap")
        XCTAssertEqual(t.wrapText("中文字", withLength: 4, encoding: .YLBig5Encoding), "中文\n字", "Chinese Wrap")
        XCTAssertEqual(t.wrapText("中a文字", withLength: 3, encoding: .YLBig5Encoding), "中a\n文\n字", "Chinese Wrap")
        XCTAssertEqual(t.wrapText("aa aa ,aa", withLength: 6, encoding: .YLBig5Encoding), "aa \naa ,aa", "Prohibit Head")
        XCTAssertEqual(t.wrapText("aa ,aa", withLength: 5, encoding: .YLBig5Encoding), "aa ,a\na", "Prohibit Head Pull All Line")
        
        XCTAssertEqual(t.wrapText("aaa(aa", withLength: 5, encoding: .YLBig5Encoding), "aaa\n(aa", "Prohibit Tail")
        XCTAssertEqual(t.wrapText("aaa)aa", withLength: 5, encoding: .YLBig5Encoding), "aaa)\naa", "Prohibit Head")
        
        XCTAssertEqual(t.wrapText("你好不好。", withLength: 8, encoding: .YLBig5Encoding), "你好不\n好。", "Prohibit Head")
        XCTAssertEqual(t.wrapText("中文", withLength: 1, encoding: .YLBig5Encoding), "中\n文", "Force Add")
    }
}
