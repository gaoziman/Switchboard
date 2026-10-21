import SwiftUI
import BarlyKit

// MARK: - Dashboard（Brisk 式 CRM：侧栏 + 标题栏 + 工具栏 + KPI + 折线 + 表格）

public struct DashboardScreen: View {
    @State private var search = ""
    @State private var range = 4
    @State private var nav = "dashboard"
    @Environment(\.barly) private var t
    public var onNavigate: (String) -> Void
    public init(onNavigate: @escaping (String) -> Void = { _ in }) { self.onNavigate = onNavigate }

    static let navItems = [
        SidebarNavItem("dashboard", icon: "square.grid.2x2", title: "Dashboard"),
        SidebarNavItem("deals", icon: "hands.sparkles", title: "Deals"),
        SidebarNavItem("notes", icon: "note.text", title: "Notes"),
        SidebarNavItem("emails", icon: "envelope", title: "Emails"),
        SidebarNavItem("reports", icon: "chart.bar", title: "Reports"),
        SidebarNavItem("chat", icon: "bubble.left.and.text.bubble.right", title: "AI Assistant"),
    ]

    static var spec: ShellSpec {
        ShellSpec(brand: (Mock.brand, "CR Management"), workspace: "Mesh", nav: navItems, selection: "dashboard",
                  groups: [SidebarGroup("Favorites", color: BarlyTokens.light.info, children: ["Companies", "Contacts", "Meetings"]),
                           SidebarGroup("Projects", color: BarlyTokens.light.warning, children: [])],
                  footer: [SidebarNavItem("settings", icon: "gearshape", title: "Settings"),
                           SidebarNavItem("help", icon: "headphones", title: "Help Center")],
                  storage: (0.9, "1.8 GB of 2 GB used"),
                  user: ("Janson Williams", "williams@mesh.com"),
                  listTitle: "Reports", listAction: "New report",
                  list: [ShellListSection("Pinned", [ShellListItem("d", "Q3 pipeline review", detail: "Today", icon: "chart.bar"),
                                                     ShellListItem("w", "Win / loss by region", icon: "chart.pie"),
                                                     ShellListItem("c", "Churn watchlist", icon: "exclamationmark.triangle")]),
                         ShellListSection("Projects", [ShellListItem("p1", "Northwind renewal", detail: "12"),
                                                       ShellListItem("p2", "EMEA expansion", detail: "8"),
                                                       ShellListItem("p3", "Partner program", detail: "5"),
                                                       ShellListItem("p4", "Pricing test", detail: "3")])],
                  listSelection: "d")
    }

    public var body: some View {
        AppShell(Self.spec, onSelect: { nav = $0; onNavigate($0) }) {
            DashboardContent(search: $search, range: $range)
        } inspector: {
            DashboardInspector()
        }
    }
}

/// Dashboard 内容区：按 AppShell 给的宽度排（窄时 Retention 卡落到下一行、KPI 两两一行）
struct DashboardContent: View {
    @Binding var search: String
    @Binding var range: Int
    @Environment(\.barly) private var t
    @Environment(\.barlyContentWidth) private var w
    @Environment(\.barlyInspector) private var inspector
    @Environment(\.barlyShell) private var shell

    var body: some View {
        VStack(spacing: 0) {
            TitleBar("Dashboard") {
                // topnav：通知和 ⌘K 搜索已经在顶栏里
                if shell != "topnav" {
                    IconButton("bell", badge: true)
                    SearchField("Search something", text: $search, shortcut: "⌘K", width: w > 900 ? 220 : 170)
                }
                if w > 900 { BarlyButton("Share", icon: "square.and.arrow.up", variant: .outline) }
            }
            Toolbar {
                AskAIButton()
                ToolbarDivider()
                BarlyButton(w > 900 ? "Customize Widget" : "Customize", icon: "square.on.square.dashed", variant: .outline)
            } trailing: {
                if w > 1000 { StatusNote(); ToolbarDivider() }
                if !inspector { BarlyButton("Imports", icon: "icloud.and.arrow.down", variant: .outline, split: true) }
                // Ask AI 已经占了这一屏唯一的强调色块 → 主按钮用 ink
                BarlyButton("Exports", icon: "icloud.and.arrow.up", variant: .ink, split: true) // 工具操作：任何品类都用带色相近黑；同屏的 Ask AI 已占用强调色
            }
            BarlyScroll {
                VStack(spacing: 16) {
                    let kpis = Group {
                        KpiCard("Leads", value: "129", note: "+24 vs last week", delta: "8%")
                        KpiCard("Conversion Rate", value: "24%", note: "+8 vs last week", delta: "2%")
                        KpiCard("CLV", value: "14d", note: "+1d vs last week", delta: "4%", up: false, info: true)
                        KpiCard("Avg. Deal Size", value: "$24.6k", note: "+$1.2k vs last week", delta: "5%")
                    }
                    if w >= 1000 {
                        HStack(spacing: 16) { kpis }
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) { kpis }
                    }
                    if w >= 1000 {
                        HStack(alignment: .top, spacing: 16) {
                            revenueCard
                            retentionCard.frame(width: 340)
                        }
                    } else {
                        revenueCard
                    }
                    dealsCard
                }
                .padding(BarlyMetrics.contentPad)
            }
        }
    }

    private var revenueCard: some View {
        Card(padding: 20) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Text("Revenue").barlyText(.product.cardTitle, color: t.text)
                            BarlyIcon("chevron.up.chevron.down", size: 12, color: t.text3)
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            SplitNumber(prefix: "$", "32,209", fraction: ".40", style: BarlyTokens.Product.heroNumber.size(24))
                            Text("+22% vs last month").barlyText(.product.body, color: t.text2)
                        }
                    }
                    Spacer()
                    Segmented(["1D", "1W", "1M", "6M", "1Y", "ALL"], selection: $range, height: 34, style: BarlyTokens.Product.caption)
                }
                LineChart(Mock.revenueSeries, highlight: 30, tooltipTitle: "Jan 2026", tooltipValue: "$30,352")
                    .frame(height: 250)
                    .padding(.top, 20)
            }
        }
    }

    private var retentionCard: some View {
        Card(padding: 20) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Retention Rate").barlyText(.product.cardTitle, color: t.text)
                    Spacer()
                    IconButton("ellipsis", size: 30)
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("95%").barlyText(.product.kpi, color: t.text)
                    Text("+12% vs last month").barlyText(.product.body, color: t.text2)
                }
                .padding(.top, 6)
                HStack(spacing: 16) {
                    LegendDot("SMEs", color: t.dataLight)
                    LegendDot("Startups", color: t.dataBase)
                    LegendDot("Enterprises", color: t.dataDeep)
                }
                .padding(.top, 10)
                BarChart(Mock.retention).frame(height: 190).padding(.top, 18)
            }
        }
    }

    private var dealsCard: some View {
        Card(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Active Deals").barlyText(.product.cardTitle, color: t.text)
                    Chip("5 open", tone: .neutral)
                    Spacer()
                    BarlyButton("Filter", icon: "line.3.horizontal.decrease", variant: .outline, size: .sm)
                    BarlyButton("Sort", icon: "arrow.up.arrow.down", variant: .outline, size: .sm)
                }
                .padding(.horizontal, 20).padding(.vertical, 14)
                DataTable(columns: [
                    BarlyColumn("Company", width: w >= 1000 ? 230 : 200) { d in AnyView(HStack(spacing: 10) {
                        Checkbox(d.id == 2)
                        CompanyLogo(d.glyph, color: d.color)
                        BarlyCellText(d.company, strong: true)
                    }) },
                    BarlyColumn("Contact", width: w >= 1000 ? 190 : 160) { d in AnyView(HStack(spacing: 8) { Avatar(d.contact, size: 24); BarlyCellText(d.contact) }) },
                    BarlyColumn("Stage", width: 140) { d in AnyView(Chip(d.stage.uppercased(), tone: d.tone, mono: true)) },
                    .text("Value", width: 130) { $0.value },
                    .text("Owner", width: w >= 1000 ? 150 : 110) { $0.owner },
                    .text("Last activity") { $0.updated },
                ], rows: Array(Mock.deals.prefix(5)), rowHeight: 46, selected: [2])
                .padding(.horizontal, -1).padding(.bottom, -1)
            }
        }
    }
}

/// Dashboard 的检查栏：报表设置 + AI 摘要（Brisk 7wUm 报表设置 / Omnize ZzxG AI 面板）
struct DashboardInspector: View {
    @State private var period = 1
    @State private var leads = true
    @State private var deals = true
    @State private var forecast = false
    @Environment(\.barly) private var t
    var body: some View {
        InspectorSection("Report settings") {
            Segmented(["Week", "Month", "Quarter"], selection: $period, height: 34, style: BarlyTokens.Product.caption, fullWidth: true)
            VStack(spacing: 12) {
                Toggle(isOn: $leads) { setting("Leads & conversion") }.toggleStyle(.barly)
                Toggle(isOn: $deals) { setting("Active deals table") }.toggleStyle(.barly)
                Toggle(isOn: $forecast) { setting("Revenue forecast") }.toggleStyle(.barly)
            }
            .padding(.top, 4)
        }
        InspectorSection("AI summary", action: "2 min ago") {
            HStack(spacing: 8) {
                BarlyIcon("barly.radiant", size: 16, color: t.accentText)
                MonoLabel("Generated", color: t.text3)
            }
            Text("Leads are up 8% on the week, driven by Northwind and Helio. Two deals above $30k are stuck in Demo for 9+ days.")
                .barlyText(.product.body.leading(21), color: t.text2)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(["Draft a nudge for Quill & Co.", "Why did CLV dip?", "Forecast next quarter"], id: \.self) { q in
                    HStack {
                        Text(q).barlyText(.product.body, color: t.text2)
                        Spacer()
                        BarlyIcon("arrow.up.right", size: 13, color: t.text3)
                    }
                    .padding(.horizontal, 12).frame(height: 36)
                    .background(RoundedRectangle(cornerRadius: BarlyRadius.sm, style: .continuous).fill(t.softSurface))
                }
            }
        }
        InspectorSection("Owners") {
            VStack(spacing: 10) {
                ForEach([("Janson W.", "$79.6k", 0.82), ("Mia Chen", "$34.8k", 0.46), ("Ava Patel", "$8.9k", 0.14)], id: \.0) { o in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Avatar(o.0, size: 22)
                            Text(o.0).barlyText(.product.body, color: t.text)
                            Spacer()
                            Text(o.1).barlyText(FamilyType.numeric(BarlyTokens.Product.body), color: t.text2)
                        }
                        ProgressBar(o.2, height: 4, color: t.dataBase)
                    }
                }
            }
        }
    }
    private func setting(_ s: String) -> some View {
        HStack { Text(s).barlyText(.product.body, color: t.text2); Spacer() }
    }
}

// MARK: - AI Chat（Lumeo 式：窄图标侧栏 + 问候空状态 / 对话中）

/// AI Chat：外壳按身份骨架切换（rail / rail-list / sidebar / sidebar-gray），inspector=true 时上下文卡进右栏
public struct AIChatScreen: View {
    let thread: Bool
    public var onNavigate: (String) -> Void
    public init(thread: Bool, onNavigate: @escaping (String) -> Void = { _ in }) { self.thread = thread; self.onNavigate = onNavigate }
    public var body: some View {
        var spec = AIChatPane.spec
        spec.selection = thread ? "chat" : "home"
        spec.listSelection = thread ? "k" : nil
        return AppShell(spec, onSelect: onNavigate) {
            AIChatPane(thread: thread)
        } inspector: {
            AIChatPane(thread: thread, inspectorPart: true)
        }
    }
}

struct AIChatPane: View {
    let thread: Bool
    var inspectorPart = false
    @State private var text = ""
    @State private var citation = true
    @State private var followCitation = false
    @Environment(\.barly) private var t

    static let railItems = [
        SidebarNavItem("home", icon: "house", title: "Home"),
        SidebarNavItem("chat", icon: "bubble.left", title: "Chat"),
        SidebarNavItem("history", icon: "clock.arrow.circlepath", title: "History"),
        SidebarNavItem("agents", icon: "cpu", title: "Agents"),
        SidebarNavItem("files", icon: "folder", title: "Files"),
        SidebarNavItem("flows", icon: "point.3.connected.trianglepath.dotted", title: "Flows"),
        SidebarNavItem("data", icon: "cylinder.split.1x2", title: "Data"),
        SidebarNavItem("dashboard", icon: "square.grid.2x2", title: "Dashboard"),
    ]

    static var spec: ShellSpec {
        ShellSpec(brand: (Mock.brand, "AI Workspace"), workspace: "Personal", nav: railItems, selection: "home",
                  footer: [SidebarNavItem("settings", icon: "gearshape", title: "Settings"),
                           SidebarNavItem("help", icon: "headphones", title: "Help Center")],
                  user: ("Jason Reed", "jason@reed.studio"),
                  listTitle: "Chats", listAction: "New chat",
                  list: [ShellListSection("Recents", [ShellListItem("k", "Weekend in Kyoto", detail: "Now"),
                                                      ShellListItem("q", "Q3 board memo outline", detail: "2h"),
                                                      ShellListItem("s", "SQL for churn cohort", detail: "Yday"),
                                                      ShellListItem("r", "Rewrite onboarding email", detail: "Mon")]),
                         ShellListSection("Projects", [ShellListItem("p1", "Travel", icon: "folder"),
                                                       ShellListItem("p2", "Launch plan", icon: "folder"),
                                                       ShellListItem("p3", "Research notes", icon: "folder")])])
    }

    var body: some View {
        if inspectorPart {
            if thread { contextPanel } else { emptyInspector }
        } else {
            VStack(spacing: 0) {
                topBar
                if thread { threadBody } else { emptyBody }
            }
        }
    }

    @Environment(\.barlyContentWidth) private var w
    @Environment(\.barlyInspector) private var inspector

    /// 空状态的检查栏：对话设置 + 固定来源
    @ViewBuilder private var emptyInspector: some View {
        InspectorSection("Thread settings") {
            VStack(alignment: .leading, spacing: 12) {
                settingRow("Model", "\(Mock.brand) 2")
                settingRow("Tone", "Casual")
                settingRow("Language", "Auto")
                Toggle(isOn: $citation) { HStack { Text("Cite sources").barlyText(.product.body, color: t.text2); Spacer() } }.toggleStyle(.barly)
            }
        }
        InspectorSection("Pinned sources", action: "3") {
            VStack(spacing: 8) {
                ForEach([("Brand guidelines.pdf", "doc.text"), ("Q3 metrics.csv", "tablecells"), ("Kyoto trip notes", "note.text")], id: \.0) { f in
                    HStack(spacing: 10) {
                        BarlyIcon(f.1, size: 15, color: t.text2)
                        Text(f.0).barlyText(.product.body, color: t.text2)
                        Spacer()
                    }
                    .padding(.horizontal, 12).frame(height: 38)
                    .background(RoundedRectangle(cornerRadius: BarlyRadius.sm, style: .continuous).fill(t.softSurface))
                }
            }
        }
    }

    private func settingRow(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).barlyText(.product.body, color: t.text2)
            Spacer()
            Text(v).barlyText(.product.body.weight(500), color: t.text)
            BarlyIcon("chevron.up.chevron.down", size: 11, color: t.text3)
        }
    }

    private var topBar: some View {
        HStack(spacing: 16) {
            DropdownButton("\(Mock.brand) 2", icon: "sparkles", size: .lg)
            if thread && w >= 1000 {
                DropdownButton("Casual", size: .lg)
                Spacer()
                HStack(spacing: 8) {
                    BarlyIcon("plus", size: 15, color: t.text2)
                    Text("Collection").barlyText(.product.body.size(15), color: t.text2)
                    Text("/").barlyText(.product.body.size(15), color: t.text3)
                    Text("Weekend in Kyoto").barlyText(.product.body.size(15).weight(500), color: t.text)
                }
            }
            Spacer()
            if w >= 1000 { BarlyButton("Search thread", icon: "magnifyingglass", variant: .outline, size: .lg) }
            BarlyButton("Invite", icon: "person.badge.plus", variant: .outline, size: .lg)
            BarlyButton("New Thread", icon: "plus", variant: .primary, size: .lg)   // 顶栏全局动作；发送键是转化（cta）
        }
        .padding(.horizontal, 32)
        .frame(height: thread ? 80 : 88)
        .overlay(alignment: .bottom) { if thread { Hairline() } }
    }

    /// 问候区列宽：856（Lumeo），内容区窄时收
    private var colW: CGFloat { min(856, w - 96) }

    private var emptyBody: some View {
        VStack(spacing: 0) {
            Orb(diameter: 80, tone: .vivid).padding(.top, 72)
            TwoToneHeading("Good Afternoon, Jason", "What’s on your mind?",
                           style: BarlyTokens.Product.pageTitle.size(40).leading(52).tracked(-0.02),
                           keyword: "your mind?", mutedSecond: false)
                .padding(.top, 44)
            DesktopComposer(text: $text, citation: $citation)
                .frame(width: colW)
                .padding(.top, 48)
            VStack(alignment: .leading, spacing: 16) {
                MonoLabel("Get started with an example below")
                let cards = Group {
                    ExampleCard("Write a to-do list for a personal project", icon: "person")
                    ExampleCard("Generate an email to reply to a job offer", icon: "envelope")
                    ExampleCard("Summarize this article in one paragraph", icon: "bubble.left")
                    ExampleCard("How does AI work in a technical capacity", icon: "chevron.left.forwardslash.chevron.right")
                }
                if colW >= 760 { HStack(spacing: 16) { cards } } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) { cards }
                }
            }
            .frame(width: colW)
            .padding(.top, 56)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var threadBody: some View {
        HStack(alignment: .top, spacing: 64) {
            ZStack(alignment: .bottom) {
                BarlyScroll {
                    VStack(alignment: .leading, spacing: 0) {
                        UserBubble("Plan a slow weekend in Kyoto", style: .tint, maxWidth: 420, textStyle: BarlyTokens.Product.body.size(16))
                            .padding(.top, 24)
                        sectionTitle("Sources", icon: "link").padding(.top, 28)
                        HStack(spacing: 12) {
                            SourceCard("Arashiyama at dawn", domain: "japan-guide.com", index: 1, icon: SourceIcon(t.info, glyph: "star.fill"))
                            SourceCard("Kyoto’s quiet temples", domain: "insidekyoto.com", index: 2, icon: SourceIcon(t.info, glyph: "star.fill"))
                            SourceCard("Two days, no rush", domain: "nytimes.com", index: 3, icon: SourceIcon(t.info, glyph: "star.fill"))
                            Text("+3 More").barlyText(.product.body, color: t.text2)
                                .frame(width: 80, height: 80)
                                .background(RoundedRectangle(cornerRadius: BarlyRadius.md, style: .continuous).fill(t.softSurface))
                        }
                        .padding(.top, 16)
                        sectionTitle("Results", icon: "barly.radiant").padding(.top, 32)
                        AIMessage(feedback: false) {
                            AIParagraph("Here’s an unhurried two-day plan that avoids the tour-bus hours:", style: BarlyTokens.Product.body.size(16).leading(28))
                            Text("Day 1 — West Kyoto").barlyText(.product.body.size(16).weight(600), color: t.text)
                            AIBullets(["Arashiyama bamboo grove before 7:30, then Okochi-Sanso villa garden.",
                                       "Lunch at Shoraian (tofu kaiseki) — book the river-view room.",
                                       "Late afternoon walk along the Hozu river; sunset at Togetsukyo bridge."],
                                      style: BarlyTokens.Product.body.size(16).leading(26))
                            Text("Day 2 — Higashiyama").barlyText(.product.body.size(16).weight(600), color: t.text)
                            AIBullets(["Kiyomizu-dera at opening (6:00) before the school groups arrive.",
                                       "Walk Sannenzaka → Ninenzaka; coffee at % Arabica Higashiyama.",
                                       "Evening: Gion Shirakawa canal, dinner at Gion Karyo (counter seats)."],
                                      style: BarlyTokens.Product.body.size(16).leading(26))
                            CodeBlock(language: "json", code: "{ \"day\": 1, \"start\": \"07:00\", \"stops\": 3, \"walk_km\": 6.4 }",
                                      codeStyle: BarlyTokens.Product.body.monospaced.leading(22))
                        }
                        .padding(.top, 14)
                        HStack(spacing: 10) {
                            BarlyButton("Share", icon: "arrowshape.turn.up.right", variant: .outline, size: .sm)
                            BarlyButton("Export", icon: "square.and.arrow.down", variant: .outline, size: .sm)
                            BarlyButton("Rewrite", icon: "pencil.line", variant: .outline, size: .sm)
                            Spacer()
                            BarlyButton("Copy", icon: "doc.on.doc", variant: .outline, size: .sm)
                            IconButton("ellipsis", size: 30, style: .ghost)
                        }
                        .padding(.top, 18)
                        .padding(.bottom, 110)
                    }
                }
                DesktopComposer("Ask follow up question", text: $text, citation: $followCitation, compact: true)
                    .padding(.bottom, 24)
                    .background(LinearGradient(colors: [t.bg.opacity(0), t.bg], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.25)))
            }
            .frame(width: threadW)
            if showSideContext { VStack(spacing: 16) { contextPanel }.frame(width: 305).padding(.top, 20) }
        }
        .padding(.leading, threadLead)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// 有检查栏时上下文卡进检查栏；没有时内容区够宽（≥ 1150）才在对话列右侧并排
    private var showSideContext: Bool { !inspector && w >= 1150 }
    private var threadW: CGFloat { min(720, w - 96) }
    private var threadLead: CGFloat { showSideContext ? max(40, min(120, w - 720 - 64 - 305 - 40)) : max(40, (w - threadW) / 2) }

    private func sectionTitle(_ s: String, icon: String) -> some View {
        HStack(spacing: 10) {
            BarlyIcon(icon, size: 19, color: t.text)
            Text(s).barlyText(.product.pageTitle.size(18), color: t.text)
        }
    }

    @ViewBuilder private var contextPanel: some View {
            Card {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Sources").barlyText(.product.sectionTitle.size(18), color: t.text)
                    Text("Add from connected knowledge or upload to thread.").barlyText(.product.body, color: t.text2)
                        .multilineTextAlignment(.center).frame(maxWidth: .infinity)
                        .padding(.vertical, 22)
                        .background(RoundedRectangle(cornerRadius: BarlyRadius.md, style: .continuous).fill(t.softSurface))
                    HStack(spacing: 10) {
                        BarlyButton("Upload file", icon: "paperclip", variant: .outline, size: .sm, fullWidth: true)
                        BarlyButton("Upload media", icon: "photo", variant: .outline, size: .sm, fullWidth: true)
                    }
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Suggested tasks").barlyText(.product.sectionTitle.size(18), color: t.text)
                    HStack(spacing: 8) { suggestion("Book Shoraian"); suggestion("Map the walk") }
                    suggestion("Check temple opening hours")
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggested questions").barlyText(.product.sectionTitle.size(18), color: t.text).padding(.bottom, 4)
                    ForEach(["Is it crowded in late October?", "Which pass covers the trains?", "Any vegetarian kaiseki nearby?"], id: \.self) {
                        suggestion($0).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
    }

    private func suggestion(_ s: String) -> some View {
        Text(s).barlyText(.product.body, color: t.text2)
            .padding(.horizontal, 12).padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: BarlyRadius.sm, style: .continuous).fill(t.softSurface))
    }
}
