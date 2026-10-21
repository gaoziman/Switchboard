import SwiftUI
import BarlyKit

// 应用页面模式 · macOS 示例屏（1440×1024）。外壳一律 AppShell（按身份 layout.shell 切换，含 topnav），
// 内容读 \.barlyContentWidth 排版；检查栏开着时，页面自己的侧栏内容挪进检查栏（不出现两个右栏）。
// 依据：gallery/lovable-apps/app-<slug>.jpg（见 references/apple.md §9）。

/// 应用页的页头：标题 + 说明（可选）…… 右侧按钮；topnav 下没有底线、留白更大
struct AppPageHeader<Trailing: View>: View {
    let title: String
    let detail: String?
    let trailing: Trailing
    @Environment(\.barly) private var t
    @Environment(\.barlyShell) private var shell
    init(_ title: String, detail: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title; self.detail = detail; self.trailing = trailing()
    }
    var body: some View {
        let top = shell == "topnav"
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).barlyText(FamilyType.pageTitle(top ? BarlyTokens.Product.pageTitle.size(24) : BarlyTokens.Product.pageTitle), color: t.text)
                if let detail { Text(detail).barlyText(.product.small, color: t.text3) }
            }
            Spacer()
            trailing
        }
        .padding(.horizontal, BarlyMetrics.contentPad)
        .padding(.top, top ? 28 : 0)
        .padding(.bottom, top ? 16 : 0)
        .frame(minHeight: top ? 0 : 72)
        .overlay(alignment: .bottom) { if !top { Hairline() } }
    }
}

// MARK: - Kanban（recruiting-pipeline / project-management-board）

public struct KanbanBoardScreen: View {
    public var onNavigate: (String) -> Void
    public init(onNavigate: @escaping (String) -> Void = { _ in }) { self.onNavigate = onNavigate }
    public var body: some View {
        AppShell(AppMock.spec("kanban", subnav: ["Board", "List", "Timeline", "Files"]), onSelect: onNavigate) { KanbanContent() } inspector: { KanbanInspector() }
    }
}

struct KanbanContent: View {
    @State private var view = 0
    @Environment(\.barly) private var t
    @Environment(\.barlyContentWidth) private var w
    @Environment(\.barlyShell) private var shell
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AppPageHeader("Website relaunch", detail: "Launch Fri, Oct 24 · 11 open tasks") {
                AvatarStack(["Priya Shah", "Maya Lin", "Tom Becker", "Leo Park"], extra: 2, size: 26)
                ToolbarDivider()
                if shell != "topnav" { Segmented(["Board", "List", "Timeline"], selection: $view, height: 34, style: BarlyTokens.Product.caption) }
                BarlyButton("Filter", icon: "line.3.horizontal.decrease", variant: .outline)
                BarlyButton("New task", icon: "plus", variant: .primary)
            }
            HStack(spacing: 8) {
                Chip("Assignee: anyone", tone: .neutral)
                Chip("Label: Web, Design", tone: .neutral)
                Chip("Due this week", tone: .neutral)
                Spacer()
                Text("Sorted by priority").barlyText(.product.caption, color: t.text3)
            }
            .padding(.horizontal, BarlyMetrics.contentPad).padding(.vertical, 14)
            KanbanBoard(AppMock.board, compact: false, columnWidth: w >= 1300 ? 248 : 264, selected: "k6")
                .padding(.leading, BarlyMetrics.contentPad)
                .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}

struct KanbanInspector: View {
    @Environment(\.barly) private var t
    var body: some View {
        InspectorSection("Navigation + mega menu", action: "TSK-142") {
            VStack(alignment: .leading, spacing: 10) {
                row("Status") { Chip("In progress", tone: .warning, dot: true) }
                row("Assignees") { AvatarStack(["Tom Becker", "Leo Park"], size: 22) }
                row("Due") { Text("Sun, Oct 19").barlyText(.product.body, color: t.text) }
                row("Subtasks") { Text("3 of 5").barlyText(FamilyType.numeric(BarlyTokens.Product.body), color: t.text) }
            }
        }
        InspectorSection("Checklist") {
            VStack(alignment: .leading, spacing: 9) {
                ForEach([("Desktop layout", true), ("Mobile drawer", true), ("Hover intent delay", true), ("Keyboard support", false), ("Focus trap", false)], id: \.0) { c in
                    HStack(spacing: 10) {
                        Checkbox(c.1)
                        Text(c.0).barlyText(.product.body, color: c.1 ? t.text3 : t.text).strikethrough(c.1, color: t.text3)
                    }
                }
            }
        }
        InspectorSection("Activity", action: "12") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach([("Leo Park", "moved this to In progress", "2h"), ("Tom Becker", "attached nav-states.mov", "Yesterday")], id: \.1) { a in
                    HStack(alignment: .top, spacing: 10) {
                        Avatar(a.0, size: 22)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(Text(a.0).font(BarlyTokens.Product.body.weight(500).font))\(Text(" \(a.1)").font(BarlyTokens.Product.body.font))")
                                .foregroundStyle(t.text2)
                            Text(a.2).barlyText(.product.caption, color: t.text3)
                        }
                    }
                }
            }
        }
    }
    private func row<V: View>(_ k: String, @ViewBuilder _ v: () -> V) -> some View {
        HStack { Text(k).barlyText(.product.body, color: t.text3).frame(width: 88, alignment: .leading); v(); Spacer() }
    }
}

// MARK: - Calendar（deskflow 周视图 + meeting-booker 预约）

public struct CalendarScreen: View {
    public var onNavigate: (String) -> Void
    public init(onNavigate: @escaping (String) -> Void = { _ in }) { self.onNavigate = onNavigate }
    public var body: some View {
        AppShell(AppMock.spec("calendar"), onSelect: onNavigate) { CalendarContent() } inspector: { BookingPanel() }
    }
}

struct CalendarContent: View {
    @State private var range = 1
    @Environment(\.barly) private var t
    @Environment(\.barlyInspector) private var inspector
    @Environment(\.barlyContentWidth) private var w
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AppPageHeader("October 2026", detail: "Week 42 · 13 events") {
                Segmented(["Day", "Week", "Month"], selection: $range, height: 34, style: BarlyTokens.Product.caption)
                ToolbarDivider()
                BarlyButton("Today", variant: .outline)
                IconButton("chevron.left", size: 36)
                IconButton("chevron.right", size: 36)
                BarlyButton("New booking", icon: "plus", variant: .primary)
            }
            HStack(alignment: .top, spacing: 0) {
                WeekCalendar(days: AppMock.week, today: 3, hours: 8...18, hourHeight: 66, events: AppMock.events, now: 10.2)
                    .padding(.horizontal, 16).padding(.top, 4)
                if !inspector && w >= 1000 {
                    BarlyScroll { BookingPanel().padding(20) }
                        .frame(width: 320)
                        .overlay(alignment: .leading) { Hairline(vertical: true) }
                }
            }
        }
    }
}

/// 预约侧栏：迷你月历 · 选中日的可用时段 · 即将开始
struct BookingPanel: View {
    @Environment(\.barly) private var t
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            MonthMini("October", firstWeekday: 2, daysInMonth: 31, today: 16, selected: 17,
                      available: [16, 17, 20, 21, 22, 23, 24, 27, 28, 29, 30])
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Fri, Oct 17").barlyText(.product.cardTitle, color: t.text)
                    Spacer()
                    Text("30 min · Room Maple").barlyText(.product.caption, color: t.text3)
                }
                SlotGrid(AppMock.slots, selected: "11:30", taken: AppMock.taken, columns: 3, compact: false)
            }
            VStack(alignment: .leading, spacing: 0) {
                MonoLabel("Up next", color: t.text3).padding(.bottom, 8)
                ForEach(AppMock.upcoming, id: \.0.id) { BookingRow($0.0, when: $0.1, compact: false) }
            }
        }
    }
}

// MARK: - Mail（note-taking-app 分栏 / 收件箱）

public struct MailScreen: View {
    public var onNavigate: (String) -> Void
    public init(onNavigate: @escaping (String) -> Void = { _ in }) { self.onNavigate = onNavigate }
    public var body: some View {
        AppShell(AppMock.spec("inbox"), onSelect: onNavigate) { MailContent() }
    }
}

struct MailContent: View {
    @Environment(\.barlyShell) private var shell
    var body: some View {
        // 外壳侧栏就是文件夹的（sidebar / sidebar-gray / rail-list）→ 两栏；topnav / rail 下自带文件夹栏 → 三栏
        let ownFolders = shell == "topnav" || shell == "rail"
        MailSplit("Inbox", folders: ownFolders ? AppMock.folders : nil, labels: AppMock.labels,
                  items: AppMock.mail, selected: "m1", readerBody: AppMock.mailBody)
    }
}

// MARK: - Journal（lovable journal：日期大标题 + 单列阅读宽度）

public struct JournalScreen: View {
    public var onNavigate: (String) -> Void
    public init(onNavigate: @escaping (String) -> Void = { _ in }) { self.onNavigate = onNavigate }
    public var body: some View {
        AppShell(AppMock.spec("journal"), onSelect: onNavigate) { JournalContent() } inspector: { JournalInspector() }
    }
}

struct JournalContent: View {
    @Environment(\.barly) private var t
    @Environment(\.barlyInspector) private var inspector
    var body: some View {
        BarlyScroll {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    DateHeading(weekday: "Saturday", date: "18 October", note: "12 days in a row", compact: false)
                    Spacer()
                    BarlyButton("New entry", icon: "square.and.pencil", variant: .primary)
                }
                .padding(.top, 48)
                Card(padding: 20) {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            Text("How are you today?").barlyText(.product.cardTitle, color: t.text)
                            Spacer()
                            HabitDots(AppMock.journalHabits)
                        }
                        MoodScale(selected: 3, compact: false)
                        Text("Write about the light in the kitchen, the call, the knee…")
                            // 占位句：衬线族用衬线（像在纸上写），其余族用正文——压缩体大写不能拿来写句子
                            .barlyText(BarlyFamily.current.title == .serif ? FamilyType.pageTitle(BarlyTokens.Product.body.size(16)).leading(26) : BarlyTokens.Product.body.size(16).leading(26), color: t.text3)
                            .frame(maxWidth: .infinity, minHeight: 56, alignment: .topLeading)
                            .padding(.top, 2)
                    }
                }
                .padding(.top, 32)
                month("October")
                ForEach(AppMock.journal.prefix(2)) { JournalEntryCard($0, compact: false).padding(.bottom, 12) }
                month("September")
                ForEach(AppMock.journal.suffix(1)) { JournalEntryCard($0, compact: false).padding(.bottom, 12) }
            }
            .frame(maxWidth: 680)
            .padding(.horizontal, 40)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 40)
        }
    }
    private func month(_ m: String) -> some View {
        MonoLabel(m, color: t.text3).padding(.top, 36).padding(.bottom, 12)
    }
}

struct JournalInspector: View {
    @Environment(\.barly) private var t
    var body: some View {
        InspectorSection("This month") {
            HStack { StatTile("14", "Entries", compact: false); StatTile("6.2k", "Words", compact: false); StatTile("12", "Streak", compact: false) }
            HabitHeatmap(Array(AppMock.habits[0].history.suffix(35)), cell: 30, gap: 4, showDays: false).padding(.top, 4)
        }
        InspectorSection("Journals") {
            VStack(spacing: 8) {
                ForEach([("Personal", "book.closed", "4 entries"), ("Work", "briefcase", "3 entries"), ("Dreams", "moon.stars", "1 entry")], id: \.0) { j in
                    HStack(spacing: 10) {
                        BarlyIcon(j.1, size: 15, color: t.text2)
                        Text(j.0).barlyText(.product.body, color: t.text)
                        Spacer()
                        Text(j.2).barlyText(.product.caption, color: t.text3)
                    }
                    .padding(.horizontal, 12).frame(height: 38)
                    .background(RoundedRectangle(cornerRadius: BarlyRadius.sm, style: .continuous).fill(t.softSurface))
                }
            }
        }
    }
}

// MARK: - Habits（continuum：今日打卡 + 连续天数热力格）

public struct HabitsScreen: View {
    public var onNavigate: (String) -> Void
    public init(onNavigate: @escaping (String) -> Void = { _ in }) { self.onNavigate = onNavigate }
    public var body: some View {
        AppShell(AppMock.spec("habits"), onSelect: onNavigate) { HabitsContent() }
    }
}

struct HabitsContent: View {
    @State private var range = 1
    @Environment(\.barly) private var t
    @Environment(\.barlyContentWidth) private var w
    var body: some View {
        BarlyScroll {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Good morning, Priya").barlyText(.product.body, color: t.text3)
                        DisplayTitle(["Almost a perfect day"], style: FamilyType.display(BarlyTokens.Product.pageTitle.size(32).leading(1.15).tracked(-0.02), scale: false),
                                     keyword: BarlyFamily.current.title == .serif ? "perfect" : nil)
                        Text("Saturday, October 18 · 3 of 5 done").barlyText(.product.body, color: t.text2)
                    }
                    Spacer()
                    ProgressRing(done: 3, total: 5, size: 64)
                }
                .padding(.top, 40)
                let twoCol = w >= 1000
                let layout = twoCol ? AnyLayout(HStackLayout(alignment: .top, spacing: 24)) : AnyLayout(VStackLayout(alignment: .leading, spacing: 24))
                layout {
                    VStack(alignment: .leading, spacing: 10) {
                        MonoLabel("Today", color: t.text3).padding(.bottom, 2)
                        ForEach(AppMock.habits) { HabitRow($0, compact: false) }
                        HStack(spacing: 8) {
                            BarlyIcon("plus", size: 14, color: t.text3)
                            Text("Add a habit").barlyText(.product.body, color: t.text3)
                        }
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .overlay(RoundedRectangle(cornerRadius: BarlyRadius.lg, style: .continuous).strokeBorder(t.borderStrong, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                    }
                    .frame(maxWidth: twoCol ? 420 : .infinity)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            MonoLabel("Insights", color: t.text3)
                            Spacer()
                            Segmented(["30d", "18w", "1y"], selection: $range, height: 30, style: BarlyTokens.Product.caption)
                        }
                        Card(padding: 20) {
                            VStack(alignment: .leading, spacing: 18) {
                                HStack {
                                    StatTile("3/5", "Today", compact: false)
                                    StatTile("78%", "Avg. rate", compact: false)
                                    StatTile("31", "Best streak", compact: false)
                                }
                                Hairline()
                                ForEach(AppMock.habits.prefix(3)) { h in
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text(h.title).barlyText(.product.cardTitle, color: t.text)
                                            Spacer()
                                            Text("\(h.streak)d streak").barlyText(FamilyType.numeric(BarlyTokens.Product.caption), color: t.text3)
                                        }
                                        HabitHeatmap(h.history, cell: w >= 1100 ? 17 : 13, gap: 4, showDays: h.id == "h1")
                                    }
                                }
                                HStack { Spacer(); HeatLegend() }
                            }
                        }
                    }
                }
                .padding(.top, 32)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Settings（meeting-booker Settings / hireflow 表单 + 危险区）

public struct SettingsScreen: View {
    public var onNavigate: (String) -> Void
    public init(onNavigate: @escaping (String) -> Void = { _ in }) { self.onNavigate = onNavigate }
    public var body: some View {
        var spec = AppMock.spec("settings")
        spec.selection = "settings"
        return AppShell(spec, onSelect: onNavigate) { SettingsContent() }
    }
}

struct SettingsContent: View {
    @State private var digest = true
    @State private var mentions = true
    @State private var marketing = false
    @State private var twoFA = true
    @Environment(\.barly) private var t
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AppPageHeader("Settings", detail: "Manage your profile, notifications and workspace") {
                BarlyButton("Cancel", variant: .outline)
                BarlyButton("Save changes", variant: .primary)
            }
            HStack(alignment: .top, spacing: 0) {
                SettingsNav([("Account", [("person", "Profile"), ("bell", "Notifications"), ("lock", "Security")]),
                             ("Workspace", [("building.2", "General"), ("person.2", "Members"), ("creditcard", "Billing"), ("puzzlepiece", "Integrations")])],
                            selection: "Profile")
                    .frame(width: 200)
                    .padding(.top, 24).padding(.leading, 16)
                BarlyScroll {
                    VStack(alignment: .leading, spacing: 24) {
                        SettingsGroup("Profile", detail: "How you appear to teammates and on booking pages.", compact: false) {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack(spacing: 14) {
                                    Avatar("Priya Shah", size: 56)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Profile photo").barlyText(.product.body.weight(500), color: t.text)
                                        Text("PNG or JPG, at least 256 px").barlyText(.product.caption, color: t.text3)
                                    }
                                    Spacer()
                                    BarlyButton("Upload", variant: .outline, size: .sm)
                                }
                                HStack(alignment: .top, spacing: 12) { FormField("Display name", value: "Priya Shah"); FormField("Username", value: "priya", hint: "northwind.studio/book/priya") }
                                FormField("Bio", value: "Producer at Northwind. Happy to chat about launches and content ops.", multiline: true)
                            }
                            .padding(16)
                        }
                        SettingsGroup("Notifications", detail: "Email is sent to priya@northwind.studio.", compact: false) {
                            SettingsRow("Daily digest", detail: "One email at 8:00 with what changed", first: true, compact: false) { Toggle("", isOn: $digest).toggleStyle(.barly) }
                            SettingsRow("Mentions and replies", compact: false) { Toggle("", isOn: $mentions).toggleStyle(.barly) }
                            SettingsRow("Product news", detail: "A few times a year", compact: false) { Toggle("", isOn: $marketing).toggleStyle(.barly) }
                        }
                        SettingsGroup("Preferences", compact: false) {
                            SettingsRow("Theme", first: true, compact: false) { SettingsValue("System", compact: false) }
                            SettingsRow("Language", compact: false) { SettingsValue("English (US)", compact: false) }
                            SettingsRow("Two-factor authentication", detail: "Authenticator app · added Mar 2026", compact: false) { Toggle("", isOn: $twoFA).toggleStyle(.barly) }
                        }
                        HStack(alignment: .top, spacing: 32) {
                            Color.clear.frame(width: 220, height: 1)
                            DangerZone([("Transfer ownership", "Give another admin full control of Northwind Studio.", "Transfer"),
                                        ("Delete workspace", "Removes 3 projects, 412 tasks and all files. This can't be undone.", "Delete workspace")], compact: false)
                        }
                    }
                    .frame(maxWidth: 860, alignment: .leading)
                    .padding(.horizontal, 32).padding(.vertical, 24)
                }
            }
        }
    }
}

// MARK: - Empty states（hireflow「No jobs found」/ meeting-booker「No upcoming bookings」）

public struct EmptyStatesScreen: View {
    public var onNavigate: (String) -> Void
    public init(onNavigate: @escaping (String) -> Void = { _ in }) { self.onNavigate = onNavigate }
    public var body: some View {
        var spec = AppMock.spec("projects")
        spec.selection = "projects"
        return AppShell(spec, onSelect: onNavigate) { EmptyStatesContent() }
    }
}

struct EmptyStatesContent: View {
    @Environment(\.barlyContentWidth) private var w
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AppPageHeader("Empty states", detail: "First use · No results · No access · Error") {
                BarlyButton("New project", icon: "plus", variant: .primary)
            }
            let cols = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
            LazyVGrid(columns: cols, spacing: 16) {
                cell { EmptyState(.firstUse, title: "Start your first project", message: "Projects hold tasks, files and the calendar for one piece of work. Import a CSV from your old board, or start blank.",
                                  primary: "New project", secondary: "Import", compact: false) }
                cell { EmptyState(.noResults, title: "No tasks match “mega menu”", message: "Try a shorter search, or clear the Label and Due filters.",
                                  primary: nil, secondary: "Clear filters", ghost: true, compact: false) }
                cell { EmptyState(.noAccess, title: "You don't have access to Billing", message: "Only workspace owners can see invoices. Ask Priya Shah to give you access.",
                                  primary: "Request access", compact: false) }
                cell { EmptyState(.error, title: "We couldn't load your inbox", message: "The mail server didn't answer in time. Your messages are safe.",
                                  primary: "Try again", secondary: "Status page", footnote: "ERR_IMAP_TIMEOUT · 10:42", compact: false) }
            }
            .padding(BarlyMetrics.contentPad)
            Spacer(minLength: 0)
        }
    }
    private func cell<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        Card(padding: 0) { c().frame(maxWidth: .infinity).frame(height: 400) }
    }
}
