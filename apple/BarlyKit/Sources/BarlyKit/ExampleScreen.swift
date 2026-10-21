import SwiftUI

/// 截图登记的一屏（barly-snap 截图用）：示例屏（BarlyExamples）和产品屏（Screens/ProductScreens）都用它。
/// 放在 BarlyKit 里，产品代码登记截图不用依赖示例屏
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
