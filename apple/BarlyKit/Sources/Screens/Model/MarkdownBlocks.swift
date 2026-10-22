import Foundation

/// 回复里的 Markdown 拆成块：标题、段落、列表、表格、代码、引用、分隔线。
/// 行内语法（加粗、行内代码、链接）留在块的文字里，显示时再交给 AttributedString
public enum MarkdownBlocks {
    public enum Block: Hashable, Sendable {
        case heading(Int, String)
        case paragraph(String)
        case bullets([String])
        case numbered(start: Int, [String])
        case table(header: [String], rows: [[String]])
        case code(language: String, String)
        case quote(String)
        case rule
    }

    public static func parse(_ text: String) -> [Block] {
        var out: [Block] = []
        var lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")[...]
        var paragraph: [String] = []
        func flush() {
            if !paragraph.isEmpty { out.append(.paragraph(paragraph.joined(separator: "\n"))); paragraph = [] }
        }

        while let line = lines.popFirst() {
            let l = line.trimmingCharacters(in: .whitespaces)
            if l.isEmpty { flush(); continue }

            // 围栏代码：原样保留缩进，没闭合就读到结尾
            if l.hasPrefix("```") {
                flush()
                let language = String(l.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var code: [String] = []
                while let c = lines.popFirst() {
                    if c.trimmingCharacters(in: .whitespaces).hasPrefix("```") { break }
                    code.append(c)
                }
                out.append(.code(language: language, code.joined(separator: "\n")))
                continue
            }
            if let level = heading(l) {
                flush()
                out.append(.heading(level, String(l.dropFirst(level)).trimmingCharacters(in: .whitespaces)))
                continue
            }
            if l == "---" || l == "***" || l == "___" { flush(); out.append(.rule); continue }
            if let item = bullet(l) {
                flush()
                var items = [item]
                while let next = lines.first, let i = bullet(next.trimmingCharacters(in: .whitespaces)) { items.append(i); lines.removeFirst() }
                out.append(.bullets(items))
                continue
            }
            if let (n, item) = numbered(l) {
                flush()
                var items = [item]
                while let next = lines.first, let (_, i) = numbered(next.trimmingCharacters(in: .whitespaces)) { items.append(i); lines.removeFirst() }
                out.append(.numbered(start: n, items))
                continue
            }
            if l.hasPrefix("|") {
                flush()
                var rows = [cells(l)]
                while let next = lines.first?.trimmingCharacters(in: .whitespaces), next.hasPrefix("|") { rows.append(cells(next)); lines.removeFirst() }
                rows.removeAll { row in row.allSatisfy { cell in !cell.isEmpty && cell.allSatisfy { "-:".contains($0) } } }
                if let header = rows.first { out.append(.table(header: header, rows: Array(rows.dropFirst()))) }
                continue
            }
            if l.hasPrefix(">") {
                flush()
                var quoted = [quote(l)]
                while let next = lines.first?.trimmingCharacters(in: .whitespaces), next.hasPrefix(">") { quoted.append(quote(next)); lines.removeFirst() }
                out.append(.quote(quoted.joined(separator: "\n")))
                continue
            }
            paragraph.append(l)
        }
        flush()
        return out
    }

    /// 「## 标题」的级别（# 后面要有空格，# 开头的普通文字不算）
    private static func heading(_ l: String) -> Int? {
        let n = l.prefix { $0 == "#" }.count
        guard (1...6).contains(n), l.dropFirst(n).first == " " else { return nil }
        return n
    }

    private static func bullet(_ l: String) -> String? {
        for p in ["- ", "* ", "• "] where l.hasPrefix(p) { return String(l.dropFirst(p.count)) }
        return nil
    }

    private static func numbered(_ l: String) -> (Int, String)? {
        let digits = l.prefix { $0.isASCII && $0.isNumber }
        guard !digits.isEmpty, digits.count <= 3, let n = Int(digits) else { return nil }
        let rest = l.dropFirst(digits.count)
        guard rest.hasPrefix(". ") || rest.hasPrefix(") ") else { return nil }
        return (n, String(rest.dropFirst(2)))
    }

    private static func cells(_ l: String) -> [String] {
        var s = Substring(l)
        if s.hasPrefix("|") { s = s.dropFirst() }
        if s.hasSuffix("|") { s = s.dropLast() }
        return s.split(separator: "|", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func quote(_ l: String) -> String {
        String(l.dropFirst()).trimmingCharacters(in: .whitespaces)
    }
}
