import Foundation
import Testing
@testable import Screens

@Suite("预览：块级 Markdown")
struct MarkdownBlocksTests {
    @Test("标题、段落：# 的个数是级别；连续的几行是一段，保留换行")
    func headingsAndParagraphs() {
        let blocks = MarkdownBlocks.parse("## 这一版的内容\n第一行\n第二行\n\n另一段")
        #expect(blocks == [.heading(2, "这一版的内容"), .paragraph("第一行\n第二行"), .paragraph("另一段")])
    }

    @Test("无序 / 有序列表：- * 都算；有序列表保留原来的序号")
    func lists() {
        #expect(MarkdownBlocks.parse("- 一\n* 二") == [.bullets(["一", "二"])])
        #expect(MarkdownBlocks.parse("1. 建议\n2. 证书\n10. 仓库") == [.numbered(start: 1, ["建议", "证书", "仓库"])])
        #expect(MarkdownBlocks.parse("3. 从三开始") == [.numbered(start: 3, ["从三开始"])])
    }

    @Test("表格：第一行是表头，|---| 分隔行不算一行；单元格去掉两边空格")
    func table() {
        let md = "| 环节 | 结果 |\n|---|:--:|\n| macOS | 已公证 |\n| Windows | 没签名 |"
        #expect(MarkdownBlocks.parse(md) == [.table(header: ["环节", "结果"], rows: [["macOS", "已公证"], ["Windows", "没签名"]])])
    }

    @Test("围栏代码块：带语言、原样保留缩进；没闭合的围栏读到结尾")
    func code() {
        let md = "执行：\n```bash\nssh deploy \\\n  'cp a b'\n```\n完成"
        #expect(MarkdownBlocks.parse(md) == [.paragraph("执行："), .code(language: "bash", "ssh deploy \\\n  'cp a b'"), .paragraph("完成")])
        #expect(MarkdownBlocks.parse("```\nx\ny") == [.code(language: "", "x\ny")])
    }

    @Test("引用和分隔线")
    func quoteAndRule() {
        #expect(MarkdownBlocks.parse("> 注意\n> 第二行\n\n---") == [.quote("注意\n第二行"), .rule])
    }

    @Test("表格行里的 | 不会把普通段落当成表格：只有以 | 开头的行才算")
    func pipeInParagraph() {
        #expect(MarkdownBlocks.parse("a | b") == [.paragraph("a | b")])
    }
}

@Suite("预览：时间线")
struct TranscriptTimelineTests {
    private func e(_ id: Int, _ kind: TranscriptEntry.Kind, _ minute: Double) -> TranscriptEntry {
        TranscriptEntry(id: id, kind: kind, time: Date(timeIntervalSince1970: minute * 60))
    }

    @Test("工具调用：每一次是 名字 + 参数；摘要还是原来的「名字 参数 · …」，超过 4 个加省略号")
    func toolSummary() {
        let calls = (1...5).map { ToolCall(name: "Bash", arg: "cmd\($0)") }
        #expect(ToolCall.summary(of: Array(calls.prefix(2))) == "Bash cmd1 · Bash cmd2")
        #expect(ToolCall.summary(of: calls) == "Bash cmd1 · Bash cmd2 · Bash cmd3 · Bash cmd4 …")
        #expect(ToolCall(name: "Read", arg: "").summary == "Read")
    }

    @Test("Claude 的 tool_use：命令、文件名（只留最后一段）当参数")
    func claudeToolCalls() {
        #expect(TranscriptLoader.toolCall("Bash", ["command": "git status"]) == ToolCall(name: "Bash", arg: "git status"))
        #expect(TranscriptLoader.toolCall("Read", ["file_path": "/Users/me/p/src/App.tsx"]) == ToolCall(name: "Read", arg: "App.tsx"))
        #expect(TranscriptLoader.toolCall("Task", nil) == ToolCall(name: "Task", arg: ""))
        // 开头的「cd 某目录;」「cd 某目录 &&」去掉：真正干活的命令才看得见
        #expect(TranscriptLoader.toolCall("Bash", ["command": "cd /Volumes/x/BarlyKit; sed -n 1,20p a.swift"]).arg == "sed -n 1,20p a.swift")
        #expect(TranscriptLoader.toolCall("Bash", ["command": "cd \"/a b\" && swift test"]).arg == "swift test")
        #expect(TranscriptLoader.toolCall("Bash", ["command": "cd /tmp"]).arg == "cd /tmp")
    }

    @Test("统计：几轮（你说了几次）、几次工具、改了几个文件（Edit / Write 按文件去重）、从第一条到最后一条几分钟")
    func stats() {
        let entries = [
            e(0, .user("发布"), 0),
            e(1, .tools([ToolCall(name: "Bash", arg: "build"), ToolCall(name: "Edit", arg: "a.sh"), ToolCall(name: "Edit", arg: "a.sh")]), 2),
            e(2, .assistant("好了"), 5),
            e(3, .user("回滚命令"), 10),
            e(4, .tools([ToolCall(name: "Write", arg: "b.md")]), 12),
            e(5, .assistant("给你"), 19),
        ]
        let s = TranscriptStats(entries)
        #expect(s.rounds == 2)
        #expect(s.tools == 4)
        #expect(s.filesChanged == 2)
        #expect(s.minutes == 19)
    }

    @Test("跨天插日期：今天的第一条前面不插；不是今天的内容前面插；中间换了一天再插")
    func dayMarkers() {
        let now = Date()
        let yesterday = now.addingTimeInterval(-86_400)
        func kinds(_ rows: [TimelineRow]) -> [String] { rows.map { if case .day = $0 { "day" } else { "e" } } }
        #expect(kinds(TimelineRow.rows([TranscriptEntry(id: 0, kind: .user("a"), time: now)])) == ["e"])
        #expect(kinds(TimelineRow.rows([TranscriptEntry(id: 0, kind: .user("a"), time: yesterday),
                                        TranscriptEntry(id: 1, kind: .assistant("b"), time: yesterday),
                                        TranscriptEntry(id: 2, kind: .user("c"), time: now)])) == ["day", "e", "e", "day", "e"])
    }

    @Test("过滤：只看对话 = 你的话和回复；只看工具 = 你的话和工具（保留你的话当分段）")
    func filter() {
        let entries = [
            e(0, .user("发布"), 0),
            e(1, .tools([ToolCall(name: "Bash", arg: "build")]), 1),
            e(2, .assistant("好了"), 2),
            e(3, .code(language: "bash", code: "x"), 2),
        ]
        #expect(TimelineFilter.conversation.apply(entries).map(\.id) == [0, 2, 3])
        #expect(TimelineFilter.tools.apply(entries).map(\.id) == [0, 1])
        #expect(TimelineFilter.all.apply(entries).map(\.id) == [0, 1, 2, 3])
    }
}
