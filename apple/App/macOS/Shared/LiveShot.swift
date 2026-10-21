import AppKit

/// 真窗口截图的启动参数（new-apple.sh liveshot 用）：离屏截图（barly-snap）拍不到系统渲染的东西——
/// ⌘, 设置窗口（系统 Form / 下拉菜单 / 开关）、NSPopover 材质、菜单栏图标——所以让 app 一启动就把它们打开，再按窗口截真图。
///
///   --open-settings        启动 1 秒后打开 ⌘, 设置窗口（标签页用 `-settingsTab <序号>` 选，UserDefaults 参数域）
///   --open-popover         菜单栏形态：弹出状态栏弹窗
///   --open-shelf           货架形态：在屏幕中央弹出一个货架
///   --open-panel           浮动面板形态：弹出面板
///   明暗：`-appearance dark|light`（同样走 UserDefaults 参数域，@AppStorage("appearance") 直接读到）
@MainActor
enum LiveShot {
    static let args = CommandLine.arguments
    static func has(_ flag: String) -> Bool { args.contains(flag) }

    /// 各形态的入口在启动完成后调一次；action 是形态自己的「打开」动作（弹窗 / 货架 / 面板）
    static func handle(open action: (() -> Void)? = nil) {
        guard has("--open-settings") || has("--open-popover") || has("--open-shelf") || has("--open-panel") else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if has("--open-settings") { AppKitSupport.openSettings() } else { action?() }
        }
    }
}
