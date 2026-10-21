import SwiftUI

// MARK: - 应用页面模式：日历 / 预约（Calendar · Booking）
//
// 依据：deskflow-office-booking（Day/Week/Month 分段 + 时间轴 + 当前时间红线 + 浅色事件块）、
// meeting-booker（顶部导航、事件类型列表、可用时间）、flux（订座 + 日历）、content-calendar。
// macOS：WeekCalendar 周视图（左 56 时间刻度 + 7 列，小时高 56）+ 右侧 BookingPanel（迷你月历 · 可用时段 · 即将开始）；
// iOS：WeekStrip 周条 + DayTimeline 日视图 + SlotGrid 可用时间。
// 事件块 = 语义色淡底 + 同色相深字 + 1px 同色边（不画左侧色条）；当前时间线 = danger 色 1px + 6pt 圆点。

public struct CalEvent: Identifiable, Sendable {
    public let id: String
    /// 周视图里第几天（0 = 周一）；日视图忽略
    public let day: Int
    /// 小时（9.5 = 09:30）
    public let start: Double
    public let end: Double
    public let title: String
    public let detail: String?
    public let tone: BarlyTone
    public let people: [String]
    public init(_ id: String, day: Int = 0, _ start: Double, _ end: Double, _ title: String, detail: String? = nil,
                tone: BarlyTone = .info, people: [String] = []) {
        self.id = id; self.day = day; self.start = start; self.end = end; self.title = title
        self.detail = detail; self.tone = tone; self.people = people
    }
    public var timeLabel: String { "\(CalTime.label(start)) – \(CalTime.label(end))" }
}

public enum CalTime {
    /// 9.5 → "9:30"，13 → "13:00"
    public static func label(_ h: Double, ampm: Bool = false) -> String {
        let hh = Int(h), mm = Int(((h - Double(hh)) * 60).rounded())
        if ampm {
            let h12 = hh % 12 == 0 ? 12 : hh % 12
            return mm == 0 ? "\(h12) \(hh < 12 ? "AM" : "PM")" : String(format: "%d:%02d %@", h12, mm, hh < 12 ? "AM" : "PM")
        }
        return String(format: "%d:%02d", hh, mm)
    }
}

extension BarlyPalette {
    /// 事件块配色：淡底 / 深字 / 边
    func eventColors(_ tone: BarlyTone) -> (bg: Color, fg: Color, edge: Color) {
        let c = toneColors(tone)
        let base: Color = {
            switch tone {
            case .neutral: text3
            case .success: success
            case .danger: danger
            case .warning: warning
            case .info: info
            case .accent: accent
            }
        }()
        // 非 Barly 族（暖纸 / 粉彩 / 黑底）把淡底往页面底色收一点，免得语义蓝在暖底上发冷
        let soft = BarlyFamily.current.isBarly ? c.bg : c.bg.barlyMix(bg, 0.35)
        return (isDark ? base.opacity(0.18) : soft, isDark ? base.barlyMix(.white, 0.45) : c.fg, base.opacity(isDark ? 0.35 : 0.28))
    }
}

/// 一个事件块（周视图 / 日视图共用）
public struct CalEventBlock: View {
    let event: CalEvent
    let compact: Bool
    @Environment(\.barly) private var t
    public init(_ event: CalEvent, compact: Bool = false) { self.event = event; self.compact = compact }
    public var body: some View {
        let c = t.eventColors(event.tone)
        let short = event.end - event.start <= 0.5
        VStack(alignment: .leading, spacing: 2) {
            Text(event.title).barlyText(.product.caption.weight(500), color: c.fg).lineLimit(short ? 1 : 2)
            if !short {
                Text(event.timeLabel).barlyText(FamilyType.numeric(BarlyTokens.Product.caption).size(11), color: c.fg.opacity(0.75))
                if let d = event.detail, event.end - event.start >= 1.5 {
                    Text(d).barlyText(.product.caption.size(11), color: c.fg.opacity(0.75)).lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            if !event.people.isEmpty && event.end - event.start >= 1 { AvatarStack(event.people, size: 18) }
        }
        .padding(.horizontal, 8).padding(.vertical, short ? 3 : 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: BarlyRadius.sm, style: .continuous).fill(c.bg))
        .overlay(RoundedRectangle(cornerRadius: BarlyRadius.sm, style: .continuous).strokeBorder(c.edge, lineWidth: 1))
    }
}

/// 周视图：表头（周几 + 日期，今天 = 强调色字 + 浅灰圆）+ 时间刻度 + 7 列网格 + 事件 + 当前时间线
public struct WeekCalendar: View {
    let days: [(String, String)]
    let today: Int?
    let hours: ClosedRange<Int>
    let hourHeight: CGFloat
    let events: [CalEvent]
    let now: Double?
    @Environment(\.barly) private var t
    /// days = [("Mon", "13"), …]；today = 今天在第几列；now = 当前时间（小时）
    public init(days: [(String, String)], today: Int? = nil, hours: ClosedRange<Int> = 8...18, hourHeight: CGFloat = 56,
                events: [CalEvent], now: Double? = nil) {
        self.days = days; self.today = today; self.hours = hours; self.hourHeight = hourHeight; self.events = events; self.now = now
    }
    private let gutter: CGFloat = 56

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Color.clear.frame(width: gutter, height: 1)
                ForEach(Array(days.enumerated()), id: \.offset) { i, d in
                    HStack(spacing: 6) {
                        Text(d.0).barlyText(FamilyType.label(BarlyTokens.Product.label), color: i == today ? t.text : t.text3)
                        // 今天 = 强调色字 + 浅灰圆底（不用实心 ink，buttons.md §4）
                        Text(d.1).barlyText(FamilyType.numeric(BarlyTokens.Product.body.weight(i == today ? 600 : 500)), color: i == today ? t.accentText : t.text)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(i == today ? t.selectedBg : .clear))
                    }
                    .frame(maxWidth: .infinity).frame(height: 48)
                }
            }
            .overlay(alignment: .bottom) { Hairline() }
            GeometryReader { g in
                let colW = (g.size.width - gutter) / CGFloat(max(1, days.count))
                ZStack(alignment: .topLeading) {
                    // 小时线 + 刻度
                    ForEach(Array(hours.enumerated()), id: \.offset) { i, h in
                        HStack(alignment: .top, spacing: 8) {
                            Text(CalTime.label(Double(h), ampm: true)).barlyText(FamilyType.numeric(BarlyTokens.Product.caption).size(11), color: t.text3)
                                .frame(width: gutter - 10, alignment: .trailing)
                                .offset(y: -7)
                                // 第一条线不标；和当前时间标签撞的那条也不标
                                .opacity(i == 0 || (now.map { abs($0 - Double(h)) < 0.4 } ?? false) ? 0 : 1)
                            Rectangle().fill(t.hairline).frame(height: 1)
                        }
                        .offset(y: CGFloat(i) * hourHeight)
                    }
                    // 列线 + 今天的淡底
                    ForEach(0..<days.count, id: \.self) { i in
                        Rectangle().fill(i == today ? t.softSurface.opacity(0.55) : .clear)
                            .frame(width: colW, height: g.size.height)
                            .overlay(alignment: .leading) { Rectangle().fill(t.hairline).frame(width: 1) }
                            .offset(x: gutter + CGFloat(i) * colW)
                    }
                    ForEach(events) { e in
                        CalEventBlock(e)
                            .frame(width: colW - 6, height: max(22, CGFloat(e.end - e.start) * hourHeight - 3))
                            .offset(x: gutter + CGFloat(e.day) * colW + 3, y: CGFloat(e.start - Double(hours.lowerBound)) * hourHeight + 1.5)
                    }
                    if let now, let today {
                        let y = CGFloat(now - Double(hours.lowerBound)) * hourHeight
                        HStack(spacing: 0) {
                            Circle().fill(t.danger).frame(width: 7, height: 7)
                            Rectangle().fill(t.danger).frame(height: 1)
                        }
                        .frame(width: colW + 3)
                        .offset(x: gutter + CGFloat(today) * colW - 3.5, y: y - 3.5)
                        Text(CalTime.label(now)).barlyText(FamilyType.numeric(BarlyTokens.Product.caption).size(10).weight(500), color: t.danger)
                            .frame(width: gutter - 10, alignment: .trailing)
                            .background(t.bg)
                            .offset(y: y - 7)
                    }
                }
            }
            .frame(height: CGFloat(hours.count) * hourHeight)
            .clipped()
        }
    }
}

/// 迷你月历（预约侧栏）：7 列，今天 = 强调色字，选中 = 1.5pt 深色圈，有空位的日期下方 3pt 点
public struct MonthMini: View {
    let title: String
    let firstWeekday: Int
    let daysInMonth: Int
    let today: Int?
    let selected: Int?
    let available: Set<Int>
    let compact: Bool
    @Environment(\.barly) private var t
    /// firstWeekday：1 号是周几（0 = 周一）
    public init(_ title: String, firstWeekday: Int, daysInMonth: Int, today: Int? = nil, selected: Int? = nil,
                available: Set<Int> = [], compact: Bool = false) {
        self.title = title; self.firstWeekday = firstWeekday; self.daysInMonth = daysInMonth
        self.today = today; self.selected = selected; self.available = available; self.compact = compact
    }
    public var body: some View {
        let cell: CGFloat = compact ? 40 : 34
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).barlyText(FamilyType.pageTitle(BarlyTokens.Product.sectionTitle), color: t.text)
                Spacer()
                BarlyIcon("chevron.left", size: 13, color: t.text2)
                BarlyIcon("chevron.right", size: 13, color: t.text2).padding(.leading, 14)
            }
            let cols = Array(repeating: GridItem(.fixed(cell), spacing: 2), count: 7)
            LazyVGrid(columns: cols, spacing: 2) {
                ForEach(["M", "T", "W", "T", "F", "S", "S"].indices, id: \.self) { i in
                    Text(["M", "T", "W", "T", "F", "S", "S"][i]).barlyText(.product.caption, color: t.text3).frame(height: 22)
                }
                ForEach(0..<(firstWeekday + daysInMonth), id: \.self) { i in
                    let d = i - firstWeekday + 1
                    if d < 1 { Color.clear.frame(width: cell, height: cell) } else { day(d, cell) }
                }
            }
        }
    }
    private func day(_ d: Int, _ cell: CGFloat) -> some View {
        let isToday = d == today, isSel = d == selected, open = available.contains(d)
        return Text("\(d)")
            .barlyText(FamilyType.numeric(BarlyTokens.Product.body).weight(isToday || isSel ? 500 : 400),
                       color: isToday ? t.accentText : (open || isSel ? t.selectedFg : t.text3))
            .frame(width: cell - 6, height: cell - 6)
            // 选中 = 1.5pt 深色圈（不填充）；今天 = 强调色字
            .overlay(Circle().strokeBorder(isSel ? t.selectedFg : .clear, lineWidth: 1.5))
            .overlay(alignment: .bottom) {
                if open && !isSel { Circle().fill(isToday ? t.selectedMark : t.text3).frame(width: 3, height: 3).offset(y: 1) }
            }
            .frame(width: cell, height: cell)
    }
}

/// 可用时段网格：等宽格子，选中 = 1.5pt 深色边 + 右上强调色小勾（不填充），已约满 = text4 灰字（不加删除线）
public struct SlotGrid: View {
    let slots: [String]
    let selected: String?
    let taken: Set<String>
    let columns: Int
    let compact: Bool
    @Environment(\.barly) private var t
    public init(_ slots: [String], selected: String? = nil, taken: Set<String> = [], columns: Int = 3, compact: Bool = BarlyPlatform.compact) {
        self.slots = slots; self.selected = selected; self.taken = taken; self.columns = columns; self.compact = compact
    }
    public var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 8) {
            ForEach(slots, id: \.self) { s in
                let on = s == selected, off = taken.contains(s)
                Text(s)
                    .barlyText(FamilyType.numeric(compact ? BarlyTokens.Mobile.label : BarlyTokens.Product.body).weight(on ? 500 : 400),
                               color: on ? t.selectedFg : (off ? t.text4 : t.text))
                    .frame(maxWidth: .infinity).frame(height: compact ? 44 : 36)
                    .barlySelectCard(on, radius: BarlyRadius.sm, idleFill: off ? t.softSurface : nil)
            }
        }
    }
}

/// iOS 周条：7 天，选中 = 1.5pt 深色边圆角块（不填充）+ 强调色事件点，有事件的日期下方点
public struct WeekStrip: View {
    let days: [(String, String)]
    let selected: Int
    let busy: Set<Int>
    @Environment(\.barly) private var t
    public init(days: [(String, String)], selected: Int, busy: Set<Int> = []) { self.days = days; self.selected = selected; self.busy = busy }
    public var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(days.enumerated()), id: \.offset) { i, d in
                let on = i == selected
                VStack(spacing: 4) {
                    Text(d.0).barlyText(.mobile.micro, color: on ? t.text2 : t.text3)
                    Text(d.1).barlyText(FamilyType.numeric(BarlyTokens.Mobile.headline), color: on ? t.selectedFg : t.text)
                    Circle().fill(busy.contains(i) ? (on ? t.selectedMark : t.text3) : .clear).frame(width: 4, height: 4)
                }
                .frame(maxWidth: .infinity).frame(height: 64)
                .barlySelectCard(on, radius: BarlyRadius.md, mark: false, idleFill: .clear)
                .overlay { if !on { RoundedRectangle(cornerRadius: BarlyRadius.md, style: .continuous).strokeBorder(t.bg, lineWidth: 1) } }
            }
        }
    }
}

/// 日视图时间轴（iOS）：左 48 时间刻度 + 事件块
public struct DayTimeline: View {
    let hours: ClosedRange<Int>
    let hourHeight: CGFloat
    let events: [CalEvent]
    let now: Double?
    @Environment(\.barly) private var t
    public init(hours: ClosedRange<Int>, hourHeight: CGFloat = 52, events: [CalEvent], now: Double? = nil) {
        self.hours = hours; self.hourHeight = hourHeight; self.events = events; self.now = now
    }
    public var body: some View {
        let gutter: CGFloat = 48
        ZStack(alignment: .topLeading) {
            ForEach(Array(hours.enumerated()), id: \.offset) { i, h in
                HStack(alignment: .top, spacing: 8) {
                    Text(CalTime.label(Double(h))).barlyText(FamilyType.numeric(BarlyTokens.Mobile.micro), color: t.text3)
                        .frame(width: gutter - 8, alignment: .leading).offset(y: -8)
                    Rectangle().fill(t.hairline).frame(height: 1)
                }
                .offset(y: CGFloat(i) * hourHeight)
            }
            GeometryReader { g in
                ForEach(events) { e in
                    CalEventBlock(e, compact: true)
                        .frame(width: g.size.width - gutter, height: max(24, CGFloat(e.end - e.start) * hourHeight - 3))
                        .offset(x: gutter, y: CGFloat(e.start - Double(hours.lowerBound)) * hourHeight + 1.5)
                }
                if let now {
                    HStack(spacing: 0) {
                        Circle().fill(t.danger).frame(width: 7, height: 7)
                        Rectangle().fill(t.danger).frame(height: 1)
                    }
                    .frame(width: g.size.width - gutter + 3.5)
                    .offset(x: gutter - 3.5, y: CGFloat(now - Double(hours.lowerBound)) * hourHeight - 3.5)
                }
            }
        }
        .frame(height: CGFloat(hours.count - 1) * hourHeight + 1, alignment: .top)
    }
}

/// 即将开始的预约行：时间块（mono）+ 标题 + 说明 + 头像
public struct BookingRow: View {
    let event: CalEvent
    let when: String
    let compact: Bool
    @Environment(\.barly) private var t
    public init(_ event: CalEvent, when: String, compact: Bool = BarlyPlatform.compact) { self.event = event; self.when = when; self.compact = compact }
    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(when).barlyText(FamilyType.label(BarlyTokens.Product.label), color: t.text3)
                Text(CalTime.label(event.start)).barlyText(FamilyType.numeric(BarlyTokens.Product.body.weight(500)), color: t.text)
            }
            .frame(width: 52, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title).barlyText(compact ? .mobile.label.weight(500) : .product.body.weight(500), color: t.text).lineLimit(1)
                if let d = event.detail { Text(d).barlyText(.product.caption, color: t.text2).lineLimit(1) }
            }
            Spacer(minLength: 4)
            if !event.people.isEmpty { AvatarStack(event.people, size: 22) }
        }
        .padding(.vertical, 10)
        .overlay(alignment: .top) { Hairline() }
    }
}
