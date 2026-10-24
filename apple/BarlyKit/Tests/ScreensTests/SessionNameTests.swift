import Foundation
import Testing
@testable import Screens

/// AI 起的名字：模型输出清洗成「主题｜动作」，显示时拆成两段
@Suite("会话名字")
struct SessionNameTests {
    @Test("去掉编号、引号、表情、结尾标点和「标题：」前缀；分隔符统一成全角竖线")
    func clean() {
        #expect(SessionName.clean("1. 「Tabula macOS 应用 | 修复功能并覆盖安装」。") == "Tabula macOS 应用｜修复功能并覆盖安装")
        #expect(SessionName.clean("- 🧩 本地 skill 与插件丨盘点分类与问题") == "本地 skill 与插件｜盘点分类与问题")
        #expect(SessionName.clean("标题：Codex 配置｜增删中转通道") == "Codex 配置｜增删中转通道")
        #expect(SessionName.clean("\"ego lite 浏览器\"") == "ego lite 浏览器")
        #expect(SessionName.clean("Title: Fix SSH reconnect | add backoff.") == "Fix SSH reconnect｜add backoff")
        #expect(SessionName.clean("  多个   空格 ｜  动作  ") == "多个 空格｜动作")
    }

    @Test("空的、只剩符号的不要；多于一个分隔符只留第一个；太长截断")
    func rejectAndLimit() {
        #expect(SessionName.clean("") == nil)
        #expect(SessionName.clean("  。」 ") == nil)
        #expect(SessionName.clean("｜修复") == "修复")                  // 主题空了：只剩动作当主题
        #expect(SessionName.clean("主题｜") == "主题")
        #expect(SessionName.clean("a｜b｜c") == "a｜b c")
        let long = SessionName.clean(String(repeating: "长", count: 60))!
        #expect(long.count == SessionName.maxLength)
        #expect(long.hasSuffix("…"))
    }

    @Test("候选：一行一个，清洗后去重，取前 N 个")
    func candidates() {
        let output = """
        以下是候选：
        1. 标签栏｜改描边托盘
        2. 标签栏｜改描边托盘
        3. 标签栏重设计｜托盘加浮起卡片

        4. 顶部标签｜提高对比度
        """
        #expect(SessionName.candidates(from: output, count: 3) == ["标签栏｜改描边托盘", "标签栏重设计｜托盘加浮起卡片", "顶部标签｜提高对比度"])
    }

    @Test("显示时拆成主题和动作：只认全角竖线，代码里的 | 不拆")
    func parts() {
        #expect(SessionName.parts("Codex 配置｜增删中转通道") == .init(topic: "Codex 配置", action: "增删中转通道"))
        #expect(SessionName.parts("ego lite 浏览器") == .init(topic: "ego lite 浏览器", action: nil))
        #expect(SessionName.parts("grep a|b 的用法") == .init(topic: "grep a|b 的用法", action: nil))
    }
}
