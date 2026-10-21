import SwiftUI
import BarlyKit

// 应用页面模式 · iOS 示例屏（393×852）。组件显式传 compact: true（barly-snap 在 macOS 上渲染 iOS 屏）。
// Barly 移动端没有 TabBar：模块之间靠顶栏标题下拉 / 返回切换。

/// 应用顶栏：左（返回 / 菜单）· 标题 · 右侧图标
public struct AppTopBar: View {
    let title: String
    var leading = "chevron.left"
    var trailing: [String] = []
    var avatar: String? = nil
    @Environment(\.barly) private var t
    /// 产品屏（Sources/Screens）也用它，所以是 public
    public init(title: String, leading: String = "chevron.left", trailing: [String] = [], avatar: String? = nil) {
        self.title = title; self.leading = leading; self.trailing = trailing; self.avatar = avatar
    }
    public var body: some View {
        HStack(spacing: 14) {
            BarlyIcon(leading, size: 19, color: t.text)
            Text(title).barlyText(.mobile.headline, color: t.text).lineLimit(1)
            Spacer()
            ForEach(trailing, id: \.self) { BarlyIcon($0, size: 19, color: t.text2) }
            if let avatar { Avatar(avatar, size: 30) }
        }
        .padding(.horizontal, BarlyMetrics.pageX)
        .frame(height: BarlyMetrics.topBar)
    }
}

/// 移动端大标题（风格族字形）
public func appTitle(_ size: CGFloat = 30) -> BarlyTextStyle {
    FamilyType.display(BarlyTokens.Mobile.display.size(size).leading(1.12).tracked(-0.02), scale: false)
}

// MARK: - Kanban（横滑列）

public struct KanbanPhoneScreen: View {
    @Environment(\.barly) private var t
    public init() {}
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AppTopBar(title: "Website relaunch", trailing: ["line.3.horizontal.decrease", "ellipsis"])
            HStack(alignment: .firstTextBaseline) {
                Text("Board").barlyText(appTitle(), color: t.text)
                Spacer()
                AvatarStack(["Priya Shah", "Maya Lin", "Tom Becker"], extra: 2, size: 24)
            }
            .padding(.horizontal, BarlyMetrics.pageX).padding(.top, 6)
            // 列索引：横滑时当前列 = ink 字 + 下划线
            BarlyScroll(.horizontal) {
                HStack(spacing: 20) {
                    ForEach(Array(AppMock.board.enumerated()), id: \.offset) { i, c in
                        HStack(spacing: 5) {
                            Text(c.title).barlyText(.mobile.label.weight(i == 2 ? 500 : 400), color: i == 2 ? t.text : t.text3)
                            Text("\(c.cards.count)").barlyText(FamilyType.numeric(BarlyTokens.Mobile.micro), color: t.text3)
                        }
                        .frame(height: 40)
                        .overlay(alignment: .bottom) { if i == 2 { Rectangle().fill(t.text).frame(height: 2) } }
                    }
                }
                .padding(.horizontal, BarlyMetrics.pageX)
            }
            .frame(height: 40)
            .overlay(alignment: .bottom) { Hairline() }
            .padding(.top, 10)
            KanbanBoard(Array(AppMock.board.dropFirst(2)), compact: true, columnWidth: 316)
                .padding(.top, 14)
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .overlay(alignment: .bottomTrailing) {
            BarlyButton("New task", icon: "plus", variant: .primary, size: .lg)
                .shadow(color: .black.opacity(t.isDark ? 0 : 0.12), radius: 12, y: 6)
                .padding(.trailing, BarlyMetrics.pageX).padding(.bottom, 12)
        }
        .screenBackground(t.bg)
    }
}

// MARK: - Calendar（日视图 + 可用时间）

public struct CalendarPhoneScreen: View {
    @Environment(\.barly) private var t
    public init() {}
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AppTopBar(title: "", leading: "barly.menu", trailing: ["magnifyingglass", "plus"])
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("October").barlyText(appTitle(), color: t.text)
                Text("2026").barlyText(appTitle().weight(300), color: t.text3)
                Spacer()
                Text("Today").barlyText(.mobile.label.weight(500), color: t.text2)
            }
            .padding(.horizontal, BarlyMetrics.pageX)
            WeekStrip(days: AppMock.week, selected: 3, busy: [0, 1, 2, 3, 4])
                .padding(.horizontal, 12).padding(.top, 14)
            BarlyScroll {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        MonoLabel("Thu · 4 events", color: t.text3)
                        Spacer()
                        Text("10:12").barlyText(FamilyType.numeric(BarlyTokens.Mobile.micro.weight(500)), color: t.danger)
                    }
                    .padding(.top, 18).padding(.bottom, 12)
                    DayTimeline(hours: 9...16, hourHeight: 46, events: AppMock.today, now: 10.2)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Book Room Maple").barlyText(FamilyType.pageTitle(BarlyTokens.Mobile.headline.size(17)), color: t.text)
                            Spacer()
                            Text("Fri, Oct 17 · 30 min").barlyText(.mobile.caption, color: t.text3)
                        }
                        SlotGrid(AppMock.slots, selected: "11:30", taken: AppMock.taken, columns: 3, compact: true)
                    }
                    .padding(.top, 26)
                }
                .padding(.horizontal, BarlyMetrics.pageX)
                .padding(.bottom, 90)
            }
        }
        .overlay(alignment: .bottom) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("11:30 – 12:00").barlyText(FamilyType.numeric(BarlyTokens.Mobile.label.weight(500)), color: t.text)
                    Text("Room Maple · 6 seats").barlyText(.mobile.micro, color: t.text3)
                }
                Spacer()
                BarlyButton("Confirm", variant: .cta, size: .lg)   // 预约 = 转化
            }
            .padding(.horizontal, BarlyMetrics.pageX).padding(.vertical, 12)
            .background(t.bg)
            .overlay(alignment: .top) { Hairline() }
        }
        .screenBackground(t.bg)
    }
}

// MARK: - Mail（列表 → 详情）

public struct MailListPhoneScreen: View {
    @State private var q = ""
    @Environment(\.barly) private var t
    public init() {}
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AppTopBar(title: "", leading: "barly.menu", trailing: ["line.3.horizontal.decrease"], avatar: "Priya Shah")
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Inbox").barlyText(appTitle(), color: t.text)
                Text("3 unread").barlyText(.mobile.caption, color: t.text3)
            }
            .padding(.horizontal, BarlyMetrics.pageX)
            BarlyTextField("Search mail", text: $q, icon: "magnifyingglass", height: 40)
                .padding(.horizontal, BarlyMetrics.pageX).padding(.top, 14).padding(.bottom, 6)
            MailList("Inbox", items: AppMock.mail, compact: true)
        }
        .overlay(alignment: .bottomTrailing) {
            BarlyButton("Compose", icon: "square.and.pencil", variant: .primary, size: .lg)
                .shadow(color: .black.opacity(t.isDark ? 0 : 0.12), radius: 12, y: 6)
                .padding(.trailing, BarlyMetrics.pageX).padding(.bottom, 12)
        }
        .screenBackground(t.bg)
    }
}

public struct MailDetailPhoneScreen: View {
    @Environment(\.barly) private var t
    public init() {}
    public var body: some View {
        VStack(spacing: 0) {
            AppTopBar(title: "Inbox", trailing: ["archivebox", "trash", "ellipsis"])
            MailReader(AppMock.mail[0], body: AppMock.mailBody, compact: true)
        }
        .screenBackground(t.bg)
    }
}

// MARK: - Journal（日期大标题 + 心情 + 习惯打点）

public struct JournalPhoneScreen: View {
    @Environment(\.barly) private var t
    public init() {}
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AppTopBar(title: "", leading: "barly.menu", trailing: ["magnifyingglass"], avatar: "Priya Shah")
            BarlyScroll {
                VStack(alignment: .leading, spacing: 0) {
                    DateHeading(weekday: "Saturday", date: "18 October", note: "12 days in a row", compact: true)
                        .padding(.top, 12)
                    Card(padding: 16) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("How are you today?").barlyText(.mobile.label.weight(500), color: t.text)
                            MoodScale(selected: 3, compact: true)
                            Hairline()
                            HabitDots(Array(AppMock.journalHabits.prefix(3)))
                        }
                    }
                    .padding(.top, 22)
                    MonoLabel("October", color: t.text3).padding(.top, 28).padding(.bottom, 10)
                    VStack(spacing: 10) {
                        ForEach(AppMock.journal.prefix(2)) { JournalEntryCard($0, compact: true) }
                    }
                }
                .padding(.horizontal, BarlyMetrics.pageX)
                .padding(.bottom, 90)
            }
        }
        .overlay(alignment: .bottom) {
            BarlyButton("Write today’s entry", icon: "square.and.pencil", variant: .primary, size: .xl, fullWidth: true)
                .padding(.horizontal, BarlyMetrics.pageX).padding(.bottom, 12)
        }
        .screenBackground(t.bg)
    }
}

// MARK: - Habits（今日打卡 + 热力格）

public struct HabitsPhoneScreen: View {
    @Environment(\.barly) private var t
    public init() {}
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AppTopBar(title: "", leading: "barly.menu", trailing: ["chart.bar", "plus"])
            BarlyScroll {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Good morning").barlyText(.mobile.caption, color: t.text3)
                            Text("Almost there").barlyText(appTitle(28), color: t.text)
                            Text("Saturday, Oct 18 · 3 of 5 done").barlyText(.mobile.caption, color: t.text2)
                        }
                        Spacer()
                        ProgressRing(done: 3, total: 5, size: 60)
                    }
                    .padding(.top, 10)
                    VStack(spacing: 8) {
                        ForEach(AppMock.habits.prefix(4)) { HabitRow($0, compact: true) }
                    }
                    .padding(.top, 20)
                    HStack {
                        MonoLabel("Read · last 18 weeks", color: t.text3)
                        Spacer()
                        Text("12d streak").barlyText(FamilyType.numeric(BarlyTokens.Mobile.micro), color: t.text3)
                    }
                    .padding(.top, 26).padding(.bottom, 10)
                    Card(padding: 14) {
                        VStack(alignment: .leading, spacing: 12) {
                            HabitHeatmap(Array(AppMock.habits[0].history.suffix(126)), cell: 13, gap: 3)
                            HStack {
                                Text("78% of days").barlyText(.mobile.micro, color: t.text2)
                                Spacer()
                                HeatLegend()
                            }
                        }
                    }
                }
                .padding(.horizontal, BarlyMetrics.pageX)
                .padding(.bottom, 24)
            }
        }
        .screenBackground(t.bg)
    }
}

// MARK: - Settings（分组 + 危险区）

public struct SettingsPhoneScreen: View {
    @State private var digest = true
    @State private var mentions = true
    @State private var faceID = true
    @Environment(\.barly) private var t
    public init() {}
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AppTopBar(title: "")
            BarlyScroll {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Settings").barlyText(appTitle(), color: t.text)
                    Card(padding: 14) {
                        HStack(spacing: 12) {
                            Avatar("Priya Shah", size: 48)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Priya Shah").barlyText(.mobile.headline, color: t.text)
                                Text(verbatim: "priya@northwind.studio").barlyText(.mobile.caption, color: t.text3)
                            }
                            Spacer()
                            BarlyIcon("chevron.right", size: 13, color: t.text4)
                        }
                    }
                    SettingsGroup("Notifications", compact: true) {
                        SettingsRow("Daily digest", icon: "envelope", first: true, compact: true) { Toggle("", isOn: $digest).toggleStyle(.barly) }
                        SettingsRow("Mentions", icon: "at", compact: true) { Toggle("", isOn: $mentions).toggleStyle(.barly) }
                        SettingsRow("Quiet hours", icon: "moon", compact: true) { SettingsValue("22:00 – 7:00", compact: true) }
                    }
                    SettingsGroup("General", detail: "Face ID is used to unlock invoices and billing.", compact: true) {
                        SettingsRow("Appearance", icon: "circle.lefthalf.filled", first: true, compact: true) { SettingsValue("System", compact: true) }
                        SettingsRow("Language", icon: "globe", compact: true) { SettingsValue("English", compact: true) }
                        SettingsRow("Face ID", icon: "faceid", compact: true) { Toggle("", isOn: $faceID).toggleStyle(.barly) }
                    }
                    DangerZone([("Delete account", "Removes your profile and 214 tasks. Can't be undone.", "Delete")], compact: true)
                    Text("Northwind 4.2 (1180) · Terms · Privacy").barlyText(.mobile.micro, color: t.text4).frame(maxWidth: .infinity)
                }
                .padding(.horizontal, BarlyMetrics.pageX)
                .padding(.bottom, 24)
            }
        }
        .screenBackground(t.bg)
    }
}

// MARK: - Empty states

public struct EmptyPhoneScreen: View {
    let kind: EmptyKind
    @State private var q = "mega menu"
    @Environment(\.barly) private var t
    public init(_ kind: EmptyKind = .firstUse) { self.kind = kind }
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AppTopBar(title: "", leading: "barly.menu", trailing: kind == .firstUse ? ["plus"] : [])
            Text(kind == .firstUse ? "Projects" : "Search").barlyText(appTitle(), color: t.text)
                .padding(.horizontal, BarlyMetrics.pageX)
            if kind == .noResults {
                BarlyTextField("Search tasks", text: $q, icon: "magnifyingglass", height: 40)
                    .padding(.horizontal, BarlyMetrics.pageX).padding(.top, 14)
                HStack(spacing: 6) { Chip("Label: Web"); Chip("Due this week") }
                    .padding(.horizontal, BarlyMetrics.pageX).padding(.top, 10)
            }
            Spacer()
            switch kind {
            case .firstUse:
                EmptyState(.firstUse, title: "Start your first project", message: "Projects hold tasks, files and the calendar for one piece of work.",
                           primary: "New project", secondary: "Import", compact: true)
            case .noResults:
                EmptyState(.noResults, title: "No tasks match “mega menu”", message: "Try a shorter search, or clear the filters.",
                           secondary: "Clear filters", compact: true)
            case .noAccess:
                EmptyState(.noAccess, title: "Billing is owner-only", message: "Ask Priya Shah to give you access.", primary: "Request access", compact: true)
            case .error:
                EmptyState(.error, title: "Couldn't load your inbox", message: "The mail server didn't answer in time. Your messages are safe.",
                           primary: "Try again", footnote: "ERR_IMAP_TIMEOUT", compact: true)
            }
            Spacer()
            Spacer()
        }
        .screenBackground(t.bg)
    }
}
