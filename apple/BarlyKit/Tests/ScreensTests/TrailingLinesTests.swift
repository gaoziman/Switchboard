import Foundation
import Testing
@testable import Screens

/// 读会话尾部的行：边读边交出去（导出最多读 256 MB，原来先整块读进来、每行再拷一份，峰值翻倍）。
/// 交出来的行必须和原来一次读完的 trailing 一模一样，解析会话的代码才不用动
@Suite("流式读尾部的行")
struct TrailingLinesTests {
    private func file(_ bytes: [UInt8]) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("sb-lines-\(UUID()).jsonl")
        try Data(bytes).write(to: url)
        return url
    }

    @Test("各种文件 × 各种读取上限 × 各种块大小：和一次读完的结果逐行相同")
    func matchesTrailing() throws {
        var rng = SystemRandomNumberGenerator()
        let shapes: [[UInt8]] = [
            Array("a\nbb\nccc\n".utf8), Array("a\nbb\nccc".utf8), Array("\n\na\n\n\nbb\n".utf8),
            Array("\nfirst\nsecond".utf8), [], Array("\n".utf8), Array("only".utf8),
        ] + (0..<20).map { _ in
            (0..<Int.random(in: 0...400, using: &rng)).map { _ in Bool.random(using: &rng) && Bool.random(using: &rng) ? 10 : UInt8.random(in: 97...122, using: &rng) }
        }
        for bytes in shapes {
            let url = try file(bytes)
            defer { try? FileManager.default.removeItem(at: url) }
            for maxBytes in [1, 2, 3, 5, 8, 13, 64, 100, 399, 1 << 20] {
                let expected = JSONLines.trailing(url, maxBytes: maxBytes)
                for chunk in [1, 2, 3, 7, 16, 1 << 16] {
                    let got = Array(JSONLines.trailingLines(url, maxBytes: maxBytes, chunkSize: chunk))
                    #expect(got == expected, "bytes=\(bytes.count) max=\(maxBytes) chunk=\(chunk)")
                }
            }
        }
    }

    @Test("文件不存在：没有行")
    func missingFile() {
        #expect(Array(JSONLines.trailingLines(URL(fileURLWithPath: "/nonexistent/\(UUID())"), maxBytes: 100)).isEmpty)
    }
}
