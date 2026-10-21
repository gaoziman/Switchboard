import SwiftUI
import BarlyKit

/// 真实感 mock 数据（不用 lorem、不用灰块）
enum Mock {
    static var brand: String { BarlyTokens.name }

    static let homeChips: [[QuickChipItem]] = [
        [QuickChipItem("Analyse docs", icon: "doc.badge.plus"), QuickChipItem("Summarize", icon: "arrow.down.right.and.arrow.up.left"),
         QuickChipItem("Latest news", icon: "newspaper")],
        [QuickChipItem("Voice mode", icon: "barly.wave"), QuickChipItem("Brainstorm idea", icon: "lightbulb"),
         QuickChipItem("Create images", icon: "photo.badge.plus")],
    ]
    static let followUps: [QuickChipItem] = [QuickChipItem("Compare"), QuickChipItem("Identify Key Streams"), QuickChipItem("Forecast")]

    static let web: [SourceIcon] = [SourceIcon(Color(hex: 0x5BB6FD), glyph: "cloud.fill"),
                                    SourceIcon(Color(hex: 0xF3B524), glyph: "a.circle", fg: .black),
                                    SourceIcon(Color(hex: 0x6798F6), glyph: "square.grid.2x2.fill")]
    static let journals: [SourceIcon] = [SourceIcon(Color(hex: 0xEFEAFF), glyph: "doc.text", fg: Color(hex: 0x775FC7))]

    struct Revenue: Identifiable { let id: Int; let region: String; let q1: String; let q2: String; let growth: String }
    static let revenue: [Revenue] = [
        Revenue(id: 0, region: "North America", q1: "1,250.5", q2: "1,402.8", growth: "+12.2%"),
        Revenue(id: 1, region: "Europe", q1: "980.2", q2: "1,021.6", growth: "+4.2%"),
        Revenue(id: 2, region: "Asia Pacific", q1: "1,450.8", q2: "1,688.1", growth: "+16.4%"),
        Revenue(id: 3, region: "South America", q1: "600.3", q2: "574.9", growth: "−4.2%"),
    ]

    static let pythonSnippet = """
    # Year-to-date revenue by region
    ytd = sum(q1 + q2 for q1, q2 in rows)
    print(f"YTD total: {ytd:,.1f}")
    """

    static let story = (read: "In a quiet forest, a sparrow named Elara found a glowing fragment of a fallen star, ",
                        unread: "nestled in the roots of an ancient oak. Its light pulsed faintly, like a heartbeat, and it whispered to her in a voice soft as moonlight. \"I am a piece of the heavens,\" it said.")
    static let story2 = "Elara, whose wings were too small to soar above the treetops, dreamed of touching the sky. She carried the star fragment in her beak."

    // Lumix 首页
    static let services: [QuickChipItem] = [QuickChipItem("AI Chat", icon: "wand.and.stars"), QuickChipItem("BG Remover", icon: "photo"),
                                           QuickChipItem("PDF Scanner", icon: "doc"), QuickChipItem("Translate", icon: "character.bubble")]
    static let conversations: [(String, String)] = [("Best way to stay focused?", "9s ago"),
                                                    ("Why is my phone battery draining fast at night", "3h ago"),
                                                    ("Measure monitor dimensions in cm for a desk setup", "7h ago")]

    // Dashboard
    static let revenueSeries: [ChartPoint] = {
        let months = ["Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec", "Jan", "Feb", "Mar"]
        let raw: [Double] = [18, 21, 17.5, 25, 19, 22, 31, 16, 23, 19, 27, 21, 18, 24, 29, 17, 33, 20, 26, 34, 19, 31, 22, 18.5,
                             36, 24, 21, 35, 27, 19.4, 30, 25, 37, 31, 38, 34, 39]
        return raw.enumerated().map { i, v in ChartPoint(i, months[min(months.count - 1, i / 3)], v * 1000) }
    }()
    static let retention: [BarGroup] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul"].enumerated().map { i, m in
        let base: [[Double]] = [[78, 52, 22], [92, 46, 30], [70, 44, 18], [80, 50, 28], [90, 41, 24], [74, 56, 20], [96, 60, 34]]
        return BarGroup(i, m, base[i])
    }

    struct Deal: Identifiable {
        let id: Int; let company: String; let glyph: String; let color: Color; let contact: String
        let stage: String; let tone: BarlyTone; let value: String; let owner: String; let updated: String
    }
    static let deals: [Deal] = [
        Deal(id: 0, company: "Northwind Labs", glyph: "wind", color: Color(hex: 0x2B6CB0), contact: "Sofia Marin", stage: "Won", tone: .success, value: "$48,200", owner: "Janson W.", updated: "2 min ago"),
        Deal(id: 1, company: "Helio Freight", glyph: "shippingbox.fill", color: Color(hex: 0xD97706), contact: "Rafael Ortiz", stage: "Discovery", tone: .info, value: "$12,750", owner: "Mia Chen", updated: "1 h ago"),
        Deal(id: 2, company: "Quill & Co.", glyph: "pencil.tip", color: Color(hex: 0x111827), contact: "Hana Sato", stage: "Demo", tone: .warning, value: "$31,400", owner: "Janson W.", updated: "3 h ago"),
        Deal(id: 3, company: "Arcadia Health", glyph: "cross.case.fill", color: Color(hex: 0x0F9D76), contact: "Liam Brooks", stage: "Lost", tone: .danger, value: "$8,900", owner: "Ava Patel", updated: "Yesterday"),
        Deal(id: 4, company: "Moonrise Studio", glyph: "moon.stars.fill", color: Color(hex: 0x6D28D9), contact: "Noor Haddad", stage: "Leads", tone: .neutral, value: "$22,000", owner: "Mia Chen", updated: "Oct 14"),
    ]
}
