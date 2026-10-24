import SwiftUI

extension SessionName {
    /// 「主题｜动作」显示成「主题 | 动作」，竖线浅灰、细一号（参考 Codex 侧栏）；没有动作就是普通文字。
    /// 返回 Text：外面照常套 barlyText，竖线自己的颜色不会被盖掉
    static func text(_ name: String, separator: Color) -> Text {
        let p = parts(name)
        guard let action = p.action else { return Text(verbatim: name) }
        return Text(verbatim: p.topic) + Text(verbatim: " | ").foregroundColor(separator).fontWeight(.light) + Text(verbatim: action)
    }
}
