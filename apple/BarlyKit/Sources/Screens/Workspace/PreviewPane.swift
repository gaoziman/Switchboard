import SwiftUI
import BarlyKit
#if os(macOS)
import AppKit
#endif

/// 对话预览：不启动 CLI 直接读会话。页头（面包屑 · 标题 · 口径行 · Resume / 分叉）→ 阅读工具条 → 对话列
public struct PreviewPane: View {
    let session: Session
    let project: Project?
    let host: Host?
    let entries: [TranscriptEntry]
    /// 查找中的词：命中处加底色
    var highlight: String?
    var onResume: () -> Void = {}
    var onBranch: () -> Void = {}
    /// 「更多」菜单的内容（和侧栏右键一样）
    var menu: (() -> AnyView)?
    /// 文件只读了尾部：显示「加载更早的消息」
    var hasEarlier = false
    var onLoadEarlier: () -> Void = {}
    @Environment(\.barly) private var t
    #if os(macOS)
    @Environment(\.controlActiveState) private var controlActiveState
    #endif
    @State private var textSize: CGFloat = 14
    @State private var findOpen = false
    @State private var findQuery = ""
    @State private var findIndex = 0
    @FocusState private var findFocused: Bool
    /// 原型截图用：固定当前命中在哪一条
    var fixtureCurrentMatch: Int? = nil

    /// 命中的条目（按顺序）
    private var matchIDs: [Int] {
        let q = (findOpen ? findQuery : highlight ?? "").trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        return entries.filter { $0.searchableText.range(of: q, options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]) != nil }.map(\.id)
    }

    private var currentMatch: Int? {
        if let fixtureCurrentMatch { return fixtureCurrentMatch }
        let ids = matchIDs
        return ids.isEmpty ? nil : ids[min(findIndex, ids.count - 1)]
    }

    private var activeQuery: String? {
        let q = findOpen ? findQuery : (highlight ?? "")
        return q.trimmingCharacters(in: .whitespaces).isEmpty ? nil : q
    }

    public init(session: Session, project: Project?, host: Host?, entries: [TranscriptEntry], highlight: String? = nil,
                onResume: @escaping () -> Void = {}, onBranch: @escaping () -> Void = {},
                menu: (() -> AnyView)? = nil, hasEarlier: Bool = false, onLoadEarlier: @escaping () -> Void = {},
                fixtureCurrentMatch: Int? = nil) {
        self.fixtureCurrentMatch = fixtureCurrentMatch
        self.menu = menu
        self.hasEarlier = hasEarlier
        self.onLoadEarlier = onLoadEarlier
        self.session = session
        self.project = project
        self.host = host
        self.entries = entries
        self.highlight = highlight
        self.onResume = onResume
        self.onBranch = onBranch
    }

    private var folderMissing: Bool { project?.folderExists == false }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Hairline()
            readingBar
            Hairline()
            if findOpen { findBar; Hairline() }
            ScrollViewReader { proxy in
            BarlyScroll {
                VStack(alignment: .leading, spacing: 18) {
                    if folderMissing { missingFolderNote }
                    if hasEarlier {
                        BarlyButton(L("加载更早的消息"), icon: "arrow.up", variant: .ghost, size: .sm, action: onLoadEarlier)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    if entries.isEmpty {
                        Text("这个会话还没有可显示的消息。").barlyText(.product.small, color: t.text3)
                    }
                    ForEach(entries) { EntryView(entry: $0, textSize: textSize, highlight: activeQuery, isCurrent: $0.id == currentMatch).id($0.id) }
                    Text("— 最新消息 · \(RelativeAge.format(session.lastActivity)) —")
                        .barlyText(.product.caption.monospaced, color: t.text4)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)
                }
                .frame(maxWidth: 760, alignment: .leading)
                .padding(.horizontal, 48)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: currentMatch) { _, id in
                if let id { withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .center) } }
            }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchboardFindInPreview)) { note in
            #if os(macOS)
            guard controlActiveState == .key else { return }
            #endif
            switch note.object as? Int {
            case 2: step(1)
            case 3: step(-1)
            default: openFind()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(t.canvas)
    }

    // MARK: 页头

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                MonoLabel(breadcrumb, color: t.text3)
                HStack(spacing: 10) {
                    CLIMark(session.cli, size: 20)
                    Text(session.displayTitle)
                        .barlyText(.product.pageTitle, color: t.text)
                        .lineLimit(1)
                }
                Text(meta).barlyText(.product.caption.monospaced, color: t.text3)
            }
            Spacer(minLength: 12)
            HStack(spacing: 8) {
                if let menu {
                    Menu { menu() } label: {
                        Label("更多", systemImage: "ellipsis").barlyText(.product.small, color: t.text2)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .handCursor()
                } else {
                    BarlyButton(L("更多"), icon: "ellipsis", variant: .ghost, size: .sm)
                }
                BarlyButton(L("分叉"), icon: "arrow.triangle.branch", variant: .outline, size: .sm, action: onBranch)
                    .disabled(folderMissing || session.cli.branchArguments(session.id) == nil)
                    .opacity(folderMissing || session.cli.branchArguments(session.id) == nil ? 0.4 : 1)
                    .help(session.cli.branchArguments(session.id) == nil ? "omp 没有直接分叉的参数：接着跑之后在里面用 /fork" : "复制这段对话，开一个新会话")
                BarlyButton(L("接着跑"), icon: "play.fill", variant: .primary, size: .sm, action: onResume)
                    .disabled(folderMissing)
                    .opacity(folderMissing ? 0.4 : 1)
                    .help(folderMissing ? "原来的文件夹不在了" : "在原目录里恢复这个会话（双击会话也可以）")
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 18).padding(.bottom, 16)
    }

    private var breadcrumb: String {
        let hostName = (host?.isLocal ?? true) ? "THIS MAC" : (host?.displayName ?? "")
        return [hostName, project?.name ?? "", session.cli.title].joined(separator: " / ")
    }

    private var meta: String {
        var parts = [session.model, L("\(session.messageCount) 条消息"), L("\(RelativeAge.format(session.lastActivity)) 前活跃"),
                     String(session.id.prefix(8))].compactMap { $0 }
        if let p = project { parts.insert(p.shortPath, at: 0) }
        return parts.joined(separator: "  ·  ")
    }

    // MARK: 阅读工具条

    private var readingBar: some View {
        HStack(spacing: 2) {
            PaneIcon(symbol: "textformat.size.smaller", help: L("缩小字号（⌘−）")) { textSize = max(12, textSize - 1) }
            Text("\(Int(textSize))").barlyText(.product.caption.monospaced, color: t.text3).frame(width: 22)
            PaneIcon(symbol: "textformat.size.larger", help: L("放大字号（⌘+）")) { textSize = min(22, textSize + 1) }
            divider
            PaneIcon(symbol: "arrow.left.and.right", help: L("阅读列宽 / 整窗宽"))
            divider
            PaneIcon(symbol: "arrow.up.to.line", help: L("跳到第一条"))
            PaneIcon(symbol: "arrow.down.to.line", help: L("跳到最新"))
            Spacer()
            PaneIcon(symbol: "magnifyingglass", help: L("在对话里查找（⌘F）"), action: openFind)
            if highlight == nil {
                PaneIcon(symbol: "macwindow.badge.plus", help: L("在独立窗口里阅读"))
            }
        }
        .padding(.horizontal, 16)
        .frame(height: BarlyScale.pt(36))
    }

    private func openFind() {
        findOpen = true
        findFocused = true
    }

    private func step(_ d: Int) {
        let n = matchIDs.count
        guard n > 0 else { return }
        if !findOpen { findOpen = true }
        findIndex = (findIndex + d + n) % n
    }

    /// 查找条：输入框 · 第几个 / 共几个 · 上一个 / 下一个 · 关闭
    private var findBar: some View {
        let n = matchIDs.count
        return HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").font(.system(size: 11)).foregroundStyle(t.text3)
                TextField("在对话里查找", text: $findQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($findFocused)
                    .onSubmit { step(NSEvent.modifierFlags.contains(.shift) ? -1 : 1) }
                    .onChange(of: findQuery) { _, _ in findIndex = 0 }
                Text(verbatim: findQuery.isEmpty ? "" : (n == 0 ? L("无结果") : "\(min(findIndex, n - 1) + 1) / \(n)"))
                    .barlyText(.product.caption.monospaced, color: t.text3)
            }
            .padding(.horizontal, 8)
            .frame(width: BarlyScale.pt(300), height: BarlyScale.pt(28))
            .background(t.fieldBg, in: RoundedRectangle(cornerRadius: BarlyRadius.sm))
            .overlay(RoundedRectangle(cornerRadius: BarlyRadius.sm).stroke(t.text3, lineWidth: 1.5))
            PaneIcon(symbol: "chevron.up", help: L("上一个（⇧⌘G）")) { step(-1) }
            PaneIcon(symbol: "chevron.down", help: L("下一个（⌘G）")) { step(1) }
            Spacer()
            if hasEarlier { Text("只搜已经加载的消息").barlyText(.product.caption, color: t.text4) }
            PaneIcon(symbol: "xmark", help: L("关闭查找（Esc）")) { findOpen = false; findQuery = "" }
        }
        .padding(.horizontal, 12)
        .frame(height: BarlyScale.pt(44))
        .onExitCommand { findOpen = false; findQuery = "" }
    }

    private var divider: some View {
        Rectangle().fill(t.hairline).frame(width: 1, height: 14).padding(.horizontal, 6)
    }

    private var missingFolderNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "questionmark.folder").font(.system(size: 13)).foregroundStyle(t.warning)
            VStack(alignment: .leading, spacing: 4) {
                Text("原来的文件夹不在了").barlyText(.product.small.weight(500), color: t.text)
                Text("这个会话在 \(project?.shortPath ?? "") 里运行过，文件夹被移走、改名或删除了。把它移回原处才能接着跑或分叉，回到 Switchboard 时会重新检查。")
                    .barlyText(.product.small, color: t.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .leading) { Rectangle().fill(t.warning).frame(width: 2) }
        .background(t.warning.opacity(0.08))
    }
}

/// 一条对话：用户消息左侧一根细线，回复是正文，工具调用折叠成一行
private struct EntryView: View {
    let entry: TranscriptEntry
    let textSize: CGFloat
    var highlight: String?
    var isCurrent = false
    @Environment(\.barly) private var t

    var body: some View {
        switch entry.kind {
        case .user(let text):
            VStack(alignment: .leading, spacing: 6) {
                MonoLabel("YOU", color: t.text4)
                Text(marked(AttributedString(text))).barlyText(.product.body.size(textSize).leading(textSize * 1.6), color: t.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, 14)
            .overlay(alignment: .leading) { Rectangle().fill(t.borderStrong).frame(width: 2) }
        case .assistant(let text):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(text.components(separatedBy: "\n").filter { !$0.isEmpty }.enumerated()), id: \.offset) { _, line in
                    Text(markdown(line)).barlyText(.product.body.size(textSize).leading(textSize * 1.65), color: t.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        case .tools(let count, let summary):
            HStack(spacing: 8) {
                Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold)).foregroundStyle(t.text4)
                Text("\(count) TOOL CALLS").barlyText(.product.caption.weight(500).monospaced, color: t.text3)
                Text(summary).barlyText(.product.caption.monospaced, color: t.text4).lineLimit(1)
            }
            .padding(.horizontal, 10)
            .frame(height: BarlyScale.pt(28))
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(RoundedRectangle(cornerRadius: BarlyRadius.xs).stroke(t.hairline))
            .handCursor()
        case .code(let language, let code):
            CodeBlock(language: language, code: code)
        case .image(let caption):
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: BarlyRadius.xs).fill(t.fill1)
                    VStack(spacing: 6) {
                        ForEach(0..<6, id: \.self) { i in
                            HStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 1).fill(t.fill3).frame(width: 90, height: 8)
                                ForEach(0..<4, id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: 1).fill(i == 2 ? t.fill3 : t.fill2).frame(width: 56, height: 8)
                                }
                            }
                        }
                    }
                }
                .frame(width: 420, height: 160)
                .overlay(RoundedRectangle(cornerRadius: BarlyRadius.xs).stroke(t.hairline))
                Text(caption).barlyText(.product.caption, color: t.text3)
            }
        }
    }

    private func markdown(_ s: String) -> AttributedString {
        marked((try? AttributedString(markdown: s, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(s))
    }

    /// 查找命中：琥珀浅底 + 正文色字
    private func marked(_ input: AttributedString) -> AttributedString {
        guard let highlight, !highlight.isEmpty else { return input }
        var out = input
        var search = out.startIndex..<out.endIndex
        var n = 0
        while let r = out[search].range(of: highlight, options: [.caseInsensitive, .diacriticInsensitive]) {
            // 当前命中（原型里固定为第 3 条回复的第一处）：实心琥珀 + 深字；其余浅底
            let current = isCurrent && n == 0
            out[r].backgroundColor = current ? t.warning : t.warning.opacity(0.28)
            out[r].foregroundColor = current ? Color.black : t.text
            search = r.upperBound..<out.endIndex
            n += 1
        }
        return out
    }
}
