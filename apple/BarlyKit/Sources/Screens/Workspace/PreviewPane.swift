import SwiftUI
import BarlyKit
#if os(macOS)
import AppKit
#endif

/// 对话预览（时间线）：不启动 CLI 直接读会话。页头（项目 · 标题 · 口径行 · 分叉 / 接着跑）→ 统计条（几轮 · 几次工具 ·
/// 几分钟 · 几个文件 | 全部 / 只看对话 / 只看工具）→ 时间线：左边时间，一根竖线串起每一步——你的话是强调色圆环，
/// 每个工具一行（图标 · 名字 · 参数），回复是实心小点、正文按 Markdown 排版
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
    @AppStorage("previewTextSize") private var textSize: Double = 14
    @State private var filter: TimelineFilter = .all
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
        // 当前命中算一次：放进 ForEach 里的话每一条都把全部条目查一遍（几千条就是几百万次查找）
        let current = currentMatch
        let rows = TimelineRow.rows(filter.apply(entries))
        VStack(spacing: 0) {
            header
            statsBar
            if findOpen { findBar; Hairline() }
            ScrollViewReader { proxy in
            BarlyScroll {
                // 懒加载：几千条消息时只建屏幕上的
                LazyVStack(alignment: .leading, spacing: 0) {
                    if folderMissing { missingFolderNote.padding(.bottom, 16) }
                    if hasEarlier {
                        BarlyButton(L("加载更早的消息"), icon: "arrow.up", variant: .ghost, size: .sm, action: onLoadEarlier)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.bottom, 12)
                    }
                    if entries.isEmpty {
                        Text("这个会话还没有可显示的消息。").barlyText(.product.small, color: t.text3)
                    }
                    ForEach(rows) { row in
                        switch row {
                        case .day(let date):
                            DayMarker(date: date)
                        case .entry(let entry):
                            TimelineEntry(entry: entry, textSize: textSize, highlight: activeQuery, isCurrent: entry.id == current)
                                .id(entry.id)
                        }
                    }
                    Text("最新消息 · \(RelativeAge.format(session.lastActivity))")
                        .barlyText(.product.caption, color: t.text4)
                        .padding(.leading, TimelineMetrics.contentX)
                        .padding(.top, 14)
                }
                .frame(maxWidth: 1000, alignment: .leading)
                .padding(.horizontal, 28)
                .padding(.top, 18).padding(.bottom, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: current) { _, id in
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
        #if os(macOS)
        // 回复里的 Markdown 链接可能被提示注入、主机镜像过来的会话也可能被改过：和终端 ⌘-点按走同一套白名单，不交给系统直接打开
        .environment(\.openURL, OpenURLAction { url in
            LinkOpener.open(url.absoluteString, relativeTo: session.projectPath, remote: !(host?.isLocal ?? true))
            return .handled
        })
        #endif
    }

    // MARK: 页头

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: (host?.isLocal ?? true) ? "folder" : "server.rack").font(.system(size: BarlyScale.pt(11)))
                    Text(kicker).lineLimit(1)
                }
                .barlyText(.product.caption, color: t.text3)
                Text(session.displayTitle)
                    .barlyText(.product.sectionTitle.weight(600), color: t.text)
                    .lineLimit(1)
                HStack(spacing: 14) {
                    meta("clock", L("\(RelativeAge.format(session.lastActivity)) 前活跃"))
                    meta("text.bubble", L("\(session.messageCount) 条消息"))
                    if let model = session.model { meta("cpu", model) }
                    if let p = project {
                        Text(p.shortPath).barlyText(.product.caption.monospaced, color: t.text4)
                            .lineLimit(1).truncationMode(.head)
                            .help("\(p.path)\n\(L("会话")) \(session.id)")
                    }
                }
            }
            Spacer(minLength: 12)
            HStack(spacing: 6) {
                PaneIcon(symbol: "magnifyingglass", help: L("在对话里查找（⌘F）"), action: openFind)
                if let menu {
                    Menu { menu() } label: {
                        Image(systemName: "ellipsis").font(.system(size: BarlyScale.pt(14))).foregroundStyle(t.text2)
                            .frame(width: BarlyScale.pt(28), height: BarlyScale.pt(28))
                            .contentShape(Rectangle())
                    }
                    .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
                    .handCursor()
                    .help(L("更多"))
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
        .padding(.horizontal, 28)
        .padding(.top, 18).padding(.bottom, 14)
    }

    /// 「项目 · Claude Code」：SSH 主机上的会话前面是主机名
    private var kicker: String {
        let hostPart = (host?.isLocal ?? true) ? "" : "\(host?.displayName ?? "") / "
        return hostPart + [project?.name, session.cli.title].compactMap { $0 }.joined(separator: "  ·  ")
    }

    private func meta(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: BarlyScale.pt(10)))
            Text(verbatim: text).lineLimit(1)
        }
        .barlyText(.product.caption, color: t.text3)
        .fixedSize()
    }

    // MARK: 统计条

    private var statsBar: some View {
        let s = TranscriptStats(entries)
        return HStack(spacing: 18) {
            stat(s.rounds, L("轮对话"))
            stat(s.tools, L("次工具"))
            if s.minutes > 0 { stat(s.minutes, L("分钟")) }
            if s.filesChanged > 0 { stat(s.filesChanged, L("个文件改动")) }
            if hasEarlier { Text("只算已加载的").barlyText(.product.caption, color: t.text4) }
            Spacer(minLength: 12)
            FilterSwitch(selection: $filter)
            Menu {
                Button("放大字号") { textSize = min(22, textSize + 1) }
                Button("缩小字号") { textSize = max(12, textSize - 1) }
                Button("恢复默认字号") { textSize = 14 }
            } label: {
                Image(systemName: "textformat.size").font(.system(size: BarlyScale.pt(13))).foregroundStyle(t.text2)
                    .frame(width: BarlyScale.pt(28), height: BarlyScale.pt(28))
                    .contentShape(Rectangle())
            }
            .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
            .handCursor()
            .help(L("字号（\(Int(textSize))）"))
        }
        .padding(.horizontal, 28)
        .frame(height: BarlyScale.pt(44))
        .overlay(alignment: .top) { Hairline() }
        .overlay(alignment: .bottom) { Hairline() }
    }

    private func stat(_ n: Int, _ label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("\(n)").barlyText(.product.small.monospaced.weight(500), color: t.text)
            Text(verbatim: label).barlyText(.product.caption, color: t.text3)
        }
        .fixedSize()
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
                Image(systemName: "magnifyingglass").font(.system(size: BarlyScale.pt(11))).foregroundStyle(t.text3)
                TextField("在对话里查找", text: $findQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: BarlyScale.pt(13)))
                    .focused($findFocused)
                    .onSubmit { step(NSEvent.modifierFlags.contains(.shift) ? -1 : 1) }
                    .onChange(of: findQuery) { _, _ in findIndex = 0 }
                Text(verbatim: findQuery.isEmpty ? "" : (n == 0 ? L("无结果") : "\(min(findIndex, n - 1) + 1) / \(n)"))
                    .barlyText(.product.caption.monospaced, color: t.text3)
            }
            .padding(.horizontal, 8)
            .frame(width: BarlyScale.pt(300), height: BarlyScale.pt(28))
            .background(t.fieldBg, in: RoundedRectangle(cornerRadius: BarlyRadius.sm, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: BarlyRadius.sm, style: .continuous).stroke(t.borderStrong, lineWidth: 1))
            PaneIcon(symbol: "chevron.up", help: L("上一个（⇧⌘G）")) { step(-1) }
            PaneIcon(symbol: "chevron.down", help: L("下一个（⌘G）")) { step(1) }
            Spacer()
            if hasEarlier { Text("只搜已经加载的消息").barlyText(.product.caption, color: t.text4) }
            PaneIcon(symbol: "xmark", help: L("关闭查找（Esc）")) { findOpen = false; findQuery = "" }
        }
        .padding(.horizontal, 24)
        .frame(height: BarlyScale.pt(44))
        .onExitCommand { findOpen = false; findQuery = "" }
    }

    private var missingFolderNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "questionmark.folder").font(.system(size: BarlyScale.pt(13))).foregroundStyle(t.warning)
            VStack(alignment: .leading, spacing: 4) {
                Text("原来的文件夹不在了").barlyText(.product.small.weight(500), color: t.text)
                Text("这个会话在 \(project?.shortPath ?? "") 里运行过，文件夹被移走、改名或删除了。把它移回原处才能接着跑或分叉，回到 Switchboard 时会重新检查。")
                    .barlyText(.product.small, color: t.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.warning.opacity(0.08), in: RoundedRectangle(cornerRadius: BarlyRadius.md, style: .continuous))
    }
}

// MARK: - 时间线

enum TimelineMetrics {
    /// 左边时间一栏
    static let timeWidth: CGFloat = 52
    /// 竖线和节点那一栏
    static let railWidth: CGFloat = 14
    /// 正文离节点
    static let gap: CGFloat = 18
    static var contentX: CGFloat { timeWidth + railWidth + gap }
}

/// 时间线上的一行：跨天时插一行日期
enum TimelineRow: Identifiable {
    case day(Date)
    case entry(TranscriptEntry)

    var id: String {
        switch self {
        case .day(let d): "day-\(Int(d.timeIntervalSince1970))"
        case .entry(let e): "entry-\(e.id)"
        }
    }

    static func rows(_ entries: [TranscriptEntry]) -> [TimelineRow] {
        var out: [TimelineRow] = []
        var lastDay: Date?
        let cal = Calendar.current
        for e in entries {
            let day = cal.startOfDay(for: e.time)
            if e.time > .distantPast, day != lastDay {
                // 第一条前面不插今天：只有内容跨天、或者不是今天时才标
                if lastDay != nil || !cal.isDateInToday(e.time) { out.append(.day(day)) }
                lastDay = day
            }
            out.append(.entry(e))
        }
        return out
    }
}

/// 跨天的日期：「10月21日 星期二」，和时间栏对齐
private struct DayMarker: View {
    let date: Date
    @Environment(\.barly) private var t

    var body: some View {
        HStack(spacing: 10) {
            Text(label).barlyText(.product.caption.weight(500), color: t.text3)
            Rectangle().fill(t.hairline).frame(height: 1)
        }
        .padding(.vertical, 12)
    }

    private var label: String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return L("今天") }
        if cal.isDateInYesterday(date) { return L("昨天") }
        let f = DateFormatter()
        f.locale = Locale.current
        f.setLocalizedDateFormatFromTemplate(cal.isDate(date, equalTo: .now, toGranularity: .year) ? "MMMdEEEE" : "yMMMdEEEE")
        return f.string(from: date)
    }
}

/// 一条：时间 | 竖线 + 节点 | 内容
private struct TimelineEntry: View {
    let entry: TranscriptEntry
    let textSize: CGFloat
    var highlight: String?
    var isCurrent = false
    @Environment(\.barly) private var t

    var body: some View {
        switch entry.kind {
        case .user(let text):
            rail(time: true, node: AnyView(Circle().strokeBorder(t.accent, lineWidth: 2).frame(width: 12, height: 12))) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("你").barlyText(.product.caption.weight(500), color: t.accent)
                    Text(TranscriptHighlight.mark(AttributedString(text), query: highlight, current: isCurrent, palette: t))
                        .barlyText(.product.body.size(textSize + 1).weight(500).leading((textSize + 1) * 1.55), color: t.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                .padding(.top, 2).padding(.bottom, 14)
            }
            .padding(.top, 10)
        case .assistant(let text):
            rail(node: AnyView(Circle().fill(t.text2).frame(width: 8, height: 8))) {
                MarkdownView(blocks: MarkdownBlocks.parse(text), size: textSize, highlight: highlight, current: isCurrent)
                    .padding(.top, 2).padding(.bottom, 16)
            }
        case .tools(let calls):
            ToolRun(calls: calls, highlight: highlight)
        case .code(let language, let code):
            rail(node: AnyView(EmptyView())) {
                TranscriptCode(language: language, code: code, size: textSize - 1).padding(.bottom, 16)
            }
        case .image(let caption):
            rail(node: AnyView(RoundedRectangle(cornerRadius: 2).fill(t.text3).frame(width: 8, height: 8))) {
                HStack(spacing: 8) {
                    Image(systemName: "photo").font(.system(size: BarlyScale.pt(12))).foregroundStyle(t.text3)
                    Text(caption).barlyText(.product.caption, color: t.text3)
                }
                .padding(.horizontal, 10).frame(height: BarlyScale.pt(28))
                .background(t.shellHover, in: RoundedRectangle(cornerRadius: BarlyRadius.sm, style: .continuous))
                .padding(.bottom, 14)
            }
        }
    }

    private func rail<C: View>(time: Bool = false, node: AnyView, @ViewBuilder _ content: () -> C) -> some View {
        TimelineRail(time: time ? entry.time : nil, node: node, content: content())
    }
}

/// 时间 | 竖线 + 节点 | 内容。竖线铺满这一行的高度，相邻行连成一根
private struct TimelineRail<Content: View>: View {
    let time: Date?
    let node: AnyView
    let content: Content
    var nodeTop: CGFloat = 6
    @Environment(\.barly) private var t

    /// 时间栏固定 24 小时制「14:32」：中文区域的「下午2:32」放不进这一栏
    private static var clock: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(time.map { Self.clock.string(from: $0) } ?? "")
                .barlyText(.product.caption.monospaced, color: t.text4)
                .frame(width: TimelineMetrics.timeWidth, alignment: .leading)
                .padding(.top, nodeTop - 1)
            ZStack(alignment: .top) {
                Rectangle().fill(t.hairline).frame(width: 1.5).frame(maxHeight: .infinity)
                node.padding(.top, nodeTop)
                    .padding(.vertical, 2).background(t.canvas)
            }
            .frame(width: TimelineMetrics.railWidth)
            content
                .padding(.leading, TimelineMetrics.gap)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// 一串工具调用：每个一行（图标 · 名字 · 参数）。超过 6 个先收起前 5 个，「还有 N 个」点开
private struct ToolRun: View {
    let calls: [ToolCall]
    var highlight: String?
    @State private var expanded = false
    @Environment(\.barly) private var t

    private static let collapsedCount = 5

    var body: some View {
        let shown = expanded || calls.count <= Self.collapsedCount + 1 ? calls : Array(calls.prefix(Self.collapsedCount))
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(shown.enumerated()), id: \.offset) { _, call in
                TimelineRail(time: nil, node: AnyView(Circle().fill(t.text4).frame(width: 5, height: 5)), content: row(call), nodeTop: 10)
            }
            if shown.count < calls.count {
                TimelineRail(time: nil, node: AnyView(EmptyView()), content:
                    Button { withAnimation(.easeOut(duration: 0.15)) { expanded = true } } label: {
                        Text("还有 \(calls.count - shown.count) 个工具调用").barlyText(.product.caption.weight(500), color: t.accent)
                            .frame(height: BarlyScale.pt(26))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .handCursor()
                )
            }
        }
        .padding(.bottom, 8)
    }

    private func row(_ call: ToolCall) -> some View {
        HStack(spacing: 10) {
            Image(systemName: Self.icon(call.name)).font(.system(size: BarlyScale.pt(11))).foregroundStyle(t.text3)
                .frame(width: 16)
            Text(call.name).barlyText(.product.caption.weight(500), color: t.text2)
                .lineLimit(1).frame(width: 64, alignment: .leading)
            Text(TranscriptHighlight.mark(AttributedString(call.arg), query: highlight, current: false, palette: t))
                .barlyText(.product.caption.monospaced, color: t.text3)
                .lineLimit(1).truncationMode(.tail)
                .help(call.arg)
        }
        .frame(height: BarlyScale.pt(26))
    }

    /// 每种工具一个 SF Symbol；认不出的用扳手
    static func icon(_ name: String) -> String {
        switch name.lowercased() {
        case "bash", "shell", "local_shell", "exec_command", "bashoutput": "terminal"
        case "read", "view", "notebookread": "doc.text"
        case "edit", "multiedit", "apply_patch", "notebookedit": "pencil"
        case "write", "create": "square.and.pencil"
        case "grep", "glob", "search", "ls", "list": "magnifyingglass"
        case "webfetch", "websearch", "fetch": "globe"
        case "task", "agent": "person.2"
        case "todowrite", "todo": "checklist"
        default: "wrench.and.screwdriver"
        }
    }
}

/// 「全部 | 只看对话 | 只看工具」：槽 + 亮一档的滑块（和侧栏的分段一样）
private struct FilterSwitch: View {
    @Binding var selection: TimelineFilter
    @Environment(\.barly) private var t

    var body: some View {
        HStack(spacing: 2) {
            ForEach(TimelineFilter.allCases, id: \.self) { f in
                let on = selection == f
                Button { selection = f } label: {
                    Text(verbatim: f.title).barlyText(.product.caption.weight(on ? 500 : 400), color: on ? t.text : t.text3)
                        .padding(.horizontal, 10)
                        .frame(height: BarlyScale.pt(24))
                        .background(on ? t.shellSelected : .clear, in: RoundedRectangle(cornerRadius: WorkspaceMetrics.rowRadius, style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .handCursor()
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(2)
        .background(t.shellBase.opacity(t.isDark ? 0.7 : 1), in: RoundedRectangle(cornerRadius: WorkspaceMetrics.trackRadius, style: .continuous))
    }
}
