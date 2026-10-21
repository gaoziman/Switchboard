import SwiftUI

// MARK: - @Environment(\.barly)

public extension EnvironmentValues {
    /// 强制用某套色板（nil = 跟随 colorScheme）
    @Entry var barlyPaletteOverride: BarlyPalette? = nil
    /// 快照模式：TextField / ScrollView 换成静态版本，ImageRenderer 才能出图
    @Entry var barlySnapshot: Bool = false
    /// macOS 自绘外壳顶部给红绿灯留的高度（App 里 28，快照里 0）
    @Entry var barlyTitlebarInset: CGFloat = 0
    /// Mac 工具形态用系统字体（SF Pro）显示界面字：菜单栏弹窗 / 浮动面板 / 货架 / 设置窗口的根视图设 true
    @Entry var barlySystemUIFont: Bool = false

    /// 当前色板：按 colorScheme 取 BarlyTokens.light / .dark
    var barly: BarlyPalette {
        barlyPaletteOverride ?? (colorScheme == .dark ? BarlyTokens.dark : BarlyTokens.light)
    }
}

public extension View {
    /// App 根视图用：注册字体 + 按身份的 prefersDark 给默认明暗（用户/系统切换仍然生效）
    func barlyRoot(forceScheme: ColorScheme? = nil) -> some View {
        BarlyFonts.register()
        return self.preferredColorScheme(forceScheme ?? (BarlyTokens.prefersDark ? .dark : nil))
    }
}

// MARK: - 派生令牌（identity.mjs 没给的，按 DNA 在本地推出来；见 references/apple.md「建议补的令牌」）

public extension BarlyPalette {
    var isDark: Bool { bg.barlyLuminance < 0.2 }

    /// L1 容器：槽、chip、输入框（深色 = 生成的 surface，纯黑派 #191919）
    var fill1: Color { isDark ? surface : bgMuted }
    /// L2 嵌套控件：输入框里的小键、Copy 按钮（深色 = surfaceRaised #292929）
    var fill2: Color { isDark ? surfaceRaised : bgMuted.barlyMix(.black, 0.035) }
    /// L3 选中 / 正在生效（深色 = surfaceTop #393939）
    var fill3: Color { isDark ? surfaceTop : bgMuted.barlyMix(.black, 0.07) }
    /// L1′ 次容器：过程卡、代码块标题栏、弹出菜单（介于底和 L1 之间）
    var fill0: Color { isDark ? bgSubtle.barlyMix(surface, 0.45) : bgSubtle }

    /// 控件面：浅色 = 白 + 1px 边；深色 = L1 实色、几乎无边（Lumix：容器无边框，靠明度差）
    var fieldBg: Color { isDark ? fill1 : surface }
    var fieldBorder: Color { isDark ? Color.white.opacity(0.045) : border }
    /// 浅灰无边的次级面（示例卡、来源卡、建议块）——同一个值通吃
    var softSurface: Color { isDark ? fill1 : bgSubtle.barlyMix(bgMuted, 0.45) }
    /// 发丝线（表格线、分隔、侧栏右沿）
    var hairline: Color { isDark ? border : divider }
    /// 深色 AI 产出（代码块/过程卡）的「顶部受光」描边
    var litEdgeTop: Color { isDark ? Color.white.opacity(0.11) : border }
    var litEdgeBottom: Color { isDark ? Color.white.opacity(0.03) : border }

    /// 表头：浅色 = 强调色 10% 底 + 同色相深字；深色 = L1
    var tableHeaderBg: Color { isDark ? fill1 : accentSoft.barlyMix(.white, 0.25) }
    var tableHeaderFg: Color { isDark ? text3 : accentSoftFg.barlyMix(text, 0.35) }

    /// 名字渐变（招牌 name-gradient）= 生成的 nameGradientFrom → nameGradientTo
    var nameGradient: [Color] { [nameGradientFrom, nameGradientTo] }

    /// 首页快捷 chip 的多色线性图标（docs/summarize/news/voice/idea/image 循环；深色令牌里已统一成灰）
    /// force = 深色下也取浅色那套彩色（Lumix 服务 chip「各有本色」）
    func chipIcon(_ i: Int, force: Bool = false) -> Color {
        let p = force ? BarlyTokens.light : self
        let all = [p.chipIconDocs, p.chipIconSummarize, p.chipIconNews, p.chipIconVoice, p.chipIconIdea, p.chipIconImage]
        return all[((i % 6) + 6) % 6]
    }

    /// 头像缺图时的浅色首字母底（米黄、浅紫、浅蓝、浅绿、浅粉）
    static let avatarTints: [(bg: Color, fg: Color)] = [
        (Color(hex: 0xF6EBCF), Color(hex: 0x6D5A23)), (Color(hex: 0xE6E0FA), Color(hex: 0x4A3D84)),
        (Color(hex: 0xDCEBFB), Color(hex: 0x24496F)), (Color(hex: 0xDDF2E4), Color(hex: 0x2C5B3E)),
        (Color(hex: 0xF8E1E4), Color(hex: 0x6E2E38)),
    ]
}

// MARK: - 尺寸（实测；按平台）

public enum BarlyMetrics {
    // 移动
    public static let pageX: CGFloat = 20          // Bimbo 20；Lumix 16
    public static let topBar: CGFloat = 44
    public static let chipH: CGFloat = 36
    public static let inputH: CGFloat = 48
    public static let composerH: CGFloat = 120
    public static let sendKey: CGFloat = 30
    public static let gap: CGFloat = 12
    // 桌面
    public static let sidebar: CGFloat = 272
    public static let rail: CGFloat = 80
    public static let titleBar: CGFloat = 64
    public static let toolbar: CGFloat = 64
    public static let contentPad: CGFloat = 24
    public static let cardPad: CGFloat = 16
    public static let rowH: CGFloat = 48
    public static let control: CGFloat = 36
    public static let icon: CGFloat = 16
}
