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
                    Button("发送反馈…") {}
                    Button("报告问题…") {}
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - 外观

private struct AppearanceSettings: View {
    @AppStorage("appearance") private var appearance = "dark"
    @AppStorage("appTheme") private var theme = AppTheme.switchboard.rawValue
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Form {
            Section {
                Picker("明暗", selection: $appearance) {
                    Text("跟随系统").tag("system")
                    Text("浅色").tag("light")
                    Text("深色").tag("dark")
                }
                .pickerStyle(.segmented)
                Picker("主题", selection: $theme) {
                    ForEach(AppTheme.allCases) { item in
                        HStack(spacing: 8) {
                            ThemeChip(colors: item.swatch(dark: scheme == .dark))
                            Text(item.title)
                        }
                        .tag(item.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)
            } header: {
                Text("App")
            } footer: {
                Text("每套主题都有浅色和深色。终端配色默认跟着主题，也可以在「终端」里单独选。").foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

/// 主题小样：底 · 面板 · 强调色三块
private struct ThemeChip: View {
    let colors: [Color]
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(colors.enumerated()), id: \.offset) { Rectangle().fill($0.element) }
        }
        .frame(width: 36, height: 14)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(.quaternary))
    }
}

// MARK: - 终端

private struct TerminalSettings: View {
    @AppStorage("terminalScheme") private var scheme = "app"
    @AppStorage("terminalBrightness") private var brightness = "app"
    @AppStorage("colorIntensity") private var intensity = 100.0
    @AppStorage("terminalFont") private var font = "system"
    @AppStorage("terminalFontSize") private var fontSize = TerminalStyle.defaultFontSize
    @State private var families: [String] = []
    @State private var importError: String?

    var body: some View {
        Form {
            Section {
                LabeledContent("引擎") {
                    Text("SwiftTerm").foregroundStyle(.secondary)
                }
            } footer: {
                Text("Ghostty（GPU 渲染）引擎还没接入，之后会在这里切换。").foregroundStyle(.secondary)
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
    var body: some View {
        Form {
            Section {
                PermissionRow(title: L("通知"), detail: L("CLI 跑完一轮、停下来等你时提醒"), state: .granted)
                PermissionRow(title: L("完全磁盘访问"), detail: L("可选。终端里的 CLI 打开「文稿」等受保护文件夹时不再逐个弹窗"), state: .notGranted)
                PermissionRow(title: L("辅助功能"), detail: L("可选。允许终端里的 CLI 控制其他 app（点菜单、按键）。会给所有 CLI，按需开启"), state: .notGranted)
                PermissionRow(title: L("本地网络"), detail: L("连局域网里的 SSH 主机需要。macOS 不让 app 查询，请在系统设置里确认"), state: .unknown)
            } footer: {
                Text("从系统设置回来时会自动重新检查，检查本身不会弹出授权请求。").foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct PermissionRow: View {
    enum State { case granted, notGranted, unknown }
    let title: String
    let detail: String
    let state: State

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
                Button("打开系统设置") {}
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
                LabeledContent("引导") { Button("重新看一遍") {} }
                LabeledContent("使用说明") { Button("打开帮助") {} }
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
