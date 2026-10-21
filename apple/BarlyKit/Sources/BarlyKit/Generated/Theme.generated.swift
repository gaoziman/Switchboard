// 由 barly-design/identity.mjs 生成，不要手改
import SwiftUI

public struct BarlyPalette: Sendable {
    public let bg: Color
    public let bgSubtle: Color
    public let bgMuted: Color
    public let surface: Color
    public let surfaceRaised: Color
    public let surfaceTop: Color
    public let border: Color
    public let borderStrong: Color
    public let divider: Color
    public let text: Color
    public let text2: Color
    public let text3: Color
    public let text4: Color
    public let ink: Color
    public let inkFg: Color
    public let inkHover: Color
    public let inkGradientFrom: Color
    public let inkGradientTo: Color
    public let inkEdge: Color
    public let accent: Color
    public let accentHover: Color
    public let accentFg: Color
    public let accentSoft: Color
    public let accentSoftFg: Color
    public let accentText: Color
    public let accentGradientFrom: Color
    public let accentGradientTo: Color
    public let accentGlow: Color
    public let tooltipFrom: Color
    public let tooltipTo: Color
    public let overlay: Color
    public let success: Color
    public let successSoft: Color
    public let successFg: Color
    public let danger: Color
    public let dangerSoft: Color
    public let dangerFg: Color
    public let warning: Color
    public let warningSoft: Color
    public let warningFg: Color
    public let info: Color
    public let infoSoft: Color
    public let infoFg: Color
    public let primary: Color
    public let primaryFg: Color
    public let headline2: Color
    public let dataDeep: Color
    public let dataBase: Color
    public let dataLight: Color
    public let dataFaint: Color
    public let dataNeutral: Color
    public let dataPos: Color
    public let dataNeg: Color
    public let nameGradientFrom: Color
    public let nameGradientTo: Color
    public let chipIconDocs: Color
    public let chipIconSummarize: Color
    public let chipIconNews: Color
    public let chipIconVoice: Color
    public let chipIconIdea: Color
    public let chipIconImage: Color
    public let codeBg: Color
    public let codeHeader: Color
    public let codeText: Color
    public let codeComment: Color
    public let codeKeyword: Color
    public let codeString: Color
    public let codeNumber: Color
    public let orbHighlight: Color
    public let orbMid: Color
    public let orbShadow: Color
    public let orbGlow: Color
    public let chartLine: Color
    public let chartAreaFrom: Color
    public let chartAreaTo: Color
    public let chartGrid: Color
    public let chartCompare: Color
    public let canvas: Color
    public let sidebarBg: Color
    public let slot: Color
    public let navSelectedFrom: Color
    public let navSelectedTo: Color
    public let navSelectedFg: Color
    public let bannerBg: Color
    public let bannerBorder: Color
    public let bannerFg: Color
    public let tile1: Color
    public let tile2: Color
    public let tile3: Color
    public let tile4: Color
    public let tile5: Color
    public let tile6: Color
    public let chartEmpty: Color
    public let cta: Color
    public let ctaFg: Color
    public let ctaHover: Color
    public let selectedBg: Color
    public let selectedFg: Color
    public let selectedBorder: Color
    public let selectedMark: Color
    public let paper: Color
    public let pastel1: Color
    public let pastel2: Color
    public let pastel3: Color
}

public enum BarlyTokens {
    public static let name = "Switchboard"
    public static let prefersDark = true
    /// 界面语言（identity.lang）：zh 时大标题默认 400
    public static let lang = "zh"
    public static let light = BarlyPalette(
        bg: Color(hex: 0xFFFFFF),
        bgSubtle: Color(hex: 0xFAFAFA),
        bgMuted: Color(hex: 0xF3F3F3),
        surface: Color(hex: 0xFFFFFF),
        surfaceRaised: Color(hex: 0xFFFFFF),
        surfaceTop: Color(hex: 0xF3F3F3),
        border: Color(hex: 0xE6E6E6),
        borderStrong: Color(hex: 0xD6D6D6),
        divider: Color(hex: 0xE8E8E8),
        text: Color(hex: 0x141414),
        text2: Color(hex: 0x5B5B5B),
        text3: Color(hex: 0x9E9E9E),
        text4: Color(hex: 0xCECECE),
        ink: Color(hex: 0x1D100C),
        inkFg: Color(hex: 0xFFFFFF),
        inkHover: Color(hex: 0x2C1E19),
        inkGradientFrom: Color(hex: 0x2F201C),
        inkGradientTo: Color(hex: 0x190C08),
        inkEdge: Color(.sRGB, red: 1.0000, green: 1.0000, blue: 1.0000, opacity: 0.14),
        accent: Color(hex: 0xDB5730),
        accentHover: Color(hex: 0xCD4A22),
        accentFg: Color(hex: 0xFFFFFF),
        accentSoft: Color(hex: 0xFFF0EB),
        accentSoftFg: Color(hex: 0xAF3100),
        accentText: Color(hex: 0xC13F13),
        accentGradientFrom: Color(hex: 0xED6741),
        accentGradientTo: Color(hex: 0xD04D25),
        accentGlow: Color(.sRGB, red: 0.8588, green: 0.3412, blue: 0.1882, opacity: 0.3),
        tooltipFrom: Color(hex: 0x2C0902),
        tooltipTo: Color(hex: 0x542112),
        overlay: Color(.sRGB, red: 0.0353, green: 0.0353, blue: 0.0431, opacity: 0.35),
        success: Color(hex: 0x389970),
        successSoft: Color(hex: 0xE2FAED),
        successFg: Color(hex: 0x315B45),
        danger: Color(hex: 0xC2414B),
        dangerSoft: Color(hex: 0xFEECED),
        dangerFg: Color(hex: 0x692F36),
        warning: Color(hex: 0xD99A1E),
        warningSoft: Color(hex: 0xFFF8E5),
        warningFg: Color(hex: 0x8A5A0B),
        info: Color(hex: 0x3B5BDE),
        infoSoft: Color(hex: 0xE3EBFE),
        infoFg: Color(hex: 0x2A3E74),
        primary: Color(hex: 0x1D100C),
        primaryFg: Color(hex: 0xFFFFFF),
        headline2: Color(hex: 0x989898),
        dataDeep: Color(hex: 0xAF3100),
        dataBase: Color(hex: 0xDB5730),
        dataLight: Color(hex: 0xFF8F6F),
        dataFaint: Color(hex: 0xFFC0AD),
        dataNeutral: Color(hex: 0xCECECE),
        dataPos: Color(hex: 0x2E63D6),
        dataNeg: Color(hex: 0xC9651F),
        nameGradientFrom: Color(hex: 0xE15C36),
        nameGradientTo: Color(hex: 0x9D6300),
        chipIconDocs: Color(hex: 0x405AEF),
        chipIconSummarize: Color(hex: 0xEF8B5A),
        chipIconNews: Color(hex: 0x6ABFF6),
        chipIconVoice: Color(hex: 0x4BA778),
        chipIconIdea: Color(hex: 0xECBB42),
        chipIconImage: Color(hex: 0x785CCD),
        codeBg: Color(hex: 0xF5F5F5),
        codeHeader: Color(hex: 0xEDEDED),
        codeText: Color(hex: 0x16171A),
        codeComment: Color(hex: 0x75767B),
        codeKeyword: Color(hex: 0x576FB7),
        codeString: Color(hex: 0x4FA87A),
        codeNumber: Color(hex: 0x5F75B1),
        orbHighlight: Color(hex: 0xFFE1CD),
        orbMid: Color(hex: 0xFF8360),
        orbShadow: Color(hex: 0xB22927),
        orbGlow: Color(.sRGB, red: 0.8588, green: 0.3412, blue: 0.1882, opacity: 0.28),
        chartLine: Color(hex: 0x723C2D),
        chartAreaFrom: Color(.sRGB, red: 0.8588, green: 0.3412, blue: 0.1882, opacity: 0.08),
        chartAreaTo: Color(.sRGB, red: 0.8588, green: 0.3412, blue: 0.1882, opacity: 0),
        chartGrid: Color(hex: 0xEFEFEF),
        chartCompare: Color(hex: 0xE5E5E5),
        canvas: Color(hex: 0xFFFFFF),
        sidebarBg: Color(hex: 0xFFFFFF),
        slot: Color(hex: 0xFAFAFA),
        navSelectedFrom: Color(hex: 0xFAFAFA),
        navSelectedTo: Color(hex: 0xFAFAFA),
        navSelectedFg: Color(hex: 0x141414),
        bannerBg: Color(hex: 0xFAFAFA),
        bannerBorder: Color(hex: 0xE6E6E6),
        bannerFg: Color(hex: 0x141414),
        tile1: Color(hex: 0xE65000),
        tile2: Color(hex: 0x7673FD),
        tile3: Color(hex: 0x008AF6),
        tile4: Color(hex: 0xE9454F),
        tile5: Color(hex: 0x00A36A),
        tile6: Color(hex: 0xEFA810),
        chartEmpty: Color(hex: 0xF3F3F3),
        cta: Color(hex: 0xDB5730),
        ctaFg: Color(hex: 0xFFFFFF),
        ctaHover: Color(hex: 0xCD4A22),
        selectedBg: Color(hex: 0xF3F3F3),
        selectedFg: Color(hex: 0x141414),
        selectedBorder: Color(hex: 0xD6D6D6),
        selectedMark: Color(hex: 0xDB5730),
        paper: Color(hex: 0xFAFAFA),
        pastel1: Color(hex: 0xFFD2C6),
        pastel2: Color(hex: 0xC5E9C7),
        pastel3: Color(hex: 0xCAE0FF)
    )
    public static let dark = BarlyPalette(
        bg: Color(hex: 0x0B0C0F),
        bgSubtle: Color(hex: 0x121416),
        bgMuted: Color(hex: 0x18191C),
        surface: Color(hex: 0x15171A),
        surfaceRaised: Color(hex: 0x1F2023),
        surfaceTop: Color(hex: 0x282A2D),
        border: Color(hex: 0x232528),
        borderStrong: Color(hex: 0x323437),
        divider: Color(hex: 0x1C1E21),
        text: Color(hex: 0xE8E8EA),
        text2: Color(hex: 0xA9ABAF),
        text3: Color(hex: 0x727578),
        text4: Color(hex: 0x404246),
        ink: Color(hex: 0xF2F2F3),
        inkFg: Color(hex: 0x0B0C0E),
        inkHover: Color(hex: 0xE4E4E7),
        inkGradientFrom: Color(hex: 0xF2F2F3),
        inkGradientTo: Color(hex: 0xF2F2F3),
        inkEdge: Color(.sRGB, red: 1.0000, green: 1.0000, blue: 1.0000, opacity: 0.4),
        accent: Color(hex: 0xDB5730),
        accentHover: Color(hex: 0xE9643D),
        accentFg: Color(hex: 0xFFFFFF),
        accentSoft: Color(hex: 0x3A1C14),
        accentSoftFg: Color(hex: 0xFFAC95),
        accentText: Color(hex: 0xF77B58),
        accentGradientFrom: Color(hex: 0xE25D37),
        accentGradientTo: Color(hex: 0xBF3D10),
        accentGlow: Color(.sRGB, red: 0.8588, green: 0.3412, blue: 0.1882, opacity: 0.4),
        tooltipFrom: Color(hex: 0xFFFFFF),
        tooltipTo: Color(hex: 0xF4F4F5),
        overlay: Color(.sRGB, red: 0.0000, green: 0.0000, blue: 0.0000, opacity: 0.6),
        success: Color(hex: 0x4CC38A),
        successSoft: Color(hex: 0x24503A),
        successFg: Color(hex: 0x8EE0B4),
        danger: Color(hex: 0xF0717B),
        dangerSoft: Color(hex: 0x552C31),
        dangerFg: Color(hex: 0xF6A9B0),
        warning: Color(hex: 0xE9A23B),
        warningSoft: Color(hex: 0x4E4428),
        warningFg: Color(hex: 0xF2D08E),
        info: Color(hex: 0x7C95F2),
        infoSoft: Color(hex: 0x2B3260),
        infoFg: Color(hex: 0xB9C6FA),
        primary: Color(hex: 0xDB5730),
        primaryFg: Color(hex: 0xFFFFFF),
        headline2: Color(hex: 0x7C7E86),
        dataDeep: Color(hex: 0xB83603),
        dataBase: Color(hex: 0xDB5730),
        dataLight: Color(hex: 0xFF8360),
        dataFaint: Color(hex: 0xFFC0AD),
        dataNeutral: Color(hex: 0x444444),
        dataPos: Color(hex: 0x5B8DEF),
        dataNeg: Color(hex: 0xE8833A),
        nameGradientFrom: Color(hex: 0xFF815D),
        nameGradientTo: Color(hex: 0xD98B00),
        chipIconDocs: Color(hex: 0xA9A9A9),
        chipIconSummarize: Color(hex: 0xA9A9A9),
        chipIconNews: Color(hex: 0xA9A9A9),
        chipIconVoice: Color(hex: 0xA9A9A9),
        chipIconIdea: Color(hex: 0xA9A9A9),
        chipIconImage: Color(hex: 0xA9A9A9),
        codeBg: Color(hex: 0x191919),
        codeHeader: Color(hex: 0x292929),
        codeText: Color(hex: 0xE4E4E4),
        codeComment: Color(hex: 0x7A7A7A),
        codeKeyword: Color(hex: 0xEF9277),
        codeString: Color(hex: 0x8FD3A8),
        codeNumber: Color(hex: 0x9DB2F2),
        orbHighlight: Color(hex: 0xFFE1CD),
        orbMid: Color(hex: 0xFF8360),
        orbShadow: Color(hex: 0xB22927),
        orbGlow: Color(.sRGB, red: 0.8588, green: 0.3412, blue: 0.1882, opacity: 0.45),
        chartLine: Color(hex: 0xF98C6C),
        chartAreaFrom: Color(.sRGB, red: 0.8588, green: 0.3412, blue: 0.1882, opacity: 0.22),
        chartAreaTo: Color(.sRGB, red: 0.8588, green: 0.3412, blue: 0.1882, opacity: 0),
        chartGrid: Color(hex: 0x262626),
        chartCompare: Color(hex: 0x3B3B3B),
        canvas: Color(hex: 0x131313),
        sidebarBg: Color(hex: 0x131313),
        slot: Color(hex: 0x1A1A1A),
        navSelectedFrom: Color(hex: 0x292929),
        navSelectedTo: Color(hex: 0x292929),
        navSelectedFg: Color(hex: 0xEFEFEF),
        bannerBg: Color(hex: 0x1A1A1A),
        bannerBorder: Color(hex: 0x262626),
        bannerFg: Color(hex: 0xEFEFEF),
        tile1: Color(hex: 0xD4896E),
        tile2: Color(hex: 0x9297DC),
        tile3: Color(hex: 0x6FA2DB),
        tile4: Color(hex: 0xD68582),
        tile5: Color(hex: 0x62B289),
        tile6: Color(hex: 0xC19652),
        chartEmpty: Color(hex: 0x323232),
        cta: Color(hex: 0xDB5730),
        ctaFg: Color(hex: 0xFFFFFF),
        ctaHover: Color(hex: 0xE9643D),
        selectedBg: Color(hex: 0x18191C),
        selectedFg: Color(hex: 0xE8E8EA),
        selectedBorder: Color(hex: 0x323437),
        selectedMark: Color(hex: 0xDB5730),
        paper: Color(hex: 0x121416),
        pastel1: Color(hex: 0x492920),
        pastel2: Color(hex: 0x213A23),
        pastel3: Color(hex: 0x22344C)
    )
    public enum Font {
        public static let display = "Inter Tight"
        public static let ui = "Inter"
        public static let mono = "Geist Mono"
        public static let files: [String] = ["InterTight-Variable.ttf","Inter-Variable.ttf","GeistMono-Variable.ttf"]
    }
    public enum Radius {
        public static let xs: CGFloat = 2
        public static let sm: CGFloat = 3
        public static let md: CGFloat = 4
        public static let lg: CGFloat = 4
        public static let xl: CGFloat = 6
        public static let window: CGFloat = 8
        public static let pill: CGFloat = 999
        public static let cta: CGFloat = 4
    }
    public enum Product {
        public static let pageTitle = BarlyTextStyle(size: 20, lineHeight: 1.3, weight: 500, tracking: -0.01, upper: false, mono: false)
        public static let sectionTitle = BarlyTextStyle(size: 16, lineHeight: 1.4, weight: 500, tracking: -0.005, upper: false, mono: false)
        public static let cardTitle = BarlyTextStyle(size: 14, lineHeight: 1.4, weight: 500, tracking: 0, upper: false, mono: false)
        public static let body = BarlyTextStyle(size: 14, lineHeight: 1.5, weight: 400, tracking: 0, upper: false, mono: false)
        public static let small = BarlyTextStyle(size: 13, lineHeight: 1.45, weight: 400, tracking: 0, upper: false, mono: false)
        public static let caption = BarlyTextStyle(size: 12, lineHeight: 1.4, weight: 400, tracking: 0, upper: false, mono: false)
        public static let kpi = BarlyTextStyle(size: 20, lineHeight: 1.2, weight: 500, tracking: -0.01, upper: false, mono: false)
        public static let heroNumber = BarlyTextStyle(size: 28, lineHeight: 1.15, weight: 500, tracking: -0.02, upper: false, mono: false)
        public static let label = BarlyTextStyle(size: 11, lineHeight: 1.2, weight: 500, tracking: 0.08, upper: true, mono: true)
    }
    public enum Mobile {
        public static let display = BarlyTextStyle(size: 24, lineHeight: 1.35, weight: 400, tracking: -0.01, upper: false, mono: false)
        public static let title = BarlyTextStyle(size: 20, lineHeight: 1.3, weight: 500, tracking: -0.01, upper: false, mono: false)
        public static let headline = BarlyTextStyle(size: 16, lineHeight: 1.4, weight: 500, tracking: 0, upper: false, mono: false)
        public static let body = BarlyTextStyle(size: 15, lineHeight: 1.42, weight: 400, tracking: 0, upper: false, mono: false)
        public static let label = BarlyTextStyle(size: 14, lineHeight: 1.3, weight: 400, tracking: 0, upper: false, mono: false)
        public static let caption = BarlyTextStyle(size: 13, lineHeight: 1.35, weight: 400, tracking: 0, upper: false, mono: false)
        public static let micro = BarlyTextStyle(size: 12, lineHeight: 1.3, weight: 400, tracking: 0, upper: false, mono: false)
        public static let sectionLabel = BarlyTextStyle(size: 11, lineHeight: 1.2, weight: 500, tracking: 0.08, upper: true, mono: true)
    }
    public enum Marketing {
        public static let hero = BarlyTextStyle(size: 56, lineHeight: 1.05, weight: 500, tracking: -0.03, upper: false, mono: false)
        public static let section = BarlyTextStyle(size: 31, lineHeight: 1.15, weight: 500, tracking: -0.03, upper: false, mono: false)
        public static let cardTitle = BarlyTextStyle(size: 22, lineHeight: 1.3, weight: 500, tracking: -0.01, upper: false, mono: false)
        public static let lead = BarlyTextStyle(size: 18, lineHeight: 1.55, weight: 400, tracking: 0, upper: false, mono: false)
        public static let body = BarlyTextStyle(size: 16, lineHeight: 1.6, weight: 400, tracking: 0, upper: false, mono: false)
        public static let small = BarlyTextStyle(size: 14, lineHeight: 1.5, weight: 400, tracking: 0, upper: false, mono: false)
        public static let label = BarlyTextStyle(size: 12, lineHeight: 1.2, weight: 500, tracking: 0.1, upper: true, mono: true)
    }
    public static let ctaFx = "flat"
    public static let primaryAction = "ink"
    public static let signature: [String] = ["mono-labels"]
    public static let family = "console"
    /// dna v2 身份轴（identity.mjs --intensity / --canvas / --icons / --chart / --ai-entry / --greeting / --mac-form）
    public enum Style {
        public static let intensity = "restrained"
        public static let canvas = "flat"
        public static let icons = "mono"
        public static let chart = "bars"
        public static let aiEntry = "gradient"
        public static let greeting = "sans"
        public static let macForm = "window"
        public static let serifFont = ""
        public static var isFull: Bool { intensity == "full" }
        public static var multiIcons: Bool { icons == "multi" }
    }
    public enum Layout {
        public static let shell = "sidebar"
        public static let inspector = false
        public static let mobileHome = "hub"
    }
}
