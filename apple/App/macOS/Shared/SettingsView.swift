import SwiftUI
import BarlyKit
import Screens

/// ⌘, 设置窗口：**系统原生样式**——顶部图标标签页（TabView）+ 分组表单（Form .grouped）+ 系统控件，
/// 身份只体现在全局强调色（Assets 的 AccentColor）上：开关、选中的标签页、焦点环。
/// 不要给整个 Form 加 `.tint(accent)`：下拉的值、禁用项会被染成强调色字（references/mac-native.md §5.1）。
struct BarlySettingsView: View {
    @AppStorage("settingsTab") private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            GeneralSettings().tabItem { Label("通用", systemImage: "gearshape") }.tag(0)
            AppearanceSettings().tabItem { Label("外观", systemImage: "paintpalette") }.tag(1)
            TerminalSettings().tabItem { Label("终端", systemImage: "terminal") }.tag(2)
            HostSettings().tabItem { Label("主机", systemImage: "server.rack") }.tag(3)
            PermissionSettings().tabItem { Label("权限", systemImage: "lock.shield") }.tag(4)
            HelpSettings().tabItem { Label("帮助", systemImage: "questionmark.circle") }.tag(5)
        }
        .frame(width: 620, height: 660)
    }
}

/// 「外观」偏好 → ColorScheme（nil = 跟随系统；身份 prefersDark 时 barlyRoot 再兜底）
func barlyScheme(_ appearance: String) -> ColorScheme? {
    switch appearance { case "light": .light; case "dark": .dark; default: nil }
}

// MARK: - 通用

private struct GeneralSettings: View {
    @AppStorage(AppLanguage.defaultsKey) private var language = AppLanguage.system.rawValue
    @State private var needsRelaunch = AppLanguage.needsRelaunch
    @AppStorage("restoreTabs") private var restoreTabs = true
    @AppStorage("plainTerminalAsk") private var plainTerminalAsk = true
    @AppStorage("cmdClickFiles") private var cmdClickFiles = "system"
    @AppStorage("notifyTurnDone") private var notifyTurnDone = true
    @AppStorage("notifyNeedsInput") private var notifyNeedsInput = true
    @AppStorage("showSubagents") private var showSubagents = false

    var body: some View {
        Form {
            Section {
                Picker("界面语言", selection: $language) {
                    Text("跟随系统").tag(AppLanguage.system.rawValue)
                    Text(verbatim: "简体中文").tag(AppLanguage.zh.rawValue)
                    Text(verbatim: "English").tag(AppLanguage.en.rawValue)
                }
                .onChange(of: language) { _, new in
                    AppLanguage.apply(AppLanguage(rawValue: new) ?? .system)
                    needsRelaunch = AppLanguage.needsRelaunch
                }
                if needsRelaunch {
                    LabeledContent {
                        Button("现在重新启动") { AppLanguage.relaunch() }
                    } label: {
                        Text("重新启动 Switchboard 后换成新语言")
                        Text("会话标签会重新打开，CLI 在 tmux 里接着跑；普通终端会关掉。")
                    }
                }
            }
            Section("标签") {
                Toggle("启动时重新打开上次的标签", isOn: $restoreTabs)
                Toggle("关闭普通终端前先问一下", isOn: $plainTerminalAsk)
                LabeledContent("关闭会话标签时") {
                    Text("按主机设置，见「主机」").foregroundStyle(.secondary)
                }
                Picker("⌘-点按终端里的文件", selection: $cmdClickFiles) {
                    Text("用系统默认 app 打开").tag("system")
                    Text("每次询问").tag("ask")
                    Divider()
                    Text("Visual Studio Code").tag("vscode")
                    Text("Cursor").tag("cursor")
                    Text("Zed").tag("zed")
                }
            }
            Section("通知") {
                Toggle("CLI 跑完一轮", isOn: $notifyTurnDone)
                Toggle("CLI 停下来等我回答", isOn: $notifyNeedsInput)
            }
            Section("会话库") {
                Toggle("在发起它们的会话下面显示子代理会话", isOn: $showSubagents)
            }
            Section {
                HStack {
                    Button("发送反馈…") { NSWorkspace.shared.open(FeedbackLinks.feedback()) }
                    Button("报告问题…") { NSWorkspace.shared.open(FeedbackLinks.bugReport()) }
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - 外观

private struct AppearanceSettings: View {
    @AppStorage(AppAppearance.defaultsKey) private var appearance = AppAppearance.defaultValue
    @AppStorage("appTheme") private var theme = AppTheme.switchboard.rawValue
    @AppStorage(BarlyScale.defaultsKey) private var interfaceScale = 1.0

    var body: some View {
        Form {
            Section {
                Picker("明暗", selection: $appearance) {
                    Text("跟随系统").tag("system")
                    Text("浅色").tag("light")
                    Text("深色").tag("dark")
                }
                .pickerStyle(.segmented)
                VStack(alignment: .leading, spacing: 10) {
                    Text("主题")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 18), count: 3), spacing: 14) {
                        ForEach(AppTheme.allCases) { item in
                            VStack(spacing: 6) {
                                ThemePreviewCard(theme: item, selected: item.rawValue == theme)
                                Text(item.title)
                                    .font(.callout.weight(item.rawValue == theme ? .semibold : .regular))
                                    .foregroundStyle(item.rawValue == theme ? .primary : .secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { theme = item.rawValue }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(item.title)
                            .accessibilityAddTraits(item.rawValue == theme ? [.isButton, .isSelected] : .isButton)
                            .accessibilityAction { theme = item.rawValue }
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("App")
            } footer: {
                Text("每套主题都有浅色和深色：卡片左上是浅色、右下是深色，上面的「明暗」决定用哪一半。终端配色默认跟着主题，也可以在「终端」里单独选。").foregroundStyle(.secondary)
            }
            ThemeColorsSection(theme: AppTheme(rawValue: theme) ?? .switchboard)
            Section {
                LabeledContent("界面大小") {
                    HStack(spacing: 10) {
                        Slider(value: $interfaceScale, in: BarlyScale.range, step: 0.1).frame(width: 200)
                        Text(interfaceScale, format: .percent.precision(.fractionLength(0)))
                            .monospacedDigit().foregroundStyle(.secondary).frame(width: 44, alignment: .trailing)
                    }
                }
            } footer: {
                Text("侧栏、标签和对话框里的文字跟着放大缩小。终端字号在「终端」里单独设。").foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

/// 自定义颜色：改当前主题的几个颜色，浅色、深色分开改，马上生效
private struct ThemeColorsSection: View {
    let theme: AppTheme
    @Environment(\.colorScheme) private var scheme
    @AppStorage(ThemeColors.revisionKey) private var revision = 0
    /// nil = 跟着当前明暗，看到的就是正在改的那套
    @State private var editsDark: Bool?

    private var dark: Bool { editsDark ?? (scheme == .dark) }

    var body: some View {
        let _ = revision
        let base = theme.baseSpec(dark: dark)
        let changes = ThemeColors.changes(theme, dark: dark)
        Section {
            Picker("改哪一套", selection: Binding(get: { dark }, set: { editsDark = $0 })) {
                Text("浅色").tag(false)
                Text("深色").tag(true)
            }
            .pickerStyle(.segmented)
            ForEach(ThemeColorRole.allCases) { role in
                LabeledContent(role.title) {
                    HStack(spacing: 8) {
                        if changes[role] != nil {
                            Button("还原") { ThemeColors.set(nil, for: role, theme: theme, dark: dark) }
                                .buttonStyle(.link).controlSize(.small)
                        }
                        ColorPicker("", selection: Binding(
                            get: { Color(hex: changes[role] ?? Self.value(role, base)) },
                            set: { ThemeColors.set(Self.hex($0), for: role, theme: theme, dark: dark) }
                        ), supportsOpacity: false)
                        .labelsHidden()
                    }
                }
            }
        } header: {
            HStack {
                Text("自定义颜色")
                Spacer()
                Button("全部还原") { ThemeColors.reset(theme) }
                    .controlSize(.small)
                    .disabled(!ThemeColors.hasChanges(theme))
            }
        } footer: {
            Text("改的是「\(theme.title)」主题，换别的主题再换回来还在。按钮上的字会自动选黑或白，保证看得清。").foregroundStyle(.secondary)
        }
    }

    static func value(_ role: ThemeColorRole, _ s: AppTheme.Spec) -> UInt32 {
        switch role {
        case .canvas: s.canvas
        case .sidebar: s.sidebar
        case .surface: s.surface
        case .text: s.text
        case .accent: s.accent
        }
    }

    static func hex(_ color: Color) -> UInt32? {
        guard let c = NSColor(color).usingColorSpace(.sRGB) else { return nil }
        func ch(_ v: CGFloat) -> UInt32 { UInt32((min(max(v, 0), 1) * 255).rounded()) }
        return ch(c.redComponent) << 16 | ch(c.greenComponent) << 8 | ch(c.blueComponent)
    }
}

// MARK: - 终端

private struct TerminalSettings: View {
    @AppStorage("terminalScheme") private var scheme = "app"
    @AppStorage("terminalBrightness") private var brightness = "app"
    @AppStorage("colorIntensity") private var intensity = 100.0
    @AppStorage("terminalFont") private var font = "system"
    @AppStorage("terminalFontSize") private var fontSize = TerminalStyle.defaultFontSize
    @AppStorage(TerminalEngine.defaultsKey) private var engine = TerminalEngine.swiftTerm.rawValue
    @State private var families: [String] = []
    @State private var importError: String?

    var body: some View {
        Form {
            Section {
                Picker("引擎", selection: $engine) {
                    ForEach(TerminalEngine.allCases, id: \.self) { e in Text(verbatim: e.title).tag(e.rawValue) }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text(engine == TerminalEngine.ghostty.rawValue
                     ? "Ghostty 用 GPU 渲染，大量输出时更流畅。只对之后新开的标签生效，开着的标签不变。字体选「系统等宽」时用 Ghostty 自带的字体。"
                     : "SwiftTerm 是默认引擎。换成 Ghostty 只对之后新开的标签生效。")
                    .foregroundStyle(.secondary)
            }
            Section("颜色") {
                Picker("配色", selection: $scheme) {
                    ForEach(TerminalColors.schemeChoices, id: \.id) { choice in
                        Text(choice.title).tag(choice.id)
                    }
                }
                LabeledContent("从 iTerm2 导入") {
                    Button("选择 .itermcolors 文件…", action: importITerm)
                }
                if let importError {
                    Text(importError).font(.caption).foregroundStyle(.red)
                }
                Picker("明暗", selection: $brightness) {
                    Text("跟随 App").tag("app")
                    Text("浅色").tag("light")
                    Text("深色").tag("dark")
                }
                LabeledContent("色彩强度") {
                    HStack {
                        Slider(value: $intensity, in: 50...200, step: 10).frame(width: 220)
                        Text("\(Int(intensity))%").monospacedDigit().foregroundStyle(.secondary).frame(width: 44, alignment: .trailing)
                    }
                }
            }
            Section {
                Picker("字体", selection: $font) {
                    Text("系统等宽").tag("system")
                    if !families.isEmpty { Divider() }
                    ForEach(families, id: \.self) { Text($0).tag($0) }
                }
                Stepper(value: $fontSize, in: 10...24) {
                    LabeledContent("字号", value: "\(fontSize) pt")
                }
            } header: {
                Text("字体")
            } footer: {
                Text("⌘+ / ⌘− / ⌘0 也能调终端字号。").foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .task { families = TerminalStyle.monospacedFamilies() }
    }

    private func importITerm() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "itermcolors") ?? .propertyList]
        panel.prompt = L("导入")
        guard panel.runModal() == .OK, let url = panel.url, let data = try? Data(contentsOf: url) else { return }
        if let colors = TerminalColors.parseITermColors(data) {
            TerminalColors.saveImported(colors)
            scheme = "iterm"
            importError = nil
        } else {
            importError = L("这个文件不是完整的 iTerm2 配色（要有 16 色和前景、背景）。")
        }
    }
}

// MARK: - 主机

private struct HostSettings: View {
    private let hosts = WorkspaceStore.savedHostAliases()

    var body: some View {
        Form {
            Section {
                CloseBehaviorPicker(hostID: Host.localID, title: L("这台 Mac"))
                ForEach(hosts, id: \.self) { CloseBehaviorPicker(hostID: $0, title: $0) }
            } header: {
                Text("关闭会话标签时")
            } footer: {
                Text("CLI 在 tmux 里还在跑时怎么处理。关标签的对话框里勾「不再询问」也会改这里。").foregroundStyle(.secondary)
            }
            Section {
                if hosts.isEmpty {
                    Text("还没有 SSH 主机。在侧栏底部点「添加 SSH 主机…」。").foregroundStyle(.secondary)
                } else {
                    ForEach(hosts, id: \.self) { alias in
                        HStack(spacing: 10) {
                            Image(systemName: "server.rack").foregroundStyle(.secondary)
                            Text(alias)
                            Spacer()
                            Text("在侧栏右键主机：刷新、断开、移除").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("SSH 主机")
            }
        }
        .formStyle(.grouped)
    }
}

private struct CloseBehaviorPicker: View {
    let title: String
    @AppStorage private var value: String

    init(hostID: String, title: String) {
        self.title = title
        _value = AppStorage(wrappedValue: "ask", "closeBehavior.\(hostID)")
    }

    var body: some View {
        Picker(title, selection: $value) {
            Text("每次询问").tag("ask")
            Text("让 CLI 继续运行").tag("keep")
            Text("结束会话").tag("end")
        }
    }
}

// MARK: - 权限

private struct PermissionSettings: View {
    @State private var status = PermissionStatus()

    var body: some View {
        Form {
            Section {
                PermissionRow(title: L("通知"), detail: L("CLI 跑完一轮、停下来等你时提醒"), state: status.notifications, pane: .notifications)
                PermissionRow(title: L("完全磁盘访问"), detail: L("可选。终端里的 CLI 打开「文稿」等受保护文件夹时不再逐个弹窗"), state: status.fullDiskAccess, pane: .fullDisk)
                PermissionRow(title: L("辅助功能"), detail: L("可选。允许终端里的 CLI 控制其他 app（点菜单、按键）。会给所有 CLI，按需开启"), state: status.accessibility, pane: .accessibility)
                PermissionRow(title: L("本地网络"), detail: L("连局域网里的 SSH 主机需要。macOS 不让 app 查询，请在系统设置里确认"), state: .unknown, pane: .localNetwork)
            } footer: {
                Text("从系统设置回来时会自动重新检查，检查本身不会弹出授权请求。").foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { status.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in status.refresh() }
    }
}

private struct PermissionRow: View {
    typealias State = PermissionStatus.State
    let title: String
    let detail: String
    let state: State
    let pane: PermissionStatus.Pane

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: state == .granted ? "checkmark.circle.fill" : state == .notGranted ? "circle" : "questionmark.circle")
                .foregroundStyle(state == .granted ? AnyShapeStyle(.green) : AnyShapeStyle(.secondary))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            if state == .granted {
                Text("已允许").font(.caption).foregroundStyle(.secondary)
            } else {
                Button("打开系统设置") { PermissionStatus.openSettings(pane) }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 帮助

private struct HelpSettings: View {
    @AppStorage("showTips") private var showTips = true
    @Bindable private var updater = AppUpdater.shared

    static let shortcuts: [(String, [String])] = [
        (L("新会话"), ["⌘", "N"]), (L("新窗口"), ["⇧", "⌘", "N"]), (L("分屏"), ["⌥", "⌘", "N"]),
        (L("关闭标签"), ["⌘", "W"]), (L("下一个标签"), ["⇧", "⌘", "]"]), (L("上一个标签"), ["⇧", "⌘", "["]),
        (L("第 1–8 个标签"), ["⌘", "1…8"]), (L("隐藏侧栏"), ["⌘", "B"]), (L("后退"), ["⌘", "["]), (L("前进"), ["⌘", "]"]),
        (L("查找"), ["⌘", "F"]), (L("设置"), ["⌘", ","]),
    ]

    var body: some View {
        Form {
            Section("快捷键") {
                ForEach(Self.shortcuts, id: \.0) { item in
                    LabeledContent(item.0) { KeyCombo(item.1) }
                }
            }
            Section("上手") {
                Toggle("每次打开时在侧栏底部显示一条小贴士", isOn: $showTips)
                LabeledContent("引导") {
                    Button("重新看一遍") { NotificationCenter.default.post(name: .switchboardReplayTour, object: nil) }
                }
                LabeledContent("使用说明") { Button("打开帮助") { NSWorkspace.shared.open(AppLinks.guide()) } }
            }
            Section("更新") {
                LabeledContent("版本") { Text(verbatim: AppUpdater.versionString).monospacedDigit() }
                Toggle("每天自动检查更新", isOn: $updater.automaticallyChecks)
                LabeledContent {
                    Button("检查更新…") { updater.checkForUpdates() }
                } label: {
                    Text("现在检查")
                    if let last = updater.lastCheck {
                        Text("上次检查：\(last.formatted(date: .abbreviated, time: .shortened))")
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
