import Foundation

/// 会话名字的格式：「主题｜动作」（只有主题时就只写主题）。AI 起的名字先过 clean，显示时用 parts 拆成两段（分隔符画成浅灰）。
/// 只认全角竖线做分隔：名字里代码片段的 `|` 不拆
public enum SessionName {
    public static let separator: Character = "｜"
    /// 中文一屏侧栏放得下的长度；再长截断加省略号
    public static let maxLength = 36

    public struct Parts: Equatable, Sendable {
        public let topic: String
        public let action: String?
    }

    public static func parts(_ name: String) -> Parts {
        guard let i = name.firstIndex(of: separator) else { return Parts(topic: name, action: nil) }
        let action = String(name[name.index(after: i)...])
        return Parts(topic: String(name[..<i]), action: action.isEmpty ? nil : action)
    }

    /// 模型输出的一行 → 名字；清洗完什么都不剩就是 nil
    public static func clean(_ raw: String) -> String? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacingOccurrences(of: #"^(?:\d+[.、)）]|[-*•])\s*"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"^(?:标题|名字|名称|title|name)\s*[:：]\s*"#, with: "", options: [.regularExpression, .caseInsensitive])
        s = String(String.UnicodeScalarView(s.unicodeScalars.filter { !isEmoji($0) }))
        let wrappers = CharacterSet(charactersIn: "\"'`“”‘’「」『』《》【】")
        let trailing = CharacterSet(charactersIn: "。.！!；;，,、")
        s = s.trimmingCharacters(in: wrappers.union(.whitespaces))
        while let last = s.unicodeScalars.last, trailing.contains(last) || wrappers.contains(last) {
            s.unicodeScalars.removeLast()
            s = s.trimmingCharacters(in: .whitespaces)
        }
        // 各种竖线统一成全角，前后空格去掉；多出来的分隔符并成空格
        s = s.replacingOccurrences(of: #"\s*[|｜丨]\s*"#, with: String(separator), options: .regularExpression)
        let pieces = s.split(separator: separator, omittingEmptySubsequences: true).map { collapse(String($0)) }.filter { !$0.isEmpty }
        guard let topic = pieces.first else { return nil }
        var name = pieces.count > 1 ? topic + String(separator) + pieces.dropFirst().joined(separator: " ") : topic
        if name.count > maxLength { name = String(name.prefix(maxLength - 1)) + "…" }
        return name
    }

    /// 模型一次给的多个候选：一行一个，「以下是候选：」这种引导行跳过，清洗后去重
    public static func candidates(from output: String, count: Int) -> [String] {
        var seen: [String] = []
        for line in output.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasSuffix(":") || trimmed.hasSuffix("：") { continue }
            if let name = clean(trimmed), !seen.contains(name) { seen.append(name) }
            if seen.count == count { break }
        }
        return seen
    }

    private static func collapse(_ s: String) -> String {
        s.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// 表情和拼表情用的零宽连接符、变体选择符；数字、# 这些「也能当表情」的普通字符不算
    private static func isEmoji(_ scalar: Unicode.Scalar) -> Bool {
        if scalar.value == 0x200D || scalar.value == 0xFE0F { return true }
        return scalar.properties.isEmojiPresentation || (scalar.properties.isEmoji && scalar.value > 0x238C)
    }
}
