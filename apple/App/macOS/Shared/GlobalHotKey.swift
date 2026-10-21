import Carbon.HIToolbox

/// 系统级全局快捷键：本 app 不在前台时也能触发。
/// 只有 Carbon 的 RegisterEventHotKey 能做到「全局 + 不需要辅助功能权限 + 能吞掉按键」；NSEvent 全局监听要辅助功能权限且只能旁听。
/// 注册在 app 整个生命周期有效（面板 app 常驻），不做注销。
@MainActor
final class GlobalHotKey {
    enum Key { static let space = UInt32(kVK_Space) }
    enum Modifier {
        static let command = UInt32(cmdKey)
        static let option = UInt32(optionKey)
        static let control = UInt32(controlKey)
        static let shift = UInt32(shiftKey)
    }

    nonisolated(unsafe) private static var actions: [UInt32: () -> Void] = [:]
    nonisolated(unsafe) private static var handler: EventHandlerRef?
    private static var nextID: UInt32 = 1
    private var reference: EventHotKeyRef?

    /// 组合键被别的 app 占用时返回 nil（设置里提示用户换一个）
    init?(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        Self.installHandlerIfNeeded()
        let id = Self.nextID
        Self.nextID += 1
        let hotKeyID = EventHotKeyID(signature: OSType(0x4252_4C59), id: id)  // 'BRLY'
        guard RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &reference) == noErr else { return nil }
        Self.actions[id] = action
    }

    private static func installHandlerIfNeeded() {
        guard handler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            let id = hotKeyID.id
            // 应用级事件目标的回调在主线程
            DispatchQueue.main.async { GlobalHotKey.actions[id]?() }
            return noErr
        }, 1, &spec, nil, &handler)
    }
}
