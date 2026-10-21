import Foundation

/// 界面文字：源语言是中文，英文在 app 的 Localizable.xcstrings 里。
/// 字面量传进 `String` 参数（自己的组件、服务层的提示）时用 L(...) 包一下，编译时会被抽进字符串表
public func L(_ resource: LocalizedStringResource) -> String {
    String(localized: resource)
}
