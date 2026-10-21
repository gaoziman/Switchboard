import SwiftUI
import BarlyKit

/// 示例屏目录：snap 和两个 App 都从这里取
public struct ExampleScreen: Identifiable, Sendable {
    public enum Platform: String, Sendable { case ios, macos }
    public let id: String
    public let title: String
    public let platform: Platform
    public let make: @Sendable @MainActor () -> AnyView
    /// 自定义尺寸：菜单栏弹窗（如 360×480）、浮动面板（如 680×420）、设置窗口（如 640×440）、复刻屏
    public var customSize: CGSize? = nil
    public var size: CGSize { customSize ?? (platform == .ios ? CGSize(width: 393, height: 852) : CGSize(width: 1440, height: 1024)) }
    /// 产品屏（Sources/Screens/ProductScreens.swift）也用它登记；id 以 ios- / mac- 开头，截图名 = id-light|dark.png
    public init(id: String, title: String, platform: Platform, make: @escaping @Sendable @MainActor () -> AnyView) {
        self.id = id; self.title = title; self.platform = platform; self.make = make
    }
    public init(id: String, title: String, platform: Platform, size: CGSize, make: @escaping @Sendable @MainActor () -> AnyView) {
        self.id = id; self.title = title; self.platform = platform; self.make = make; self.customSize = size
    }
    public var scale: CGFloat { platform == .ios ? 3 : 2 }
}

@MainActor
public enum ExampleCatalog {
    public static let all: [ExampleScreen] = [
        ExampleScreen(id: "ios-home", title: "Home 欢迎页", platform: .ios) { AnyView(PhoneScreen { HomeScreen() }) },
        ExampleScreen(id: "ios-chat", title: "Chat 对话中", platform: .ios) { AnyView(PhoneScreen { ChatScreen() }) },
        ExampleScreen(id: "ios-voice", title: "Voice 语音模式", platform: .ios) { AnyView(PhoneScreen { VoiceScreen() }) },
        ExampleScreen(id: "ios-listening", title: "Listening 语音聆听（粒子环）", platform: .ios) { AnyView(PhoneScreen { ListeningScreen() }) },
        ExampleScreen(id: "ios-plus", title: "Plus 付费页", platform: .ios) { AnyView(PhoneScreen { PlusScreen() }) },
        ExampleScreen(id: "ios-lumix-home", title: "Lumix 式首页", platform: .ios) { AnyView(PhoneScreen { LumixHomeScreen() }) },
        // 风格族示例屏（ios-f-<族>）：截图时挑和身份 style 一致的那张（new-apple.sh families 自动挑）
        ExampleScreen(id: "ios-f-editorial", title: "editorial 今日阅读 / 预约", platform: .ios) { AnyView(PhoneScreen { EditorialReadingScreen() }) },
        ExampleScreen(id: "ios-f-swiss", title: "swiss 目录 / 规格", platform: .ios) { AnyView(PhoneScreen { SwissSpecScreen() }) },
        ExampleScreen(id: "ios-f-brutal", title: "brutal 商品详情", platform: .ios) { AnyView(PhoneScreen { BrutalProductScreen() }) },
        ExampleScreen(id: "ios-f-flood", title: "flood 个人名片 / 活动", platform: .ios) { AnyView(PhoneScreen { FloodCardScreen() }) },
        ExampleScreen(id: "ios-f-press", title: "press 资讯首页", platform: .ios) { AnyView(PhoneScreen { PressFrontScreen() }) },
        ExampleScreen(id: "ios-f-noir", title: "noir 音乐人 / 巡演", platform: .ios) { AnyView(PhoneScreen { NoirTourScreen() }) },
        ExampleScreen(id: "ios-f-soft", title: "soft 托育预约", platform: .ios) { AnyView(PhoneScreen { SoftCareScreen() }) },
        ExampleScreen(id: "ios-f-gallery", title: "gallery 摄影集", platform: .ios) { AnyView(PhoneScreen { GalleryAlbumScreen() }) },
        ExampleScreen(id: "ios-f-console", title: "console 指标看板", platform: .ios) { AnyView(PhoneScreen { ConsoleMetricsScreen() }) },
        ExampleScreen(id: "mac-dashboard", title: "Dashboard（Brisk 式 CRM）", platform: .macos) { AnyView(DashboardScreen()) },
        ExampleScreen(id: "mac-chat-empty", title: "AI Chat 问候空状态", platform: .macos) { AnyView(AIChatScreen(thread: false)) },
        ExampleScreen(id: "mac-chat-thread", title: "AI Chat 对话中", platform: .macos) { AnyView(AIChatScreen(thread: true)) },
        ExampleScreen(id: "mac-f-console", title: "console 指标看板", platform: .macos) { AnyView(MetricsBoardScreen()) },
        // 应用页面模式（AppScreensMac / AppScreensIOS，组件在 BarlyKit/Components/Apps）
        ExampleScreen(id: "mac-kanban", title: "看板（多列）", platform: .macos) { AnyView(KanbanBoardScreen()) },
        ExampleScreen(id: "mac-calendar", title: "日历周视图 + 预约侧栏", platform: .macos) { AnyView(CalendarScreen()) },
        ExampleScreen(id: "mac-mail", title: "邮件式分栏（列表 + 详情）", platform: .macos) { AnyView(MailScreen()) },
        ExampleScreen(id: "mac-journal", title: "日记（单列阅读宽度）", platform: .macos) { AnyView(JournalScreen()) },
        ExampleScreen(id: "mac-habits", title: "习惯打卡 + 热力格", platform: .macos) { AnyView(HabitsScreen()) },
        ExampleScreen(id: "mac-settings", title: "设置（分组表单 + 危险区）", platform: .macos) { AnyView(SettingsScreen()) },
        ExampleScreen(id: "mac-empty", title: "空状态四种", platform: .macos) { AnyView(EmptyStatesScreen()) },
        // macOS 形态样板（--mac-form）与 dna v2 复刻屏
        ExampleScreen(id: "mac-form-menubar", title: "菜单栏弹窗（--mac-form menubar）", platform: .macos, size: CGSize(width: 360, height: 470)) { AnyView(MenuBarExampleScreen().environment(\.barlySystemUIFont, true).frame(maxHeight: .infinity, alignment: .top)) },
        ExampleScreen(id: "mac-form-panel", title: "浮动面板 / 启动器（--mac-form panel）", platform: .macos, size: CGSize(width: 680, height: 452)) { AnyView(LauncherExampleScreen().environment(\.barlySystemUIFont, true)) },
        ExampleScreen(id: "mac-form-shelf", title: "拖放货架 · 叠放（--mac-form shelf）", platform: .macos, size: CGSize(width: 244, height: 290)) { AnyView(ShelfExampleScreen().environment(\.barlySystemUIFont, true)) },
        ExampleScreen(id: "mac-form-shelf-list", title: "拖放货架 · 展开列表", platform: .macos, size: CGSize(width: 360, height: 380)) { AnyView(ShelfListExampleScreen().environment(\.barlySystemUIFont, true)) },
        ExampleScreen(id: "mac-form-shelf-drop", title: "拖放货架 · 拖入中", platform: .macos, size: CGSize(width: 244, height: 260)) { AnyView(ShelfDropExampleScreen().environment(\.barlySystemUIFont, true)) },
        ExampleScreen(id: "mac-form-settings", title: "设置窗口（⌘,，三种形态共用）", platform: .macos, size: CGSize(width: 700, height: 470)) { AnyView(SettingsWindowExampleScreen().environment(\.barlySystemUIFont, true)) },
        ExampleScreen(id: "mac-ref-enigma", title: "复刻：Enigma Traces（饱满 · 深色）", platform: .macos, size: CGSize(width: 1440, height: 991)) { AnyView(EnigmaTracesScreen()) },
        ExampleScreen(id: "mac-ref-rekann", title: "复刻：Rekann Dashboard（饱满 · 灰壳 · 助手面板）", platform: .macos, size: CGSize(width: 1440, height: 1029)) { AnyView(RekannDashboardScreen()) },
        ExampleScreen(id: "ios-kanban", title: "看板（横滑列）", platform: .ios) { AnyView(PhoneScreen { KanbanPhoneScreen() }) },
        ExampleScreen(id: "ios-calendar", title: "日视图 + 可用时间", platform: .ios) { AnyView(PhoneScreen { CalendarPhoneScreen() }) },
        ExampleScreen(id: "ios-mail", title: "邮件列表", platform: .ios) { AnyView(PhoneScreen { MailListPhoneScreen() }) },
        ExampleScreen(id: "ios-mail-detail", title: "邮件详情", platform: .ios) { AnyView(PhoneScreen { MailDetailPhoneScreen() }) },
        ExampleScreen(id: "ios-journal", title: "日记", platform: .ios) { AnyView(PhoneScreen { JournalPhoneScreen() }) },
        ExampleScreen(id: "ios-habits", title: "习惯打卡", platform: .ios) { AnyView(PhoneScreen { HabitsPhoneScreen() }) },
        ExampleScreen(id: "ios-settings", title: "设置", platform: .ios) { AnyView(PhoneScreen { SettingsPhoneScreen() }) },
        ExampleScreen(id: "ios-empty", title: "空状态：首次使用", platform: .ios) { AnyView(PhoneScreen { EmptyPhoneScreen(.firstUse) }) },
        ExampleScreen(id: "ios-empty-search", title: "空状态：无结果", platform: .ios) { AnyView(PhoneScreen { EmptyPhoneScreen(.noResults) }) },
    ]
    public static var ios: [ExampleScreen] { all.filter { $0.platform == .ios } }
    /// 当前风格族的示例屏 id（barly 没有专属屏）
    public static var familyScreenIDs: [String] { all.map(\.id).filter { $0.hasSuffix("-f-\(BarlyTokens.family)") } }
    /// 和当前身份相关的示例屏：通用屏 + 本风格族的示例屏（别的族的示例屏用这套令牌渲染没有意义）
    public static var forIdentity: [ExampleScreen] { all.filter { !$0.id.contains("-f-") || familyScreenIDs.contains($0.id) } }
    public static var macos: [ExampleScreen] { all.filter { $0.platform == .macos } }
}

/// iPhone 屏外壳：快照模式下画状态栏（54）和 Home 条（34），App 里交给系统安全区
public struct PhoneScreen<Content: View>: View {
    let content: Content
    @Environment(\.barlySnapshot) private var snapshot
    @Environment(\.barly) private var t
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
    public var body: some View {
        if snapshot {
            content
                .safeAreaPadding(.top, 54).safeAreaPadding(.bottom, 34)
                .overlay(alignment: .top) { FakeStatusBar() }
                .overlay(alignment: .bottom) {
                    Capsule().fill(t.text).frame(width: 134, height: 5).padding(.bottom, 8)
                }
        } else {
            content
        }
    }
}

struct FakeStatusBar: View {
    @Environment(\.barly) private var t
    var body: some View {
        HStack {
            Text("9:41").font(.system(size: 17, weight: .semibold)).padding(.leading, 34)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "cellularbars").font(.system(size: 14, weight: .semibold))
                Image(systemName: "wifi").font(.system(size: 14, weight: .semibold))
                Image(systemName: "battery.100").font(.system(size: 20, weight: .regular))
            }
            .padding(.trailing, 28)
        }
        .foregroundStyle(t.text)
        .frame(height: 54)
        .padding(.top, 2)
    }
}

/// 页面背景（忽略安全区铺满）
struct ScreenBackground<B: View>: ViewModifier {
    let bg: B
    func body(content: Content) -> some View {
        content.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(bg.ignoresSafeArea())
    }
}

extension View {
    /// 页面背景铺满（产品屏也用，apple.md §4）
    public func screenBackground<B: View>(_ b: B) -> some View { modifier(ScreenBackground(bg: b)) }
}
