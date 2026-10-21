import SwiftUI

extension WorkspaceStore {
    /// 某一种弹窗的绑定（.sheet(item:)、.alert 用）：读 = 当前开着的是不是这种；关 = 当前是这种才收起，别的弹窗不动
    func presented<T>(_ value: @escaping (Presentation) -> T?) -> Binding<T?> {
        Binding(get: { self.presentation.flatMap(value) },
                set: { if $0 == nil, self.presentation.flatMap(value) != nil { self.presentation = nil } })
    }

    func isPresenting<T>(_ value: @escaping (Presentation) -> T?) -> Binding<Bool> {
        Binding(get: { self.presentation.flatMap(value) != nil },
                set: { if !$0, self.presentation.flatMap(value) != nil { self.presentation = nil } })
    }
}
