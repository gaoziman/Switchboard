import SwiftUI

// MARK: - 应用页面模式：邮件式分栏（列表 + 详情）
//
// 依据：lovable note-taking-app（240 侧栏 + 列表 + 编辑区）、lead-manager / hireflow 候选人详情、Barly AI 对话型的分栏。
// macOS：MailSplit = [可选文件夹栏 220] · 列表栏 360（搜索 + 分段 + 行）· 阅读区（主题大标题 + 发件人 + 正文 + 附件 + 回复框）。
//   在 sidebar / sidebar-gray / rail-list 外壳里外壳侧栏就是文件夹 → 两栏；topnav / rail 下带 folders → 三栏。
// iOS：MailList 列表屏 → MailReader 详情屏（两张示例屏）。
// 未读 = 标题 500 + 6pt 强调色点（状态点是强调色合法位置）；选中行 = 弱底块，不加色条。

public struct MailItem: Identifiable, Sendable {
    public let id: String
    public let from: String
    public let email: String
    public let subject: String
    public let preview: String
    public let time: String
    public let unread: Bool
    public let starred: Bool
    public let tag: KanbanTag?
    public let attachments: [String]
    public let thread: Int
    public init(_ id: String, from: String, email: String = "", subject: String, preview: String, time: String,
                unread: Bool = false, starred: Bool = false, tag: KanbanTag? = nil, attachments: [String] = [], thread: Int = 1) {
        self.id = id; self.from = from; self.email = email; self.subject = subject; self.preview = preview; self.time = time
        self.unread = unread; self.starred = starred; self.tag = tag; self.attachments = attachments; self.thread = thread
    }
}

public struct MailFolder: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let icon: String
    public let count: Int?
    public init(_ id: String, _ title: String, icon: String, count: Int? = nil) { self.id = id; self.title = title; self.icon = icon; self.count = count }
}

/// 列表行：头像 · 发件人 + 时间 / 主题 / 两行预览 · 标签 / 附件
public struct MailRow: View {
    let item: MailItem
    let selected: Bool
    let compact: Bool
    @Environment(\.barly) private var t
    public init(_ item: MailItem, selected: Bool = false, compact: Bool = BarlyPlatform.compact) {
        self.item = item; self.selected = selected; self.compact = compact
    }
    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Avatar(item.from, size: compact ? 40 : 32)
                .overlay(alignment: .topLeading) {
                    if item.unread { Circle().fill(t.accent).frame(width: 7, height: 7).offset(x: -10, y: compact ? 16 : 12) }
                }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.from).barlyText((compact ? BarlyTokens.Mobile.label : BarlyTokens.Product.body).weight(item.unread ? 600 : 500), color: t.text).lineLimit(1)
                    if item.thread > 1 { Text("\(item.thread)").barlyText(FamilyType.numeric(BarlyTokens.Product.caption), color: t.text3) }
                    Spacer(minLength: 4)
                    if item.starred { BarlyIcon("star.fill", size: 11, color: t.warning) }
                    Text(item.time).barlyText(FamilyType.numeric(BarlyTokens.Product.caption), color: item.unread ? t.text : t.text3)
                }
                Text(item.subject).barlyText((compact ? BarlyTokens.Mobile.label : BarlyTokens.Product.body).weight(item.unread ? 500 : 400), color: item.unread ? t.text : t.text2).lineLimit(1)
                Text(item.preview).barlyText(compact ? .mobile.caption : .product.small, color: t.text3).lineLimit(2)
                if item.tag != nil || !item.attachments.isEmpty {
                    HStack(spacing: 6) {
                        if let tag = item.tag { Chip(tag.text, tone: tag.tone) }
                        if let a = item.attachments.first {
                            HStack(spacing: 4) {
                                BarlyIcon("paperclip", size: 11, color: t.text2)
                                Text(a).barlyText(.product.caption, color: t.text2).lineLimit(1)
                            }
                            .padding(.horizontal, 7).frame(height: 22)
                            .overlay(RoundedRectangle(cornerRadius: BarlyRadius.xs, style: .continuous).strokeBorder(t.border, lineWidth: 1))
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(.horizontal, compact ? BarlyMetrics.pageX : 12)
        .padding(.vertical, compact ? 12 : 11)
        .background {
            if selected { RoundedRectangle(cornerRadius: BarlyRadius.md, style: .continuous).fill(t.isDark ? t.fill1 : t.softSurface) }
        }
        .overlay(alignment: .bottom) { if compact { Hairline().padding(.leading, 72) } }
    }
}

/// 列表栏（macOS 360）：标题 + 计数 + 新建 · 搜索 · 分段（All / Unread / Flagged）· 行
public struct MailList: View {
    let title: String
    let items: [MailItem]
    let selected: String?
    let compact: Bool
    @State private var q = ""
    @State private var seg = 0
    @Environment(\.barly) private var t
    public init(_ title: String, items: [MailItem], selected: String? = nil, compact: Bool = BarlyPlatform.compact) {
        self.title = title; self.items = items; self.selected = selected; self.compact = compact
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !compact {
                HStack(spacing: 8) {
                    Text(title).barlyText(FamilyType.pageTitle(), color: t.text)
                    Text("\(items.filter(\.unread).count) unread").barlyText(.product.caption, color: t.text3)
                    Spacer()
                    IconButton("square.and.pencil", size: 32, style: .ghost)
                }
                .padding(.horizontal, 16)
                .frame(height: 64)
                VStack(spacing: 10) {
                    SearchField("Search mail", text: $q, shortcut: "⌘F")
                    Segmented(["All", "Unread", "Flagged"], selection: $seg, height: 32, style: BarlyTokens.Product.caption, fullWidth: true)
                }
                .padding(.horizontal, 16).padding(.bottom, 12)
                Hairline()
            }
            BarlyScroll {
                VStack(spacing: compact ? 0 : 2) {
                    ForEach(items) { MailRow($0, selected: $0.id == selected, compact: compact) }
                }
                .padding(compact ? 0 : 8)
            }
        }
    }
}

/// 阅读区：工具条（归档 / 删除 / 稍后 … 上一封下一封）→ 主题 → 发件人行 → 正文段落 → 附件卡 → 回复框
public struct MailReader: View {
    let item: MailItem
    let body_: [String]
    let compact: Bool
    @State private var reply = ""
    @Environment(\.barly) private var t
    public init(_ item: MailItem, body: [String], compact: Bool = BarlyPlatform.compact) { self.item = item; self.body_ = body; self.compact = compact }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !compact {
                HStack(spacing: 6) {
                    ForEach(["archivebox", "trash", "clock", "folder"], id: \.self) { IconButton($0, size: 32, style: .ghost) }
                    Spacer()
                    Text("3 of 128").barlyText(FamilyType.numeric(BarlyTokens.Product.caption), color: t.text3)
                    IconButton("chevron.up", size: 32, style: .ghost)
                    IconButton("chevron.down", size: 32, style: .ghost)
                }
                .padding(.horizontal, 20).frame(height: 64)
                .overlay(alignment: .bottom) { Hairline() }
            }
            BarlyScroll {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        Text(item.subject).barlyText(FamilyType.pageTitle(compact ? BarlyTokens.Mobile.title.size(22) : BarlyTokens.Product.pageTitle.size(24)), color: t.text)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 12)
                        if let tag = item.tag { Chip(tag.text, tone: tag.tone) }
                    }
                    HStack(spacing: 12) {
                        Avatar(item.from, size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(item.from).barlyText(.product.body.weight(500), color: t.text)
                                Text(verbatim: "<\(item.email)>").barlyText(.product.caption, color: t.text3).lineLimit(1)
                            }
                            Text("to me, Priya Shah").barlyText(.product.caption, color: t.text3)
                        }
                        Spacer()
                        Text(item.time).barlyText(FamilyType.numeric(BarlyTokens.Product.caption), color: t.text3)
                    }
                    .padding(.top, 18)
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(body_.enumerated()), id: \.offset) { _, p in
                            Text(p).barlyText(compact ? .mobile.body.leading(24) : .product.body.size(15).leading(25), color: t.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.top, 24)
                    .frame(maxWidth: 640, alignment: .leading)
                    if !item.attachments.isEmpty {
                        HStack(spacing: 10) {
                            ForEach(item.attachments, id: \.self) { a in
                                HStack(spacing: 10) {
                                    RoundedRectangle(cornerRadius: BarlyRadius.xs, style: .continuous).fill(t.fill1)
                                        .overlay(BarlyIcon(a.hasSuffix(".pdf") ? "doc.richtext" : "tablecells", size: 15, color: t.text2))
                                        .frame(width: 34, height: 34)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(a).barlyText(.product.caption.weight(500), color: t.text).lineLimit(1)
                                        Text(a.hasSuffix(".pdf") ? "PDF · 1.2 MB" : "Sheet · 84 KB").barlyText(.product.caption.size(11), color: t.text3)
                                    }
                                }
                                .padding(8).padding(.trailing, 8)
                                .overlay(RoundedRectangle(cornerRadius: BarlyRadius.md, style: .continuous).strokeBorder(t.border, lineWidth: 1))
                            }
                        }
                        .padding(.top, 24)
                    }
                    // 回复框：白底描边，左下工具，右下发送（发送 = 转化 cta，buttons.md）
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Reply to \(item.from.split(separator: " ").first.map(String.init) ?? item.from)…").barlyText(.product.body, color: t.text3)
                            .frame(maxWidth: .infinity, minHeight: compact ? 44 : 64, alignment: .topLeading)
                        HStack(spacing: 14) {
                            BarlyIcon("paperclip", size: 15, color: t.text3)
                            BarlyIcon("face.smiling", size: 15, color: t.text3)
                            BarlyIcon("barly.sparkle", size: 15, color: t.text3)
                            Spacer()
                            BarlyButton("Send", icon: "paperplane", variant: .cta, size: .sm)
                        }
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: BarlyRadius.lg, style: .continuous).fill(t.fieldBg))
                    .overlay(RoundedRectangle(cornerRadius: BarlyRadius.lg, style: .continuous).strokeBorder(t.fieldBorder, lineWidth: BarlyFamily.current.stroke))
                    .padding(.top, 32)
                }
                .padding(.horizontal, compact ? BarlyMetrics.pageX : 32)
                .padding(.vertical, compact ? 8 : 28)
            }
        }
    }
}

/// 文件夹栏（topnav / rail 外壳下的第一栏）：Compose 按钮 + 文件夹 + 标签
public struct MailFolders: View {
    let folders: [MailFolder]
    let selection: String
    let labels: [KanbanTag]
    @Environment(\.barly) private var t
    public init(_ folders: [MailFolder], selection: String, labels: [KanbanTag] = []) { self.folders = folders; self.selection = selection; self.labels = labels }
    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            BarlyButton("Compose", icon: "square.and.pencil", variant: .primary, size: .md, fullWidth: true).padding(.bottom, 14)
            ForEach(folders) { f in
                let on = f.id == selection
                HStack(spacing: 10) {
                    BarlyIcon(f.icon, size: 15, color: on ? t.text : t.text2)
                    Text(f.title).barlyText(on ? .product.body.weight(500) : .product.body, color: on ? t.text : t.text2)
                    Spacer()
                    if let c = f.count { Text("\(c)").barlyText(FamilyType.numeric(BarlyTokens.Product.caption), color: t.text3) }
                }
                .padding(.horizontal, 10).frame(height: 34)
                .background(RoundedRectangle(cornerRadius: BarlyRadius.sm, style: .continuous).fill(on ? (t.isDark ? t.fill1 : t.softSurface) : .clear))
            }
            if !labels.isEmpty {
                MonoLabel("Labels", color: t.text3).padding(.top, 22).padding(.bottom, 8).padding(.leading, 10)
                ForEach(labels, id: \.self) { l in
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 2).fill(t.toneColors(l.tone).fg.opacity(0.75)).frame(width: 9, height: 9)
                        Text(l.text).barlyText(.product.body, color: t.text2)
                    }
                    .padding(.horizontal, 12).frame(height: 32)
                }
            }
            Spacer()
        }
        .padding(16)
    }
}

/// macOS 分栏：[folders] · 列表 360 · 阅读区
public struct MailSplit: View {
    let title: String
    let folders: [MailFolder]?
    let folderSelection: String
    let labels: [KanbanTag]
    let items: [MailItem]
    let selected: String
    let readerBody: [String]
    @Environment(\.barly) private var t
    public init(_ title: String, folders: [MailFolder]? = nil, folderSelection: String = "inbox", labels: [KanbanTag] = [],
                items: [MailItem], selected: String, readerBody: [String]) {
        self.title = title; self.folders = folders; self.folderSelection = folderSelection; self.labels = labels
        self.items = items; self.selected = selected; self.readerBody = readerBody
    }
    public var body: some View {
        HStack(spacing: 0) {
            if let folders {
                MailFolders(folders, selection: folderSelection, labels: labels)
                    .frame(width: 220).frame(maxHeight: .infinity)
                    .overlay(alignment: .trailing) { Hairline(vertical: true) }
            }
            MailList(title, items: items, selected: selected, compact: false)
                .frame(width: 360).frame(maxHeight: .infinity)
                .overlay(alignment: .trailing) { Hairline(vertical: true) }
            if let item = items.first(where: { $0.id == selected }) {
                MailReader(item, body: readerBody, compact: false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
