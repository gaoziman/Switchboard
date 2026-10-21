import SwiftUI
import BarlyKit

/// 应用页面模式的演示数据（看板 / 日历 / 邮件 / 日记 / 习惯 / 设置）：虚构的团队「Northwind Studio」正在做官网改版。
enum AppMock {
    // MARK: 共用外壳（同一个产品的几个模块）
    static let nav = [
        SidebarNavItem("kanban", icon: "square.split.2x1", title: "Board"),
        SidebarNavItem("calendar", icon: "calendar", title: "Calendar"),
        SidebarNavItem("inbox", icon: "tray", title: "Inbox", badge: "12"),
        SidebarNavItem("journal", icon: "book.closed", title: "Journal"),
        SidebarNavItem("habits", icon: "checkmark.circle", title: "Habits"),
        SidebarNavItem("projects", icon: "folder", title: "Projects"),
    ]

    static func spec(_ selection: String, subnav: [String] = [], subnavSelection: Int = 0) -> ShellSpec {
        ShellSpec(brand: (Mock.brand, "Northwind Studio"), workspace: "Northwind", nav: nav, selection: selection,
                  groups: [SidebarGroup("Teams", color: BarlyTokens.light.info, children: ["Design", "Web", "Content"])],
                  footer: [SidebarNavItem("settings", icon: "gearshape", title: "Settings"),
                           SidebarNavItem("help", icon: "headphones", title: "Help Center")],
                  user: ("Priya Shah", "priya@northwind.studio"),
                  listTitle: "Projects", listAction: "New project",
                  list: [ShellListSection("Active", [ShellListItem("p1", "Website relaunch", detail: "24", icon: "globe"),
                                                     ShellListItem("p2", "Spring campaign", detail: "9", icon: "megaphone"),
                                                     ShellListItem("p3", "Brand refresh", detail: "6", icon: "paintpalette")]),
                         ShellListSection("Views", [ShellListItem("v1", "My tasks", detail: "7"),
                                                    ShellListItem("v2", "Due this week", detail: "5"),
                                                    ShellListItem("v3", "Blocked", detail: "2")])],
                  listSelection: "p1", subnav: subnav, subnavSelection: subnavSelection)
    }

    // MARK: 看板
    static let board: [KanbanColumn] = [
        KanbanColumn("backlog", "Backlog", tone: .neutral, cards: [
            KanbanCard("k1", "Audit legacy blog redirects", detail: "214 URLs from the 2019 CMS still 301 to the homepage.",
                       tags: [KanbanTag("SEO", tone: .info)], people: ["Leo Park"], comments: 3),
            KanbanCard("k2", "Pricing page FAQ copy", tags: [KanbanTag("Content")], people: ["Ines Duarte"], due: "Oct 28"),
            KanbanCard("k3", "Cookie banner — EU consent modes", tags: [KanbanTag("Legal", tone: .warning)], attachments: 2),
        ]),
        KanbanColumn("todo", "To do", tone: .info, cards: [
            KanbanCard("k4", "Hero illustration, 3 directions", detail: "Moodboard is on the Relaunch › Hero board.",
                       tags: [KanbanTag("Design", tone: .accent)], people: ["Maya Lin", "Priya Shah"], due: "Oct 21", comments: 8, attachments: 4),
            KanbanCard("k5", "Set up preview deployments", tags: [KanbanTag("Web", tone: .success)], people: ["Tom Becker"], due: "Oct 22",
                       progress: 0.25, progressLabel: "1/4"),
        ]),
        KanbanColumn("doing", "In progress", tone: .warning, limit: 4, cards: [
            KanbanCard("k6", "Navigation + mega menu build", detail: "Keyboard support and focus trap still missing.",
                       tags: [KanbanTag("Web", tone: .success)], people: ["Tom Becker", "Leo Park"], due: "Oct 19", comments: 12,
                       progress: 0.6, progressLabel: "3/5"),
            KanbanCard("k7", "Case study: Helio Freight", tags: [KanbanTag("Content")], people: ["Ines Duarte"], due: "Oct 17", overdue: true, comments: 4),
            KanbanCard("k8", "Type scale + tokens in code", tags: [KanbanTag("Design", tone: .accent)], people: ["Maya Lin"], attachments: 1,
                       progress: 0.8, progressLabel: "4/5"),
        ]),
        KanbanColumn("review", "In review", tone: .accent, cards: [
            KanbanCard("k9", "Footer & legal links", tags: [KanbanTag("Web", tone: .success)], people: ["Tom Becker"], comments: 2,
                       progress: 1, progressLabel: "Done"),
        ]),
        KanbanColumn("done", "Done", tone: .success, cards: [
            KanbanCard("k10", "Sitemap v2 signed off", people: ["Priya Shah"], comments: 6),
            KanbanCard("k11", "Analytics events spec", tags: [KanbanTag("Data", tone: .info)], people: ["Leo Park"], attachments: 1),
        ]),
    ]

    // MARK: 日历 / 预约（周一 Oct 13 … 周日 Oct 19，今天 = 周四 16）
    static let week: [(String, String)] = [("Mon", "13"), ("Tue", "14"), ("Wed", "15"), ("Thu", "16"), ("Fri", "17"), ("Sat", "18"), ("Sun", "19")]
    static let events: [CalEvent] = [
        CalEvent("e1", day: 0, 9, 9.5, "Standup", tone: .neutral),
        CalEvent("e2", day: 0, 10, 12, "Hero workshop", detail: "Studio B · bring sketches", tone: .accent, people: ["Maya Lin", "Priya Shah"]),
        CalEvent("e3", day: 1, 9, 9.5, "Standup", tone: .neutral),
        CalEvent("e4", day: 1, 13, 14, "Client: Helio review", detail: "Video call", tone: .info, people: ["Ines Duarte"]),
        CalEvent("e5", day: 2, 9, 9.5, "Standup", tone: .neutral),
        CalEvent("e6", day: 2, 11, 12.5, "Nav build pairing", detail: "Desk D-12", tone: .success, people: ["Tom Becker", "Leo Park"]),
        CalEvent("e7", day: 2, 15, 16, "1:1 Maya", tone: .warning),
        CalEvent("e8", day: 3, 9, 9.5, "Standup", tone: .neutral),
        CalEvent("e9", day: 3, 10.5, 11.5, "Design crit", detail: "Room Maple", tone: .accent, people: ["Maya Lin", "Tom Becker"]),
        CalEvent("e10", day: 3, 14, 15.5, "Content sprint", detail: "Case studies × 3", tone: .info, people: ["Ines Duarte"]),
        CalEvent("e11", day: 4, 9, 9.5, "Standup", tone: .neutral),
        CalEvent("e12", day: 4, 12, 13, "Team lunch", detail: "Shoraian", tone: .warning, people: ["Priya Shah", "Leo Park"]),
        CalEvent("e13", day: 4, 15, 17, "Launch rehearsal", detail: "All hands · Room Cedar", tone: .danger, people: ["Priya Shah", "Tom Becker", "Maya Lin"]),
    ]
    static let slots = ["9:00", "9:30", "10:00", "11:30", "13:00", "13:30", "14:00", "15:30", "16:00"]
    static let taken: Set<String> = ["10:00", "13:30"]
    static let upcoming: [(CalEvent, String)] = [
        (CalEvent("u1", 10.5, 11.5, "Design crit", detail: "Room Maple · 4 people", people: ["Maya Lin", "Tom Becker"]), "Today"),
        (CalEvent("u2", 14, 15.5, "Content sprint", detail: "Case studies × 3", people: ["Ines Duarte"]), "Today"),
        (CalEvent("u3", 12, 13, "Team lunch", detail: "Shoraian · booked for 6", people: ["Priya Shah", "Leo Park"]), "Fri"),
    ]
    /// iOS 日视图（今天）
    static let today: [CalEvent] = [
        CalEvent("t1", 9, 9.5, "Standup", tone: .neutral),
        CalEvent("t2", 10.5, 11.5, "Design crit", detail: "Room Maple", tone: .accent, people: ["Maya Lin", "Tom Becker"]),
        CalEvent("t3", 12.5, 13, "Lunch w/ Ines", tone: .warning),
        CalEvent("t4", 14, 15.5, "Content sprint", detail: "Case studies × 3", tone: .info, people: ["Ines Duarte"]),
    ]

    // MARK: 邮件
    static let mail: [MailItem] = [
        MailItem("m1", from: "Ines Duarte", email: "ines@northwind.studio", subject: "Helio case study — final draft",
                 preview: "Attached the version with Daniel's quotes approved. Two numbers still need a source before we publish on Friday.",
                 time: "9:42", unread: true, starred: true, tag: KanbanTag("Content"), attachments: ["helio-case-v4.pdf"], thread: 3),
        MailItem("m2", from: "Tom Becker", email: "tom@northwind.studio", subject: "Preview deploys are live",
                 preview: "Every PR now gets its own URL. Password is in 1Password under “Relaunch preview”.", time: "9:10", unread: true, tag: KanbanTag("Web", tone: .success)),
        MailItem("m3", from: "Daniel Okafor", email: "daniel@heliofreight.com", subject: "Re: Launch date",
                 preview: "Friday the 24th works for us. Could we get the press kit by Wednesday so legal has two days?", time: "8:55", unread: true, thread: 5),
        MailItem("m4", from: "Maya Lin", email: "maya@northwind.studio", subject: "Hero directions for crit",
                 preview: "Three directions, plus a fourth I couldn't resist. Mostly want feedback on the type lockup.", time: "Yesterday",
                 tag: KanbanTag("Design", tone: .accent), attachments: ["hero-directions.fig"]),
        MailItem("m5", from: "Kestrel Pay", email: "receipts@kestrelpay.example", subject: "Your receipt from Northwind Studio",
                 preview: "Receipt #2291-4410 · $1,240.00 · Paid October 15, 2026", time: "Yesterday"),
        MailItem("m6", from: "Leo Park", email: "leo@northwind.studio", subject: "Redirect map, round two",
                 preview: "Down to 38 URLs that need a human decision. Sheet is sorted by traffic so we can start at the top.", time: "Tue",
                 attachments: ["redirects.csv"]),
        MailItem("m7", from: "Meridian", email: "notifications@meridian.example", subject: "New event: Intro call with Harbor & Co.",
                 preview: "Thursday, Oct 23 · 2:00 – 2:30 pm · Video call", time: "Mon"),
    ]
    static let mailBody = [
        "Hi Priya,",
        "Attached is v4 of the Helio Freight case study. Daniel approved all three quotes this morning, and I've tightened the intro so the 41% number lands in the first paragraph instead of the third.",
        "Two things before we publish on Friday: the “6 weeks to launch” figure needs a source (I think it's from Tom's retro doc), and legal asked us to drop the customer logo wall from the hero until the contracts are countersigned.",
        "If you can skim it before crit at 10:30 I'll make the last pass this afternoon.",
        "Thanks,\nInes",
    ]
    static let folders = [MailFolder("inbox", "Inbox", icon: "tray", count: 12), MailFolder("starred", "Starred", icon: "star"),
                          MailFolder("snoozed", "Snoozed", icon: "clock", count: 2), MailFolder("sent", "Sent", icon: "paperplane"),
                          MailFolder("drafts", "Drafts", icon: "doc", count: 1), MailFolder("archive", "Archive", icon: "archivebox")]
    static let labels = [KanbanTag("Clients", tone: .info), KanbanTag("Content"), KanbanTag("Design", tone: .accent), KanbanTag("Invoices", tone: .warning)]

    // MARK: 日记
    static let journal: [JournalEntry] = [
        JournalEntry("j1", date: "Saturday, Oct 18", title: "Gratitude",
                     body: "Three things I'm grateful for today. The first is the light in the kitchen before anyone else is up, the way it lands on the table and makes the whole room feel patient. The second is my sister calling for no reason. The third is that my knee hasn't hurt in nine days.",
                     mood: 3, tags: ["morning"], words: 212),
        JournalEntry("j2", date: "Tuesday, Oct 14", title: "The Multnomah hike",
                     body: "Worth every step, though I said the opposite about six times on the way up. It rained the whole first hour, the fine kind that soaks you slowly without ever feeling like rain. At the top there was almost no one.",
                     mood: 4, words: 486),
        JournalEntry("j3", date: "Thursday, Sep 25", title: "Weekend in Portland",
                     body: "Everything I needed and nothing I planned. We booked the room on Thursday night and left before the traffic on Friday. Saturday was mostly walking. Bookshops, a long lunch, a bridge I have crossed a dozen times.",
                     mood: 3, words: 731),
    ]
    static let journalHabits: [(String, Bool)] = [("Read", true), ("Walk", true), ("No phone after 10", false), ("Water", true)]

    // MARK: 习惯（最近 18 周热力格，最后一格 = 今天）
    static func history(_ seed: Int, _ density: Double, streak: Int = 0) -> [Int] {
        var x = UInt64(seed * 2654435761 % 4294967296 + 1)
        // 习惯是「做了 / 没做」：做了的天大多是 3 级，偶尔 2（只做了一半）/ 4（超额）；越近越稳定
        let n = 182
        return (0..<n).map { i in
            x = x &* 6364136223846793005 &+ 1442695040888963407
            let r = Double((x >> 33) % 1000) / 1000
            let ramp = Double(i) / Double(n) * 0.3
            if r > density + ramp { return 0 }
            let k = (x >> 20) % 10
            return k < 6 ? 2 : (k < 9 ? 3 : 4)
        }
        .enumerated().map { i, v in
            // 和连续天数对得上：最近 streak 天都做了，再往前一天断开
            if i >= n - streak { return max(v, 2) }
            if i == n - streak - 1 { return 0 }
            return v
        }
    }
    static let habits: [HabitItem] = [
        HabitItem("h1", "Read", target: "At least 10 pages", icon: "book", done: true, streak: 12, history: history(3, 0.62, streak: 12)),
        HabitItem("h2", "Morning walk", target: "20 minutes of fresh air", icon: "figure.walk", done: true, streak: 5, history: history(7, 0.5, streak: 5)),
        HabitItem("h3", "Meditate", target: "5 minutes of stillness", icon: "wind", done: false, streak: 0, history: history(11, 0.35, streak: 0)),
        HabitItem("h4", "Drink water", target: "8 glasses through the day", icon: "drop", done: true, streak: 31, history: history(5, 0.8, streak: 31)),
        HabitItem("h5", "No phone after 10", target: "Charger stays in the hall", icon: "moon", done: false, streak: 2, history: history(13, 0.4, streak: 2)),
    ]
}
