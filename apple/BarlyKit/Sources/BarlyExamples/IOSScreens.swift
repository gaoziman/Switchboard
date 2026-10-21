import SwiftUI
import BarlyKit

// MARK: - 顶栏变体

/// 浅色：≡ ······ Get Plus；深色：方键 ≡ · 居中 Get Plus · 方键（Bimbo 深色实测）
struct BimboTopBar: View {
    @Environment(\.barly) private var t
    var body: some View {
        if t.isDark {
            MobileTopBar(leading: { IconButton("barly.menu", size: 38, style: .outline) },
                         center: { GetPlusPill() },
                         trailing: { IconButton("eye.slash", size: 38, style: .outline) })
        } else {
            MobileTopBar(leading: { BarlyIcon("barly.menu", size: 20, color: t.text2) },
                         trailing: { GetPlusPill() })
        }
    }
}

// MARK: - Home：按身份骨架 mobileHome 三选一（references/layouts.md §4）

/// greeting-bottom = Bimbo 问候贴底；hub = Lumix 功能中心；orb-center = 光球居中 + 2×2 建议卡
public struct HomeScreen: View {
    @Environment(\.barlyMobileHome) private var layout
    public init() {}
    public var body: some View {
        switch layout {
        case "hub": LumixHomeScreen()
        case "orb-center": OrbHomeScreen()
        default: GreetingHomeScreen()
        }
    }
}

// MARK: - greeting-bottom（Bimbo）

public struct GreetingHomeScreen: View {
    @State private var text = ""
    @Environment(\.barly) private var t
    public init() {}
    public var body: some View {
        VStack(spacing: 0) {
            BimboTopBar()
            Spacer(minLength: 0)
            if t.isDark {
                // 深色：首页空态内嵌最近对话
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        BarlyIcon("clock.arrow.circlepath", size: 16, color: t.text2)
                        Text("Chat History").barlyText(.mobile.body, color: t.text2)
                        Spacer()
                        BarlyIcon("chevron.right", size: 13, color: t.text2)
                    }
                    HistoryCard("Meeting Record Transcription Analysis", time: "7h ago")
                    HistoryCard("Japanese Mastery: Fun Approach", time: "Yesterday")
                }
                .padding(.horizontal, BarlyMetrics.pageX)
                .padding(.bottom, 28)
            } else {
                Greeting(name: "Martin")
                    .padding(.bottom, 38)
            }
            if !t.isDark {
                QuickChips(Mock.homeChips)
            }
            MobileInput("Ask \(Mock.brand) Anything", text: $text, sendIcon: t.isDark ? "mic" : "arrow.up")
                .padding(.horizontal, BarlyMetrics.pageX)
                .padding(.top, t.isDark ? 0 : 16)
            if t.isDark {
                QuickChips([[QuickChipItem("Deep Search", icon: "dot.radiowaves.left.and.right"),
                             QuickChipItem("Analyse docs", icon: "doc.badge.plus"),
                             QuickChipItem("Summarize", icon: "arrow.down.right.and.arrow.up.left")]], colored: true)
                    .padding(.top, 14)
            }
        }
        .padding(.bottom, 20)
        .screenBackground(ZStack { t.bg; TopWash() })
    }
}

// MARK: - orb-center（Bimbo Plus 光球 + Lumeo 示例卡的移动版）

/// ≡ · 模型 pill · 头像 → 光球 164 居中偏上 → 问候两行居中 → 2×2 建议卡（浅灰无边 r = md，左上两行说明、左下图标）→ 底部输入框
public struct OrbHomeScreen: View {
    @State private var text = ""
    @Environment(\.barly) private var t
    public init() {}
    static let ideas: [(String, String)] = [("Plan a slow weekend in Kyoto", "map"), ("Summarize this PDF in 5 bullets", "doc.text"),
                                            ("Draft a reply to the landlord", "envelope"), ("Explain RAG like I’m new", "lightbulb")]
    public var body: some View {
        VStack(spacing: 0) {
            MobileTopBar(leading: { BarlyIcon("barly.menu", size: 20, color: t.text2) },
                         center: { ModelPill("\(Mock.brand) 2") },
                         trailing: { Avatar("Martin Kowalski", size: 34, tint: 1) })
            Spacer(minLength: 8)
            Orb(diameter: 164, tone: .auto)
            Greeting(name: "Martin", question: "What shall we start with?")
                .padding(.top, 40)
            Spacer(minLength: 20)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(Array(Self.ideas.enumerated()), id: \.offset) { i, idea in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(idea.0).barlyText(.mobile.caption.leading(18), color: t.text2).lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 10)
                        BarlyIcon(idea.1, size: 17, color: t.text)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, minHeight: 96, maxHeight: 96, alignment: .topLeading)
                    .background(ideaBackground(i))
                }
            }
            .padding(.horizontal, BarlyMetrics.pageX)
            MobileInput("Ask \(Mock.brand) Anything", text: $text)
                .padding(.horizontal, BarlyMetrics.pageX)
                .padding(.top, 16)
        }
        .padding(.bottom, 20)
        .screenBackground(ZStack { t.bg; TopWash(amount: 0.04) })
    }

    @ViewBuilder private func ideaBackground(_ i: Int) -> some View {
        switch BarlyFamily.current.surface {
        case .rule, .grid, .thick:
            Rectangle().fill(.clear).overlay(Rectangle().strokeBorder(BarlyFamily.current == .brutal ? t.text : t.border, lineWidth: BarlyFamily.current.stroke))
        case .block:
            RoundedRectangle(cornerRadius: BarlyRadius.lg, style: .continuous).fill(t.pastels[i % 3].opacity(0.75))
        default:
            RoundedRectangle(cornerRadius: BarlyRadius.md, style: .continuous).fill(t.softSurface)
        }
    }
}

// MARK: - Chat 对话中（表格 + 代码块 + 来源 + 过程卡）

public struct ChatScreen: View {
    @State private var text = ""
    @Environment(\.barly) private var t
    public init() {}
    public var body: some View {
        VStack(spacing: 0) {
            BimboTopBar()
            BarlyScroll {
                VStack(alignment: .leading, spacing: 12) {
                    UserBubble("Analyze our revenue this year")
                    ProcessCard("Deep Searched", time: "54s", subtitle: "Tap to read my mind")
                    SourceChips([("20 Web Source", Mock.web), ("3 Journals", Mock.journals)])
                    AIMessage(feedback: true) {
                        AIParagraph("Asia Pacific leads Q2 growth; Europe is flat. Here is the breakdown and the YTD formula:")
                        BarlyScroll(.horizontal) {
                            DataTable(columns: [
                                .text("Region", width: 150) { $0.region },
                                .text("Q1 Revenue", width: 112) { $0.q1 },
                                .text("Q2 Revenue", width: 112) { $0.q2 },
                                .text("Growth", width: 90) { $0.growth },
                            ], rows: Array(Mock.revenue.prefix(3)), rowHeight: 38, headerHeight: 38, header: .tint,
                                      headerText: BarlyTokens.Mobile.label, cellPad: 10)
                        }
                        .frame(height: 38 * 4 + 4)
                        CodeBlock(language: "python", code: Mock.pythonSnippet)
                    }
                }
                .padding(.horizontal, BarlyMetrics.pageX)
                .padding(.top, 8)
                .padding(.bottom, 210)
            }
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 14) {
                BarlyScroll(.horizontal) {
                    HStack(spacing: 10) { ForEach(Mock.followUps) { QuickChip($0) } }
                        .padding(.horizontal, BarlyMetrics.pageX)
                }
                .frame(height: 36)
                // 两层 Composer：上占位，下 工具 pill …… 📎 🎙 发送
                MobileComposer("Ask \(Mock.brand) Anything", text: $text,
                               tools: [ToolPill("Deep Think", icon: "atom"), ToolPill("Search", icon: "globe", on: true)])
                    .padding(.horizontal, BarlyMetrics.pageX)
            }
            .padding(.top, 14)
            .padding(.bottom, 20)
            .background(LinearGradient(colors: [t.bg.opacity(0), t.bg, t.bg], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.18)).ignoresSafeArea())
        }
        .screenBackground(ZStack { t.bg; TopWash() })
    }
}

// MARK: - Voice 语音模式（朗读高亮 + 人声卡 + 光环主键）

public struct VoiceScreen: View {
    @Environment(\.barly) private var t
    public init() {}
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                if t.isDark { BarlyIcon("barly.wave", size: 18, color: t.accentText) } else {
                    Image(systemName: "chevron.left").font(.system(size: 13, weight: .medium))
                }
                Text("Voice Mode").barlyText(.mobile.body.weight(500))
            }
            .foregroundStyle(t.accentText)
            .frame(maxWidth: .infinity)
            .frame(height: BarlyMetrics.topBar)
            UserBubble("Surprise me with bittersweet fable stories")
                .padding(.top, 12)
            Text("Sparrow and the Fallen Star").barlyText(.mobile.title, color: t.text)
                .padding(.top, 26)
            ReadAloudText(read: Mock.story.read, unread: Mock.story.unread)
                .padding(.top, 12)
            Text(Mock.story2).barlyText(.mobile.body.size(17).leading(26), color: t.text3)
                .padding(.top, 18)
            Spacer(minLength: 12)
            VoiceCard(name: "Clair", traits: ["Calm", "Female Voice"])
            VoiceControls().padding(.top, 22).padding(.bottom, 14)
        }
        .padding(.horizontal, BarlyMetrics.pageX)
        .screenBackground(ZStack { t.isDark ? t.bg : t.bgSubtle; GlowHorizon(.auto, heightFraction: t.isDark ? 0.3 : 0.34) })
    }
}

// MARK: - Plus 付费页（光球 + 权益列表）

public struct PlusScreen: View {
    @State private var plan = 0
    @Environment(\.barly) private var t
    public init() {}
    public var body: some View {
        let sheet = UnevenRoundedRectangle(topLeadingRadius: BarlyRadius.xl + 4, bottomLeadingRadius: BarlyRadius.xl + 4,
                                           bottomTrailingRadius: BarlyRadius.xl + 4, topTrailingRadius: BarlyRadius.xl + 4, style: .continuous)
        VStack(spacing: 0) {
            HStack { Spacer(); BarlyIcon("xmark", size: 16, color: t.text2) }
                .padding(.top, 20).padding(.horizontal, 20)
            Orb(diameter: 164, tone: .auto).padding(.top, 34)
            Text("\(Mock.brand) Plus").barlyText(.mobile.display.weight(500), color: t.accentText)
                .padding(.top, 40)
            VStack(alignment: .leading, spacing: 18) {
                PerkRow("Access Most Powerful Model")
                PerkRow("Access \(Mock.brand) Voice Mode")
                PerkRow("Early access to New Features")
            }
            .padding(.top, 22)
            Spacer(minLength: 20)
            Segmented(["Monthly", "Annually"], selection: $plan, height: 44, style: BarlyTokens.Mobile.body)
                .frame(width: 248)
            Text("Billed monthly at $20. Cancel anytime").barlyText(.mobile.caption, color: t.text2)
                .padding(.top, 18)
            BarlyButton("Upgrade to \(Mock.brand) Plus", variant: .cta, size: .xl, fullWidth: true)
                .padding(.horizontal, 16).padding(.top, 14)
            HStack(spacing: 6) {
                Text("Terms & Conditions"); Text("|").foregroundStyle(t.text4)
                Text("Privacy Policies"); Text("|").foregroundStyle(t.text4)
                Text("Restore Purchases")
            }
            .barlyText(.mobile.micro, color: t.text2)
            .padding(.top, 12).padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(sheet.fill(t.isDark ? t.fill0 : t.surface))
        .overlay(sheet.strokeBorder(t.isDark ? t.litEdgeTop : .clear, lineWidth: 1))
        .padding(.horizontal, 6).padding(.top, 10).padding(.bottom, 4)
        .screenBackground(
            LinearGradient(colors: t.isDark
                           ? [t.bg.barlyMix(t.accent, 0.22), t.bg.barlyMix(t.nameGradient[1], 0.12)]
                           : [t.accent.barlyShift(hue: -4, sat: -0.2, light: 0.45), t.accent.barlyShift(hue: 45, sat: -0.3, light: 0.47)],
                           startPoint: .topLeading, endPoint: .topTrailing)
        )
    }
}

// MARK: - Lumix 式深色首页（Services / Starters / Previous Conversations / 全宽 New Chat）

public struct LumixHomeScreen: View {
    @Environment(\.barly) private var t
    public init() {}
    private let pad: CGFloat = 16
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Good Morning!").barlyText(.mobile.headline.size(18).weight(500), color: t.text)
                    Text("Alexandria Attaya").barlyText(.mobile.micro, color: t.text3)
                }
                Spacer()
                Avatar("Alexandria Attaya", size: 43, tint: 4)
            }
            .padding(.horizontal, pad).padding(.top, 12)

            SectionHeader("Services").padding(.horizontal, pad).padding(.top, 30)
            BarlyScroll(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(Array(Mock.services.enumerated()), id: \.offset) { i, s in
                        // 服务 chip 图标各有本色：第一个用强调色，其余取多色线性图标
                        QuickChip(s, style: .filled, iconColor: !BarlyFamily.current.isBarly ? nil : i == 0 ? t.accent : t.chipIcon([0, 3, 5][(i - 1) % 3], force: true))
                    }
                }
                .padding(.horizontal, pad)
            }
            .frame(height: 42).padding(.top, 16)

            SectionHeader("Starters", action: nil).padding(.horizontal, pad).padding(.top, 34)
            BarlyScroll(.horizontal) {
                HStack(spacing: 12) {
                    StarterCard(icon: "bolt", title: "Today’s Top Prioritize", detail: "Based on last 3 days habits and activity.", primary: true)
                    StarterCard(icon: "lightbulb", title: "Mindfulness Exercise", detail: "Sharpening your focus in long-term", primary: false)
                }
                .padding(.horizontal, pad)
            }
            .frame(height: 197).padding(.top, 16)

            SectionHeader("Previous Conversations").padding(.horizontal, pad).padding(.top, 28)
            VStack(spacing: 8) {
                ForEach(Mock.conversations, id: \.0) { c in ConversationRow(c.0, time: c.1) }
            }
            .padding(.horizontal, pad).padding(.top, 16)
            Spacer(minLength: 16)
            BarlyButton("New Chat", variant: .cta, size: .xl, fullWidth: true)
                .padding(.horizontal, pad).padding(.bottom, 14)
        }
        .screenBackground(t.bg)
    }
}

// MARK: - Listening 语音聆听（Lumix：粒子圆环 + 底部发光地平线）

public struct ListeningScreen: View {
    @Environment(\.barly) private var t
    public init() {}
    public var body: some View {
        VStack(spacing: 0) {
            MobileTopBar(leading: { BarlyIcon("barly.menu2", size: 22, color: t.text3) },
                         center: { ModelPill("\(Mock.brand).AI") },
                         trailing: { Avatar("Alexandria Attaya", size: 43, tint: 4) })
                .padding(.horizontal, -4)
            Spacer(minLength: 0)
            ParticleRing(diameter: 286, band: 70, seed: 11)
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(Text("Create a mystical, fantasy-style warrior standing on a cliff during ").foregroundStyle(t.text))\(Text("sunset…").foregroundStyle(t.text3))")
                    .barlyText(.mobile.title.size(22).weight(400).leading(32))
                Text("Listening…").barlyText(.mobile.body, color: t.text2)
                    .frame(maxWidth: .infinity).padding(.top, 14)
            }
            .padding(.horizontal, BarlyMetrics.pageX)
            VoiceControls(main: 61, halo: 78, side: 42).padding(.top, 26).padding(.bottom, 18)
        }
        .screenBackground(ZStack { t.bg; GlowHorizon(.horizon, heightFraction: 0.36) })
    }
}
