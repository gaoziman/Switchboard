import SwiftUI
import BarlyKit
#if os(macOS)
import AppKit
#endif

/// 回复正文：按块排版的 Markdown（标题、列表、表格、代码、引用），行内的加粗 / 代码 / 链接交给 AttributedString。
/// highlight：查找中的词，命中处加底色；current = 当前命中在这一条里
struct MarkdownView: View {
    let blocks: [MarkdownBlocks.Block]
    var size: CGFloat = 14
    var highlight: String?
    var current = false
    @Environment(\.barly) private var t

    var body: some View {
        VStack(alignment: .leading, spacing: size * 0.8) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, b in block(b) }
        }
    }

    private var bodyStyle: BarlyTextStyle { .product.body.size(size).leading(size * 1.65) }

    @ViewBuilder private func block(_ b: MarkdownBlocks.Block) -> some View {
        switch b {
        case .heading(let level, let s):
            Text(inline(s, color: t.text))
                .barlyText(.product.body.size(level <= 2 ? size + 2 : size + 1).weight(600).leading(1.4), color: t.text)
                .padding(.top, size * 0.5)
                .fixedSize(horizontal: false, vertical: true)
        case .paragraph(let s):
            Text(inline(s, color: t.text2)).barlyText(bodyStyle, color: t.text2)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        case .bullets(let items):
            VStack(alignment: .leading, spacing: size * 0.4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Circle().fill(t.text3).frame(width: 4.5, height: 4.5).offset(y: -size * 0.18)
                        Text(inline(item, color: t.text2)).barlyText(bodyStyle, color: t.text2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .textSelection(.enabled)
        case .numbered(let start, let items):
            VStack(alignment: .leading, spacing: size * 0.4) {
                ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(start + i)").barlyText(.product.caption.monospaced.weight(500), color: t.text3)
                            .frame(minWidth: 14, alignment: .trailing)
                        Text(inline(item, color: t.text2)).barlyText(bodyStyle, color: t.text2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .textSelection(.enabled)
        case .table(let header, let rows):
            MarkdownTable(header: header, rows: rows, size: size) { inline($0, color: $1) }
        case .code(let language, let code):
            TranscriptCode(language: language, code: code, size: size - 1)
        case .quote(let s):
            Text(inline(s, color: t.text3)).barlyText(bodyStyle, color: t.text3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 12)
                .overlay(alignment: .leading) { Capsule().fill(t.borderStrong).frame(width: 2) }
        case .rule:
            Rectangle().fill(t.hairline).frame(height: 1).padding(.vertical, 4)
        }
    }

    /// 行内：加粗用正文色 600；行内代码等宽 + 浅底；链接强调色；查找命中加底色
    private func inline(_ s: String, color: Color) -> AttributedString {
        var out = (try? AttributedString(markdown: s, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(s)
        for run in out.runs {
            if let intent = run.inlinePresentationIntent {
                if intent.contains(.code) {
                    out[run.range].font = BarlyFonts.font(BarlyTokens.Font.mono, size: size - 1, weight: 400)
                    out[run.range].foregroundColor = t.text
                    out[run.range].backgroundColor = t.isDark ? Color.white.opacity(0.07) : Color.black.opacity(0.05)
                }
                if intent.contains(.stronglyEmphasized) {
                    out[run.range].font = BarlyFonts.font(BarlyTokens.Font.ui, size: size, weight: 600)
                    out[run.range].foregroundColor = t.text
                }
            }
            if run.link != nil { out[run.range].foregroundColor = t.accent }
        }
        return TranscriptHighlight.mark(out, query: highlight, current: current, palette: t)
    }
}

/// 查找命中：浅琥珀底；当前命中实心琥珀 + 深字
enum TranscriptHighlight {
    static func mark(_ input: AttributedString, query: String?, current: Bool, palette t: BarlyPalette) -> AttributedString {
        guard let query, !query.isEmpty else { return input }
        var out = input
        var search = out.startIndex..<out.endIndex
        var n = 0
        while let r = out[search].range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) {
            let isCurrent = current && n == 0
            out[r].backgroundColor = isCurrent ? t.warning : t.warning.opacity(0.28)
            out[r].foregroundColor = isCurrent ? Color.black : t.text
            search = r.upperBound..<out.endIndex
            n += 1
        }
        return out
    }
}

/// 表格：表头次要色，第一列正文色 500，行间一根细线；外面一圈圆角浅底
private struct MarkdownTable: View {
    let header: [String]
    let rows: [[String]]
    let size: CGFloat
    let inline: (String, Color) -> AttributedString
    @Environment(\.barly) private var t

    var body: some View {
        let columns = max(header.count, rows.map(\.count).max() ?? 0)
        let shape = RoundedRectangle(cornerRadius: BarlyRadius.md, style: .continuous)
        Grid(alignment: .topLeading, horizontalSpacing: 20, verticalSpacing: 0) {
            row(header, columns: columns, isHeader: true)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                Divider().overlay(t.hairline).gridCellUnsizedAxes(.horizontal)
                row(r, columns: columns, isHeader: false)
            }
        }
        .padding(.horizontal, 14)
        .background(t.isDark ? Color.white.opacity(0.025) : Color.black.opacity(0.02), in: shape)
        .overlay(shape.strokeBorder(t.hairline))
        .textSelection(.enabled)
    }

    private func row(_ cells: [String], columns: Int, isHeader: Bool) -> some View {
        GridRow {
            ForEach(0..<columns, id: \.self) { j in
                let cell = j < cells.count ? cells[j] : ""
                let color = isHeader ? t.text3 : (j == 0 ? t.text : t.text2)
                Text(inline(cell, color))
                    .barlyText(.product.body.size(size - 1).weight(isHeader || j == 0 ? 500 : 400).leading(1.5), color: color)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 9)
            }
        }
    }
}

/// 代码块：语言 · 复制（真的复制，点完一秒内显示「已复制」）
struct TranscriptCode: View {
    let language: String
    let code: String
    var size: CGFloat = 13
    @Environment(\.barly) private var t
    @State private var copied = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: BarlyRadius.md, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(language.isEmpty ? L("代码") : language).barlyText(.product.caption.weight(500), color: t.text3)
                Spacer()
                Button {
                    #if os(macOS)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                    #endif
                    copied = true
                    Task { try? await Task.sleep(for: .seconds(1.2)); copied = false }
                } label: {
                    Label(copied ? L("已复制") : L("复制"), systemImage: copied ? "checkmark" : "doc.on.doc")
                        .barlyText(.product.caption, color: copied ? t.accent : t.text3)
                }
                .buttonStyle(.plain)
                .handCursor()
            }
            .padding(.horizontal, 14).frame(height: BarlyScale.pt(32))
            Rectangle().fill(t.hairline).frame(height: 1)
            Text(CodeHighlighter.highlight(code, palette: t))
                .barlyText(.product.small.size(size).monospaced.leading(size * 1.6), color: t.text)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(t.isDark ? Color.black.opacity(0.22) : Color.black.opacity(0.03), in: shape)
        .overlay(shape.strokeBorder(t.hairline))
    }
}
