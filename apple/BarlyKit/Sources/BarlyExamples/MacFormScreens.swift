import SwiftUI
import BarlyKit

// macOS 形态样板（--mac-form window|menubar|panel）+ dna v2 复刻屏（Enigma Traces、Rekann Dashboard）。
// 复刻屏与 Web 模板 /ref/enigma、/ref/rekann 同数据同结构，参考原图：vibe-coding/_re/barly/x/ref-*.png。

// MARK: - 菜单栏弹窗样板（360×520）

public struct MenuBarExampleScreen: View {
    public init() {}
    public var body: some View {
        MenuBarPopover(title: BarlyTokens.name, subtitle: "已同步 · 2 分钟前") { MenuBarExampleBody() }
    }
}

/// 菜单栏弹窗的样板内容（App/macOS/menubar 直接套在 MenuBarPopover 里用）
public struct MenuBarExampleBody: View {
    @Environment(\.barly) private var t
    public init() {}
    public var body: some View {
        Group {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    BarlyIcon("magnifyingglass", size: 14, color: t.text3)
                    Text("搜索收件箱…").barlyText(.product.body, color: t.text3)
                    Spacer(); KeyCombo(["⌘", "F"], boxed: true)
                }
                .padding(.horizontal, 10).frame(height: 34)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(t.fill1))
                .padding(12)
                LauncherSection("今天")
                VStack(spacing: 2) {
                    LauncherRow("周会纪要", subtitle: "10:30 · 产品组", icon: "doc.text", tone: 3, trailing: "3m", selected: true)
                    LauncherRow("报销审批", subtitle: "4 条待处理", icon: "checkmark.seal", tone: 1, trailing: "1h")
                    LauncherRow("新同事入职", subtitle: "Lucas Martin · 周一", icon: "person.badge.plus", tone: 2, trailing: "昨天")
                }.padding(.horizontal, 6)
                HStack(spacing: 8) {
                    Text("本周完成").barlyText(.product.caption, color: t.text3)
                    Spacer()
                    Text("18 / 24").barlyText(.monoText(12), color: t.text2)
                }
                .padding(.horizontal, 16).padding(.top, 14)
                ProgressBar(0.75).padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 14)
            }
        }
    }
}

// MARK: - 浮动面板样板（680×420）

public struct LauncherExampleScreen: View {
    public init() {}
    public var body: some View {
        LauncherPanel(query: "报销") {
            LauncherSection("最佳匹配")
            LauncherRow("报销审批", subtitle: "4 条待处理 · 财务", icon: "checkmark.seal", tone: 1, trailing: "工作流", selected: true)
            LauncherSection("文档")
            LauncherRow("2026 年差旅报销规则", subtitle: "更新于 10 月 12 日", icon: "doc.text", tone: 3, trailing: "文档")
            LauncherRow("报销单模板", subtitle: "共享 · 12 人使用", icon: "tablecells", tone: 5, trailing: "模板")
            LauncherSection("命令")
            LauncherRow("新建报销单", icon: "plus", tone: 2, trailing: "⌘N")
        }
        .padding(0)
    }
}

// MARK: - 设置窗口样板（680×460）

public struct SettingsWindowExampleScreen: View {
    @Environment(\.barly) private var t
    public init() {}
    public var body: some View {
        SettingsWindow(panes: [
            .init("general", title: "通用", icon: "gearshape"),
            .init("appearance", title: "外观", icon: "paintbrush"),
            .init("shortcuts", title: "快捷键", icon: "command"),
            .init("account", title: "账户", icon: "person.crop.circle"),
        ], selection: "general") {
            Text("通用").barlyText(.product.pageTitle, color: t.text)
            SettingsGroup("启动", compact: true) {
                SettingsRow("登录时打开", detail: "开机后自动在菜单栏常驻", first: true, compact: true) { Toggle("", isOn: .constant(true)).labelsHidden().toggleStyle(BarlyToggleStyle()) }
                SettingsRow("显示 Dock 图标", compact: true) { Toggle("", isOn: .constant(false)).labelsHidden().toggleStyle(BarlyToggleStyle()) }
            }
            SettingsGroup("同步", compact: true) {
                SettingsRow("同步间隔", first: true, compact: true) { DropdownButton("15 分钟", size: .sm) }
                SettingsRow("数据位置", detail: "~/Library/Application Support", compact: true) { BarlyButton("在访达中显示", size: .sm) }
            }
            SettingsGroup("全局快捷键", compact: true) {
                SettingsRow("呼出面板", first: true, compact: true) { KeyCombo(["⌥", "Space"]) }
            }
        }
    }
}

// MARK: - 复刻屏：Enigma — AI Agent Dashboard — Traces（1440×991，深色）

public struct EnigmaTracesScreen: View {
    @Environment(\.barly) private var t
    public init() {}
    static let traces: [Double] = [0.35, 0.82, 0.25, 0.42, 0.18, 0.3, 0.12, 0.62, 0.3, 0.22, 0.12, 0.35, 0.18, 0.12, 0.45, 0.35, 0.3, 0.22, 0.62, 0.48, 0.8, 0.55, 0.18, 0.3, 0.35, 0.42, 0.18, 0.12, 0.28, 0.5, 0.2, 0.35, 0.22, 0.12, 0.3, 0.25, 0.62, 0.42, 0.3, 0.18, 0.35, 0.28, 0.15, 0.3, 0.22].map { min(1, 0.22 + $0 * 0.85) }
    static let latency: [(Double, Double)] = [(3.4, 1.7), (1.5, 3.3), (2.6, 1.3), (3.8, 3.0), (2.4, 0.9), (2.4, 0.4), (1.0, 0.8), (3.2, 2.8), (1.3, 2.9), (2.0, 1.0), (2.6, 1.0)]
    struct Row: Identifiable { let id = UUID(); let name, desc, icon: String; let prod: Bool; let traces, err: String; let errHigh: Bool; let p50, p99, cost: String; let vol: [Double]; let last: String }
    static let rows: [Row] = [
        .init(name: "Email verifier", desc: "Contact validation tool", icon: "envelope", prod: true, traces: "29,800", err: "5.4%", errHigh: true, p50: "2.1s", p99: "9.1s", cost: "$88.90", vol: [5, 8, 3, 7, 6, 9, 4, 7, 8, 5, 9, 6, 8, 7], last: "1.6s · 3m ago"),
        .init(name: "Web scraper", desc: "Website data collector", icon: "globe", prod: true, traces: "40,560", err: "6.8%", errHigh: true, p50: "2.3s", p99: "7.7s", cost: "$130.65", vol: [8, 6, 5, 7, 3, 4, 3, 6, 5, 7, 8, 9, 7, 9], last: "3.2s · 6m ago"),
        .init(name: "Data visualizer", desc: "Interactive dashboard creator", icon: "chart.bar", prod: true, traces: "33,120", err: "5.9%", errHigh: true, p50: "3.6s", p99: "8.2s", cost: "$175.00", vol: [6, 9, 4, 8, 7, 5, 9, 6, 8, 4, 7, 9, 5, 8], last: "1.0s · 12m ago"),
        .init(name: "Chatbot framework", desc: "Conversational AI system", icon: "text.bubble", prod: false, traces: "38,920", err: "8.0%", errHigh: true, p50: "1.7s", p99: "5.5s", cost: "$220.75", vol: [4, 6, 8, 5, 9, 7, 6, 3, 8, 5, 7, 4, 6, 7], last: "4.9s · 19m ago"),
        .init(name: "Data analyzer", desc: "CSV processing tool", icon: "arrow.triangle.2.circlepath", prod: false, traces: "35,620", err: "1.5%", errHigh: false, p50: "2.5s", p99: "9.5s", cost: "$180.75", vol: [7, 5, 9, 6, 8, 4, 7, 9, 5, 8, 6, 9, 7, 5], last: "3.0s · 25m ago"),
        .init(name: "Doc extractor", desc: "PDF retrieval pipeline", icon: "doc.text", prod: false, traces: "42,180", err: "1.8%", errHigh: false, p50: "3.8s", p99: "11.2s", cost: "$245.20", vol: [9, 8, 9, 7, 4, 5, 3, 6, 8, 5, 7, 4, 6, 5], last: "1.2s · 32m ago"),
    ]

    public var body: some View {
        HStack(spacing: 0) {
            WorkspaceRail(logo: "asterisk", items: [.init("enigma", icon: "dot.radiowaves.left.and.right", tone: 1), .init("flux", icon: "sparkle", tone: 2), .init("stack", icon: "square.stack.3d.up", tone: 4), .init("nova", icon: "sparkle", tone: 3)],
                          active: "enigma", bottom: ["lifepreserver", "person.2", "gearshape"])
            sidebar
            main
        }
        .background(t.bg)
    }

    private var logo: some View {
        BarlyIcon("dot.radiowaves.left.and.right", size: 14, color: .white).frame(width: 26, height: 26)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(t.accent))
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 10) { logo; Text(BarlyTokens.name).barlyText(.product.body.size(16).weight(500), color: t.text); Spacer(); BarlyIcon("chevron.left.2", size: 13, color: t.text2) }
                .padding(.horizontal, 8).frame(height: 58)
            NavGroupLabel("Overview")
            NavRowV2("Dashboard", icon: "house")
            NavRowV2("Requests", icon: "doc.text", trailing: AnyView(Text("40").barlyText(.monoText(12), color: t.text2)))
            NavRowV2("Sessions", icon: "square.stack")
            NavRowV2("Traces", icon: "viewfinder", selected: true)
            NavRowV2("Models", icon: "cube")
            NavRowV2("Evaluations", icon: "flask")
            NavGroupLabel("Manage")
            NavRowV2("Prompts", icon: "character.book.closed")
            NavRowV2("Datasets", icon: "cylinder.split.1x2")
            NavRowV2("Playground", icon: "terminal")
            Spacer()
            NavGroupLabel("Monitor")
            NavRowV2("Rate Limits", icon: "timer")
            NavRowV2("Settings", icon: "gearshape", trailing: AnyView(KeyCombo(["⇧", "⌘"])))
            NavRowV2("Help & Support", icon: "questionmark.circle", trailing: AnyView(BarlyIcon("chevron.right", size: 12, color: t.text2)))
            HStack(spacing: 10) {
                Avatar("Jason Reed", size: 32)
                VStack(alignment: .leading, spacing: 1) { Text("jason@enigma.com").barlyText(.product.small.weight(500), color: t.text).lineLimit(1); Text("Operations").barlyText(.product.caption, color: t.text2) }
                Spacer(); BarlyIcon("chevron.up.chevron.down", size: 12, color: t.text2)
            }
            .padding(10).background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(t.surface)).padding(.top, 10)
        }
        .padding(.horizontal, 12).padding(.bottom, 12)
        .frame(width: 236).frame(maxHeight: .infinity)
        .background(t.sidebarBg)
        .overlay(alignment: .trailing) { Rectangle().fill(t.border).frame(width: 1) }
    }

    private func select(_ title: String, icon: AnyView, width: CGFloat) -> some View {
        HStack(spacing: 8) { icon; Text(title).barlyText(.product.body.weight(500), color: t.text).lineLimit(1).fixedSize(); Spacer(minLength: 0); BarlyIcon("chevron.down", size: 11, color: t.text2) }
            .padding(.horizontal, 10).frame(width: width, height: 34)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(t.surface))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(t.border, lineWidth: 1))
    }

    private func card<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        // 多个子视图必须先包进 VStack：直接对 TupleView 加修饰符，SwiftUI 会把每个子视图各包一张卡
        VStack(alignment: .leading, spacing: 0) { c() }.padding(18).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(t.surface))
    }

    private var main: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                HStack(spacing: 7) { BarlyIcon("viewfinder", size: 14, color: t.text); Text("Traces").barlyText(.product.body.weight(500), color: t.text) }
                    .padding(.horizontal, 10).frame(height: 34).overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(t.border, lineWidth: 1))
                Spacer()
                HStack(spacing: 8) { BarlyIcon("magnifyingglass", size: 14, color: t.text3); Text("Search…").barlyText(.product.body, color: t.text3); Spacer(); KeyCombo(["⌘", "K"], boxed: true) }
                    .padding(.horizontal, 10).frame(width: 250, height: 34)
                    .background(RoundedRectangle(cornerRadius: 8).fill(t.surface)).overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(t.border, lineWidth: 1))
                BarlyButton("Share", icon: "square.and.arrow.up", size: .sm)
            }
            .padding(.horizontal, 20).frame(height: 58)
            Rectangle().fill(t.border).frame(height: 1)
            VStack(spacing: 16) {
                HStack(spacing: 10) {
                    select(BarlyTokens.name, icon: AnyView(logo.scaleEffect(0.8)), width: 140)
                    select("Last 30 days", icon: AnyView(BarlyIcon("calendar", size: 14, color: t.text2)), width: 166)
                    select("All models", icon: AnyView(BarlyIcon("square.stack.3d.up", size: 14, color: t.text2)), width: 150)
                    Spacer()
                    HStack(spacing: 7) { BarlyIcon("clock", size: 14, color: t.text2); Text("Retention").barlyText(.product.body, color: t.text); Text("14d").barlyText(.monoText(11), color: t.text2).padding(.horizontal, 5).padding(.vertical, 1).background(RoundedRectangle(cornerRadius: 4).fill(t.fill2)) }
                        .padding(.horizontal, 10).frame(height: 34).overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(t.border, lineWidth: 1))
                    BarlyButton("New", icon: "plus.circle", variant: .primary, size: .sm, split: true)
                }
                BarlyBanner(lead: "Need help or want guidance?", "You can explore the tutorial session at any time.") {
                    BarlyButton("Dismiss", size: .sm); BarlyButton("Explore", variant: .primary, size: .sm)
                }
                HStack(spacing: 16) {
                    card {
                        HStack { Text("Traces").barlyText(.product.sectionTitle, color: t.text); Spacer(); BarlyButton("All projects", icon: "line.3.horizontal.decrease", trailingIcon: "chevron.down", size: .sm); BarlyButton("Filter", icon: "line.3.horizontal.decrease", trailingIcon: "chevron.down", size: .sm) }
                            .padding(.bottom, 16)
                        DotMatrix(values: Self.traces, rows: 14, cell: 9, gap: 4.5, yTicks: ["10.0 K", "7.5 K", "5.0 K", "2.5 K", "0%"], xLabels: ("30 Jul", "29 Aug"))
                    }
                    card {
                        HStack { Text("Latency").barlyText(.product.sectionTitle, color: t.text); Spacer(); BarlyIcon("ellipsis", size: 14, color: t.text2) }
                        DotLegend([("P50", t.accent), ("P99", t.text)]).padding(.vertical, 12)
                        PairedBars(pairs: Self.latency, max: 4, height: 150, yTicks: ["4s", "3s", "2s", "1s", "0"], xLabels: ("30 Jul", "29 Aug"))
                    }
                    .frame(width: 330)
                }
                .frame(height: 300)
                table
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(t.canvas)
    }

    private var table: some View {
        VStack(spacing: 0) {
            HStack(spacing: 24) {
                VStack(spacing: 0) { Text("Recent projects").barlyText(.product.body.weight(500), color: t.text).frame(height: 46); Rectangle().fill(t.accent).frame(height: 2) }.fixedSize()
                ForEach(["Recent errors", "Most expensive runs", "Top models"], id: \.self) { Text($0).barlyText(.product.body, color: t.text2) }
                Spacer()
            }
            .padding(.horizontal, 18)
            Rectangle().fill(t.border).frame(height: 1)
            row(header: true, Self.rows[0])
            ForEach(Self.rows) { r in Rectangle().fill(t.border).frame(height: 1); row(header: false, r) }
        }
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(t.surface))
    }

    @ViewBuilder private func row(header: Bool, _ r: Row) -> some View {
        let cols: [CGFloat] = [250, 90, 80, 86, 112, 86, 128]
        HStack(spacing: 14) {
            Checkbox(false)
            if header {
                Text("Projects").barlyText(.product.small, color: t.text2).frame(width: cols[0], alignment: .leading)
                ForEach(Array(["Status", "Traces", "Error rate", "p50/P99", "Cost", "Vol (30d)"].enumerated()), id: \.offset) { i, h in Text(h).barlyText(.product.small, color: t.text2).frame(width: cols[i + 1], alignment: .leading) }
                Text("Last activity").barlyText(.product.small, color: t.text2)
            } else {
                HStack(spacing: 10) {
                    IconTile(r.icon, size: 30, multi: false, iconColor: t.accent)
                    VStack(alignment: .leading, spacing: 1) { Text(r.name).barlyText(.product.body.weight(500), color: t.text); Text(r.desc).barlyText(.product.caption, color: t.text2) }
                }.frame(width: cols[0], alignment: .leading)
                Group { if r.prod { Chip("prod", tone: .success, mono: false) } else { Chip("staging", tone: .info, mono: false) } }.frame(width: cols[1], alignment: .leading)
                Text(r.traces).barlyText(.monoText(13), color: t.text).frame(width: cols[2], alignment: .leading)
                Chip(r.err, tone: r.errHigh ? .danger : .warning).frame(width: cols[3], alignment: .leading)
                (Text(r.p50).foregroundColor(t.text) + Text(" /" + r.p99).foregroundColor(t.text3)).barlyText(.monoText(13)).frame(width: cols[4], alignment: .leading)
                Text(r.cost).barlyText(.monoText(13), color: t.text).frame(width: cols[5], alignment: .leading)
                MiniBars(r.vol, width: 110, height: 20).frame(width: cols[6], alignment: .leading)
                Text(r.last).barlyText(.product.small, color: t.text2).lineLimit(1).fixedSize()
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18).frame(height: header ? 42 : 52)
    }
}

// MARK: - 复刻屏：Rekann — AI HR Workspace — Dashboard（1440×1029，浅色 · 灰壳白卡 · 多色图标块 · 助手面板）

public struct RekannDashboardScreen: View {
    @Environment(\.barly) private var t
    public init() {}
    public var body: some View {
        HStack(spacing: 0) {
            sidebar
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    BarlyIcon("square.grid.2x2", size: 14, color: t.text2); Text("Dashboard").barlyText(.product.body, color: t.text)
                    Spacer()
                    Text("14:57:04").barlyText(.monoText(13), color: t.text); Text("Berlin (GMT+1)").barlyText(.product.body, color: t.text3)
                    BarlyIcon("bell", size: 15, color: t.text).frame(width: 32, height: 32).overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(t.border, lineWidth: 1))
                    BarlyButton("Assistant", icon: "note.text", size: .sm)
                }
                .padding(.horizontal, 22).frame(height: 52).background(t.canvas)
                Rectangle().fill(t.border).frame(height: 1)
                HStack(spacing: 0) { main; assistant }
            }
        }
        .background(t.slot)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 9) {
                BarlyIcon("note.text", size: 12, color: .white).frame(width: 22, height: 22).background(RoundedRectangle(cornerRadius: 6).fill(t.accent))
                Text(BarlyTokens.name).barlyText(.product.body.size(16).weight(500), color: t.text); Spacer(); BarlyIcon("sidebar.left", size: 14, color: t.text2)
            }.padding(.horizontal, 6).frame(height: 56)
            HStack(spacing: 9) { Text("U").barlyText(.product.caption.weight(600), color: t.bg).frame(width: 18, height: 18).background(RoundedRectangle(cornerRadius: 5).fill(t.text)); Text("Uxer Digital").barlyText(.product.body, color: t.text); Spacer() }
                .padding(.horizontal, 10).frame(height: 36).background(RoundedRectangle(cornerRadius: 9).fill(t.surface)).overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(t.border, lineWidth: 1)).padding(.bottom, 8)
            NavRowV2("Dashboard", icon: "square.grid.2x2", selected: true)
            NavRowV2("Rekann AI", icon: "note.text"); NavRowV2("Team directory", icon: "person.2"); NavRowV2("Company", icon: "building.2"); NavRowV2("Daily report", icon: "list.clipboard")
            NavGroupLabel("Time"); NavRowV2("Attendance", icon: "clock"); NavRowV2("Leaves", icon: "calendar.badge.minus"); NavRowV2("Permissions", icon: "calendar.badge.clock")
            NavGroupLabel("Personal"); NavRowV2("Documents", icon: "doc"); NavRowV2("Payslips", icon: "doc.plaintext")
            NavGroupLabel("Management"); NavRowV2("Attendance report", icon: "doc.badge.clock"); NavRowV2("Review report", icon: "square.and.pencil"); NavRowV2("Approvals", icon: "calendar.badge.checkmark"); NavRowV2("Announcements", icon: "megaphone")
            Spacer()
            HStack(spacing: 9) { OrbAvatar(hue: 300, size: 24); Text("Barly").barlyText(.product.body, color: t.text); Spacer(); BarlyIcon("moon", size: 14, color: t.text2); BarlyIcon("gearshape", size: 14, color: t.text2) }.padding(.horizontal, 6)
        }
        .padding(.horizontal, 12).padding(.bottom, 14)
        .frame(width: 248).frame(maxHeight: .infinity)
        .background(t.sidebarBg)
    }

    private func card<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 0) { c() }.padding(20).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(t.surface))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(t.border, lineWidth: 1))
    }

    private var main: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Good morning, Barly").barlyText(.product.pageTitle.size(26), color: t.text)
                Text("Here is your workforce overview and HR insights for today.").barlyText(.product.body, color: t.text2)
            }
            HStack(spacing: 18) {
                ForEach([("Present today", "18", "Employees present"), ("Pending approvals", "8", "Awaiting decision"), ("Reports missing today", "20", "Haven't submitted yet")], id: \.0) { k in
                    card { Text(k.0).barlyText(.product.body, color: t.text); Text(k.1).barlyText(.product.heroNumber, color: t.text).padding(.top, 12); Text(k.2).barlyText(.product.caption, color: t.text2).padding(.top, 2) }
                }
            }.frame(height: 118)
            HStack(spacing: 18) {
                card {
                    HStack { Text("Needs your attention").barlyText(.product.sectionTitle, color: t.text); Spacer(); Text("See all ›").barlyText(.product.small, color: t.text2) }.padding(.bottom, 6)
                    ForEach([("calendar.badge.minus", 1, "Time-off requests", "4 time-off requests awaiting approval"), ("clock", 2, "Attendance", "4 attendance records need review"), ("person.badge.plus", 3, "New hires", "2 new employees don't have a manager"), ("calendar.badge.clock", 4, "Permissions", "4 requests awaiting approval")], id: \.2) { a in
                        HStack(spacing: 12) {
                            IconTile(a.0, tone: a.1, size: 38)
                            VStack(alignment: .leading, spacing: 2) { Text(a.2).barlyText(.product.body, color: t.text); Text(a.3).barlyText(.product.caption, color: t.text2).lineLimit(1) }
                            Spacer(); BarlyButton("Review", size: .sm)
                        }.padding(.vertical, 7)
                    }
                }
                StickyNote()
            }.frame(height: 290)
            HStack(spacing: 18) {
                card {
                    Text("Today's Attendance").barlyText(.product.sectionTitle, color: t.text)
                    Text("90%").barlyText(.product.heroNumber, color: t.text).padding(.top, 6)
                    GeometryReader { g in HStack(spacing: 0) { t.accent.frame(width: g.size.width * 0.7); Color(hex: 0xFF8E28).frame(width: g.size.width * 0.04); Color(hex: 0xFF5454).frame(width: g.size.width * 0.04); t.bgMuted } }
                        .frame(height: 20).clipShape(RoundedRectangle(cornerRadius: 5)).padding(.top, 16)
                    ForEach([("On time", "15", t.accent), ("Late", "3", Color(hex: 0xFF8E28)), ("Absent", "2", Color(hex: 0xFF5454))], id: \.0) { l in
                        HStack(spacing: 9) { RoundedRectangle(cornerRadius: 2).fill(l.2).frame(width: 9, height: 9); Text(l.0).barlyText(.product.body, color: t.text); Spacer(); Text(l.1).barlyText(.product.body, color: t.text) }.padding(.top, 14)
                    }
                }
                card {
                    HStack { Text("Who's off today").barlyText(.product.sectionTitle, color: t.text); Spacer(); Text("See all ›").barlyText(.product.small, color: t.text2) }
                    Text("4 employees").barlyText(.product.heroNumber, color: t.text).padding(.top, 6)
                    ForEach([("Oliver Bennett", 40.0, "2 days • 9–10 Feb 2026"), ("Lucas Martin", 285.0, "1 day • 9 Feb 2026"), ("Emma Wilson", 70.0, "3 days • 9–11 Feb 2026")], id: \.0) { p in
                        HStack(spacing: 11) { OrbAvatar(hue: p.1, size: 32); VStack(alignment: .leading, spacing: 1) { Text(p.0).barlyText(.product.body, color: t.text); Text(p.2).barlyText(.product.caption, color: t.text2) }; Spacer(); BarlyIcon("chevron.right", size: 12, color: t.text2) }.padding(.top, 12)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 26).padding(.vertical, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(t.canvas)
    }

    private var assistant: some View {
        AssistantPanel(width: 420, footnote: "AI can make mistakes. Always verify important information.") {
            HStack { Spacer(); Text("Draft a maternity leave policy.").barlyText(.product.body, color: t.text).padding(.horizontal, 14).padding(.vertical, 9).background(RoundedRectangle(cornerRadius: 10).fill(t.bgMuted)) }
            WorkedFor("Worked for 15 seconds")
            Text("I've prepared a draft based on common policies and your current setup.").barlyText(.product.body, color: t.text)
            DraftCard(title: "Maternity leave (draft)", description: "Review maternity leave details before adding them to the leave policy.",
                      rows: [("Category", "Parental leave"), ("Coverage", "Female members"), ("Allowance", "90 calendar days / year"), ("Approval", "Department Manager"), ("Payment", "Fully Paid")],
                      note: "Review this draft in leave settings before creating the policy.") {
                BarlyButton("Create leave policy", variant: .primary, size: .sm)
            }
        } composer: {
            VStack(alignment: .leading, spacing: 12) {
                Text("Ask about your team...").barlyText(.product.body, color: t.text3)
                HStack(spacing: 8) {
                    BarlyIcon("plus", size: 14, color: t.text).frame(width: 30, height: 30).overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(t.border, lineWidth: 1))
                    BarlyIcon("doc", size: 14, color: t.text).frame(width: 30, height: 30).overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(t.border, lineWidth: 1))
                    Spacer()
                    DropdownButton(BarlyTokens.name, size: .sm)
                    BarlyIcon("arrow.up", size: 14, color: .white).frame(width: 30, height: 30).background(RoundedRectangle(cornerRadius: 8).fill(t.accent))
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14).fill(t.surface))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(t.border, lineWidth: 1))
        }
    }
}

// MARK: - 拖放货架样板（--mac-form shelf；Dropover 式，参考 _re/dropover）

public enum ShelfMock {
    public static let files: [ShelfFile] = [
        .init("发布会主视觉.png", kind: "photo", detail: "4.2 MB · PNG", tone: 2),
        .init("Launch Brief.pdf", kind: "doc.text", detail: "1.1 MB · PDF", tone: 4),
        .init("产品截图", kind: "folder", detail: "12 项 · 文件夹", tone: 3),
        .init("演示视频.mov", kind: "film", detail: "86 MB · 影片", tone: 1),
    ]
}

/// 货架叠放态（截图尺寸 260×300：货架 184 宽 + 四周桌面留白）
public struct ShelfExampleScreen: View {
    public init() {}
    public var body: some View { ShelfView(files: ShelfMock.files).padding(30) }
}
/// 货架展开列表态
public struct ShelfListExampleScreen: View {
    public init() {}
    public var body: some View { ShelfView(files: ShelfMock.files, expanded: true).padding(30) }
}
/// 拖入中（空货架 + 强调色描边）
public struct ShelfDropExampleScreen: View {
    public init() {}
    public var body: some View { ShelfView(files: [], dropTarget: true).padding(30) }
}
