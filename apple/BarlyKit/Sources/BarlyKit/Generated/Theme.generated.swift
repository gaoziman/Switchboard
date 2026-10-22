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
        bgSubtle: Color(hex: 0xF7FBFA),
        bgMuted: Color(hex: 0xF1F4F4),
        surface: Color(hex: 0xFFFFFF),
        surfaceRaised: Color(hex: 0xFFFFFF),
        surfaceTop: Color(hex: 0xF1F4F4),
        border: Color(hex: 0xE3E7E6),
        borderStrong: Color(hex: 0xD3D7D6),
        divider: Color(hex: 0xE5E9E8),
        text: Color(hex: 0x090E0E),
        text2: Color(hex: 0x585B5B),
        text3: Color(hex: 0x9C9F9F),
        text4: Color(hex: 0xCBCECE),
        ink: Color(hex: 0x0B1615),
        inkFg: Color(hex: 0xFFFFFF),
        inkHover: Color(hex: 0x192423),
        inkGradientFrom: Color(hex: 0x1B2725),
        inkGradientTo: Color(hex: 0x071210),
        inkEdge: Color(.sRGB, red: 1.0000, green: 1.0000, blue: 1.0000, opacity: 0.14),
        accent: Color(hex: 0x19B3A6),
        accentHover: Color(hex: 0x00A699),
        accentFg: Color(hex: 0x141414),
        accentSoft: Color(hex: 0xDAFCF7),
        accentSoftFg: Color(hex: 0x008B80),
        accentText: Color(hex: 0x008379),
        accentGradientFrom: Color(hex: 0x36C3B6),
        accentGradientTo: Color(hex: 0x00A99D),
        accentGlow: Color(.sRGB, red: 0.0980, green: 0.7020, blue: 0.6510, opacity: 0.3),
        tooltipFrom: Color(hex: 0x001B18),
        tooltipTo: Color(hex: 0x003C37),
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
        primary: Color(hex: 0x0B1615),
        primaryFg: Color(hex: 0xFFFFFF),
        headline2: Color(hex: 0x969998),
        dataDeep: Color(hex: 0x008B80),
        dataBase: Color(hex: 0x19B3A6),
        dataLight: Color(hex: 0x6CDED1),
        dataFaint: Color(hex: 0xAADDD6),
        dataNeutral: Color(hex: 0xCBCECE),
        dataPos: Color(hex: 0x2E63D6),
        dataNeg: Color(hex: 0xC9651F),
        nameGradientFrom: Color(hex: 0x00A296),
        nameGradientTo: Color(hex: 0x006FD7),
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
        orbHighlight: Color(hex: 0xC2F2F8),
        orbMid: Color(hex: 0x3AC6B8),
        orbShadow: Color(hex: 0x008C75),
        orbGlow: Color(.sRGB, red: 0.0980, green: 0.7020, blue: 0.6510, opacity: 0.28),
        chartLine: Color(hex: 0x005A53),
        chartAreaFrom: Color(.sRGB, red: 0.0980, green: 0.7020, blue: 0.6510, opacity: 0.08),
        chartAreaTo: Color(.sRGB, red: 0.0980, green: 0.7020, blue: 0.6510, opacity: 0),
        chartGrid: Color(hex: 0xEFEFEF),
        chartCompare: Color(hex: 0xE5E5E5),
        canvas: Color(hex: 0xFFFFFF),
        sidebarBg: Color(hex: 0xFFFFFF),
        slot: Color(hex: 0xF7FBFA),
        navSelectedFrom: Color(hex: 0xF7FBFA),
        navSelectedTo: Color(hex: 0xF7FBFA),
        navSelectedFg: Color(hex: 0x090E0E),
        bannerBg: Color(hex: 0xF7FBFA),
        bannerBorder: Color(hex: 0xE3E7E6),
        bannerFg: Color(hex: 0x090E0E),
        tile1: Color(hex: 0xE65000),
        tile2: Color(hex: 0x7673FD),
        tile3: Color(hex: 0x008AF6),
        tile4: Color(hex: 0xE9454F),
        tile5: Color(hex: 0x00A36A),
        tile6: Color(hex: 0xEFA810),
        chartEmpty: Color(hex: 0xF1F4F4),
        cta: Color(hex: 0x0B1615),
        ctaFg: Color(hex: 0xFFFFFF),
        ctaHover: Color(hex: 0x192423),
        selectedBg: Color(hex: 0xF1F4F4),
        selectedFg: Color(hex: 0x090E0E),
        selectedBorder: Color(hex: 0xD3D7D6),
        selectedMark: Color(hex: 0x090E0E),
        paper: Color(hex: 0xF7FBFA),
        pastel1: Color(hex: 0xB1ECE3),
        pastel2: Color(hex: 0xE0D7FF),
        pastel3: Color(hex: 0xFFD3C0)
    )
    public static let dark = BarlyPalette(
        bg: Color(hex: 0x121212),
        bgSubtle: Color(hex: 0x1A1A1A),
        bgMuted: Color(hex: 0x202020),
        surface: Color(hex: 0x1D1D1D),
        surfaceRaised: Color(hex: 0x272727),
        surfaceTop: Color(hex: 0x313131),
        border: Color(hex: 0x2C2C2C),
        borderStrong: Color(hex: 0x3B3B3B),
        divider: Color(hex: 0x242424),
        text: Color(hex: 0xEFEFEF),
        text2: Color(hex: 0xABABAB),
        text3: Color(hex: 0x747474),
        text4: Color(hex: 0x424242),
        ink: Color(hex: 0xFFFFFF),
        inkFg: Color(hex: 0x141414),
        inkHover: Color(hex: 0xE4E4E7),
        inkGradientFrom: Color(hex: 0xFFFFFF),
        inkGradientTo: Color(hex: 0xFFFFFF),
        inkEdge: Color(.sRGB, red: 1.0000, green: 1.0000, blue: 1.0000, opacity: 0.4),
        accent: Color(hex: 0x19B3A6),
        accentHover: Color(hex: 0x31C0B3),
        accentFg: Color(hex: 0x141414),
        accentSoft: Color(hex: 0x012622),
        accentSoftFg: Color(hex: 0x57DDCF),
        accentText: Color(hex: 0x2BBCAF),
        accentGradientFrom: Color(hex: 0x27B9AC),
        accentGradientTo: Color(hex: 0x00988D),
        accentGlow: Color(.sRGB, red: 0.0980, green: 0.7020, blue: 0.6510, opacity: 0.4),
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
        primary: Color(hex: 0xFFFFFF),
        primaryFg: Color(hex: 0x141414),
        headline2: Color(hex: 0x808080),
        dataDeep: Color(hex: 0x008B80),
        dataBase: Color(hex: 0x19B3A6),
        dataLight: Color(hex: 0x6CDED1),
        dataFaint: Color(hex: 0xAADDD6),
        dataNeutral: Color(hex: 0x374644),
        dataPos: Color(hex: 0x5B8DEF),
        dataNeg: Color(hex: 0xE8833A),
        nameGradientFrom: Color(hex: 0x00C5B6),
        nameGradientTo: Color(hex: 0x53A0FF),
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
        codeKeyword: Color(hex: 0x35C6B9),
        codeString: Color(hex: 0x8FD3A8),
        codeNumber: Color(hex: 0x9DB2F2),
        orbHighlight: Color(hex: 0xC2F2F8),
        orbMid: Color(hex: 0x3AC6B8),
        orbShadow: Color(hex: 0x008C75),
        orbGlow: Color(.sRGB, red: 0.0980, green: 0.7020, blue: 0.6510, opacity: 0.45),
        chartLine: Color(hex: 0x3AC6B8),
        chartAreaFrom: Color(.sRGB, red: 0.0980, green: 0.7020, blue: 0.6510, opacity: 0.22),
        chartAreaTo: Color(.sRGB, red: 0.0980, green: 0.7020, blue: 0.6510, opacity: 0),
        chartGrid: Color(hex: 0x262626),
        chartCompare: Color(hex: 0x3B3B3B),
        canvas: Color(hex: 0x121212),
        sidebarBg: Color(hex: 0x121212),
        slot: Color(hex: 0x1A1A1A),
        navSelectedFrom: Color(hex: 0x272727),
        navSelectedTo: Color(hex: 0x272727),
        navSelectedFg: Color(hex: 0xEFEFEF),
        bannerBg: Color(hex: 0x1A1A1A),
        bannerBorder: Color(hex: 0x2C2C2C),
        bannerFg: Color(hex: 0xEFEFEF),
        tile1: Color(hex: 0xD4896E),
        tile2: Color(hex: 0x9297DC),
        tile3: Color(hex: 0x6FA2DB),
        tile4: Color(hex: 0xD68582),
        tile5: Color(hex: 0x62B289),
        tile6: Color(hex: 0xC19652),
        chartEmpty: Color(hex: 0x202020),
        cta: Color(hex: 0xFFFFFF),
        ctaFg: Color(hex: 0x141414),
        ctaHover: Color(hex: 0xE4E4E7),
        selectedBg: Color(hex: 0x202020),
        selectedFg: Color(hex: 0xEFEFEF),
        selectedBorder: Color(hex: 0x3B3B3B),
        selectedMark: Color(hex: 0xEFEFEF),
        paper: Color(hex: 0x1A1A1A),
        pastel1: Color(hex: 0x0B3B36),
        pastel2: Color(hex: 0x352D4A),
        pastel3: Color(hex: 0x482A1D)
    )
    public enum Font {
        public static let display = "Geist"
        public static let ui = "Inter"
        public static let mono = "Geist Mono"
        public static let files: [String] = ["Geist-Variable.ttf","Inter-Variable.ttf","GeistMono-Variable.ttf"]
    }
    public enum Radius {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 6
        public static let md: CGFloat = 8
        public static let lg: CGFloat = 10
        public static let xl: CGFloat = 12
        public static let window: CGFloat = 20
        public static let pill: CGFloat = 999
        public static let cta: CGFloat = 8
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
        public static let hero = BarlyTextStyle(size: 64, lineHeight: 1.12, weight: 500, tracking: -0.035, upper: false, mono: false)
        public static let section = BarlyTextStyle(size: 48, lineHeight: 1.15, weight: 500, tracking: -0.03, upper: false, mono: false)
        public static let cardTitle = BarlyTextStyle(size: 22, lineHeight: 1.3, weight: 500, tracking: -0.01, upper: false, mono: false)
        public static let lead = BarlyTextStyle(size: 18, lineHeight: 1.55, weight: 400, tracking: 0, upper: false, mono: false)
        public static let body = BarlyTextStyle(size: 16, lineHeight: 1.6, weight: 400, tracking: 0, upper: false, mono: false)
        public static let small = BarlyTextStyle(size: 14, lineHeight: 1.5, weight: 400, tracking: 0, upper: false, mono: false)
        public static let label = BarlyTextStyle(size: 12, lineHeight: 1.2, weight: 500, tracking: 0.08, upper: true, mono: true)
    }
    public static let ctaFx = "flat"
    public static let primaryAction = "ink"
    public static let signature: [String] = []
    public static let family = "barly"
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
        // 身份 v3（空串 = auto，按风格族默认）：标题声音、用量、数字、纵深、眉标、页脚、画面层、底色调子
        public static let headline = "single"
        public static let dose = "data"
        public static let numerals = "tabular"
        public static let depth = "soft"
        public static let eyebrow = ""
        public static let footer = ""
        public static let art = "generative-data"
        public static let ground = "graphite"
        public static let chrome = ""
    }
    public enum Layout {
        public static let shell = "sidebar"
        public static let inspector = false
        public static let mobileHome = "hub"
        public static let hero = "tool-hero"
        public static let workspace = "grid"
    }
}
