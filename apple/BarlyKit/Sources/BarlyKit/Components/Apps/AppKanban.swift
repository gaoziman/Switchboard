import SwiftUI

// MARK: - 应用页面模式：看板（Kanban）
//
// 依据：lovable 应用内页 recruiting-pipeline-tracker（阶段列 + 计数 + 候选人卡）、hireflow、project-management-board、retrofly。
// macOS：多列并排（列宽 272，列间 12，列底 = 比主区深一级的浅灰槽）；iOS：横滑列（列宽 = 屏宽 − 56，露出下一列的边）。
// 卡片走 Card（按风格族换分层），阶段色只出现在列头小圆点上；强调色不进卡片。

/// 平台默认：iOS = 紧凑布局（单列 / 横滑 / 列表 → 详情），macOS = 宽布局。
/// barly-snap 在 macOS 上渲染 iOS 屏，所以 iOS 示例屏显式传 `compact: true`，组件默认值只给真机用。
public enum BarlyPlatform {
    public static var compact: Bool {
        #if os(iOS)
        true
        #else
        false
        #endif
    }
}

public struct KanbanTag: Hashable, Sendable {
    public let text: String
    public let tone: BarlyTone
    public init(_ text: String, tone: BarlyTone = .neutral) { self.text = text; self.tone = tone }
}

public struct KanbanCard: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let detail: String?
    public let tags: [KanbanTag]
    public let people: [String]
    public let due: String?
    public let overdue: Bool
    public let comments: Int
    public let attachments: Int
    /// 0…1 子任务进度（nil = 不显示）
    public let progress: Double?
    public let progressLabel: String?
    public init(_ id: String, _ title: String, detail: String? = nil, tags: [KanbanTag] = [], people: [String] = [],
                due: String? = nil, overdue: Bool = false, comments: Int = 0, attachments: Int = 0,
                progress: Double? = nil, progressLabel: String? = nil) {
        self.id = id; self.title = title; self.detail = detail; self.tags = tags; self.people = people
        self.due = due; self.overdue = overdue; self.comments = comments; self.attachments = attachments
        self.progress = progress; self.progressLabel = progressLabel
    }
}

public struct KanbanColumn: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let tone: BarlyTone
    public let cards: [KanbanCard]
    /// 列头右侧的「n / 上限」（WIP），nil = 只显示数量
    public let limit: Int?
    public init(_ id: String, _ title: String, tone: BarlyTone = .neutral, limit: Int? = nil, cards: [KanbanCard]) {
        self.id = id; self.title = title; self.tone = tone; self.limit = limit; self.cards = cards
    }
}

/// 看板：macOS 列并排、iOS 横滑。selected = 高亮的卡片 id（拖动中 / 打开详情）
public struct KanbanBoard: View {
    let columns: [KanbanColumn]
    let compact: Bool
    let columnWidth: CGFloat?
    let selected: String?
    @Environment(\.barly) private var t
    public init(_ columns: [KanbanColumn], compact: Bool = BarlyPlatform.compact, columnWidth: CGFloat? = nil, selected: String? = nil) {
        self.columns = columns; self.compact = compact; self.columnWidth = columnWidth; self.selected = selected
    }
    public var body: some View {
        let w = columnWidth ?? (compact ? 300 : 272)
        BarlyScroll(.horizontal) {
            HStack(alignment: .top, spacing: compact ? 10 : 12) {
                ForEach(columns) { c in
                    KanbanColumnView(c, compact: compact, selected: selected).frame(width: w)
                }
            }
            .padding(.horizontal, compact ? BarlyMetrics.pageX : 0)
        }
    }
}

public struct KanbanColumnView: View {
    let column: KanbanColumn
    let compact: Bool
    let selected: String?
    @Environment(\.barly) private var t
    public init(_ column: KanbanColumn, compact: Bool = BarlyPlatform.compact, selected: String? = nil) {
        self.column = column; self.compact = compact; self.selected = selected
    }

    /// 列底：Barly / noir = 浅灰槽；线框族不画槽，只靠列头下的线分列；soft = 粉彩奶油块
    private var trough: Color {
        switch BarlyFamily.current.surface {
        case .outline: t.isDark ? t.bgSubtle.barlyMix(t.surface, 0.3) : t.bgSubtle
        case .filled: t.bgSubtle
        case .block: t.paper
        default: .clear
        }
    }
    private var troughPad: CGFloat { trough == .clear ? 0 : 8 }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle().fill(dot).frame(width: 7, height: 7)
                Text(column.title).barlyText(compact ? .mobile.label.weight(500) : .product.cardTitle, color: t.text)
                // 计数小方块（recruiting-pipeline 列头的计数徽标），满 WIP 上限时变警示色
                let full = column.limit.map { column.cards.count >= $0 } ?? false
                Text(column.limit.map { "\(column.cards.count)/\($0)" } ?? "\(column.cards.count)")
                    .barlyText(FamilyType.numeric(BarlyTokens.Product.caption.weight(500)), color: full ? t.warningFg : t.text2)
                    .padding(.horizontal, 6).frame(minWidth: 20).frame(height: 20)
                    .background(RoundedRectangle(cornerRadius: BarlyRadius.xs, style: .continuous).fill(full ? t.warningSoft : (t.isDark ? t.fill2 : t.surface)))
                Spacer()
                BarlyIcon("plus", size: 14, color: t.text3)
                BarlyIcon("ellipsis", size: 14, color: t.text3)
            }
            .padding(.horizontal, 4)
            .frame(height: 30)
            .overlay(alignment: .bottom) { if trough == .clear { Rectangle().fill(t.borderStrong).frame(height: 1).offset(y: 4) } }
            .padding(.bottom, trough == .clear ? 8 : 0)
            ForEach(column.cards) { c in KanbanCardView(c, compact: compact, selected: c.id == selected) }
            if column.cards.isEmpty {
                Text("Drop cards here").barlyText(.product.caption, color: t.text3)
                    .frame(maxWidth: .infinity).frame(height: 72)
                    .overlay(RoundedRectangle(cornerRadius: BarlyRadius.md, style: .continuous)
                        .strokeBorder(t.borderStrong, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
            }
            HStack(spacing: 6) {
                BarlyIcon("plus", size: 13, color: t.text3)
                Text("Add card").barlyText(.product.caption, color: t.text3)
            }
            .padding(.horizontal, 6).frame(height: 30)
        }
        .padding(troughPad)
        .background(RoundedRectangle(cornerRadius: BarlyRadius.lg, style: .continuous).fill(trough))
    }

    private var dot: Color {
        switch column.tone {
        case .neutral: t.text4
        case .success: t.success
        case .danger: t.danger
        case .warning: t.warning
        case .info: t.info
        case .accent: t.accent
        }
    }
}

public struct KanbanCardView: View {
    let card: KanbanCard
    let compact: Bool
    let selected: Bool
    @Environment(\.barly) private var t
    public init(_ card: KanbanCard, compact: Bool = BarlyPlatform.compact, selected: Bool = false) {
        self.card = card; self.compact = compact; self.selected = selected
    }
    public var body: some View {
        Card(padding: 12, radius: BarlyRadius.md, fill: BarlyFamily.current.surface == .rule ? t.bg : nil) {
            VStack(alignment: .leading, spacing: 10) {
                if !card.tags.isEmpty {
                    HStack(spacing: 6) { ForEach(card.tags, id: \.self) { Chip($0.text, tone: $0.tone) } }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(card.title).barlyText(compact ? .mobile.label.weight(500) : .product.body.weight(500), color: t.text)
                        .fixedSize(horizontal: false, vertical: true)
                    if let d = card.detail {
                        Text(d).barlyText(.product.caption, color: t.text2).lineLimit(2)
                    }
                }
                if let p = card.progress {
                    HStack(spacing: 8) {
                        ProgressBar(p, height: 4, color: p >= 1 ? t.success : t.dataBase)
                        Text(card.progressLabel ?? "\(Int(p * 100))%").barlyText(FamilyType.numeric(BarlyTokens.Product.caption), color: t.text3)
                    }
                }
                HStack(spacing: 10) {
                    if let due = card.due {
                        HStack(spacing: 4) {
                            BarlyIcon("calendar", size: 12, color: card.overdue ? t.danger : t.text3)
                            Text(due).barlyText(.product.caption, color: card.overdue ? t.danger : t.text3)
                        }
                    }
                    if card.comments > 0 { meta("bubble.left", "\(card.comments)") }
                    if card.attachments > 0 { meta("paperclip", "\(card.attachments)") }
                    Spacer(minLength: 0)
                    if !card.people.isEmpty { AvatarStack(card.people, size: 20) }
                }
            }
        }
        .overlay {
            if selected {
                RoundedRectangle(cornerRadius: BarlyRadius.md, style: .continuous).strokeBorder(t.selectedFg, lineWidth: 1.5)
            }
        }
        .shadow(color: selected && !t.isDark ? .black.opacity(0.08) : .clear, radius: 10, y: 6)
        .rotationEffect(.degrees(selected ? -1.2 : 0))
    }

    private func meta(_ icon: String, _ v: String) -> some View {
        HStack(spacing: 4) {
            BarlyIcon(icon, size: 12, color: t.text3)
            Text(v).barlyText(FamilyType.numeric(BarlyTokens.Product.caption), color: t.text3)
        }
    }
}
