#if os(macOS)
import AppKit
#endif
import SwiftUI
import BarlyKit

/// sheet 的外框：标题区 · 内容 · 底部按钮条。真 app 里放进 `.sheet`，截图时由 `SheetOverlay` 叠在工作区上
struct SheetFrame<Content: View, Buttons: View>: View {
    let title: String
    var subtitle: String?
    var width: CGFloat = 520
    @ViewBuilder var content: Content
    @ViewBuilder var buttons: Buttons
    @Environment(\.barly) private var t

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).barlyText(.product.sectionTitle, color: t.text)
                if let subtitle { Text(subtitle).barlyText(.product.small, color: t.text3) }
            }
            .padding(.horizontal, 22).padding(.top, 20).padding(.bottom, 16)
            content
                .padding(.horizontal, 22)
                .padding(.bottom, 18)
            Hairline()
            HStack(spacing: 8) { buttons }
                .padding(.horizontal, 16)
                .frame(height: BarlyScale.pt(56))
        }
        .frame(width: BarlyScale.pt(width))
        .background(t.surface)
    }
}

/// 截图用：把 sheet 叠在暗下去的工作区上，位置和系统 sheet 一样（窗口上沿居中）
struct SheetOverlay<Base: View, Sheet: View>: View {
    @ViewBuilder var base: Base
    @ViewBuilder var sheet: Sheet
    @Environment(\.barly) private var t

    var body: some View {
        base
            .overlay(Color.black.opacity(0.45))
            .overlay(alignment: .top) {
                sheet
                    .clipShape(RoundedRectangle(cornerRadius: BarlyRadius.md))
                    .overlay(RoundedRectangle(cornerRadius: BarlyRadius.md).stroke(t.borderStrong))
                    .shadow(color: .black.opacity(0.5), radius: 30, y: 12)
                    .padding(.top, 72)
            }
    }
}

/// 表单一行：左标签固定宽，右控件
struct FieldRow<Control: View>: View {
    let label: String
    var note: String?
    @ViewBuilder var control: Control
    @Environment(\.barly) private var t

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(label).barlyText(.product.small, color: t.text2)
                .frame(width: BarlyScale.pt(72), alignment: .leading)
            VStack(alignment: .leading, spacing: 6) {
                control
                if let note { Text(note).barlyText(.product.caption, color: t.text3).fixedSize(horizontal: false, vertical: true) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// 静态值框（下拉 / 路径）：fieldBg + 边，右侧一个小图标
struct ValueBox: View {
    let text: String
    var icon: String? = "chevron.up.chevron.down"
    var mono = false
    var dim = false
    var error = false
    @Environment(\.barly) private var t

    var body: some View {
        HStack(spacing: 8) {
            Text(text)
                .barlyText(mono ? .product.small.monospaced : .product.small, color: dim ? t.text3 : t.text)
                .lineLimit(1).truncationMode(.middle)
            Spacer(minLength: 4)
            if let icon { Image(systemName: icon).font(.system(size: BarlyScale.pt(10), weight: .medium)).foregroundStyle(t.text3) }
        }
        .padding(.horizontal, 10)
        .frame(height: BarlyScale.pt(30))
        .background(t.fieldBg, in: RoundedRectangle(cornerRadius: BarlyRadius.sm))
        .overlay(RoundedRectangle(cornerRadius: BarlyRadius.sm).stroke(error ? t.danger : t.borderStrong))
        .handCursor()
    }
}

// MARK: - 新会话

public struct NewSessionSheet: View {
    public enum Fixture: String { case normal, editing, invalidCommand, missingFolder }

    @Binding var draft: NewSessionDraft
    let fixture: Fixture
    var installed: [CLIKind] = CLIKind.allCases
    var recentFolders: [String] = []
    /// 能选的主机（这台 Mac + 连着的 SSH 主机）
    var hosts: [Host] = []
    /// 某台主机最近用过的文件夹
    var recentFoldersFor: (String) -> [String] = { _ in [] }
    var savedCommandFor: (CLIKind) -> String? = { _ in nil }
    /// 默认值从哪来：「来自当前标签「…」」。改了文件夹就不显示
    var origin: String?
    var onCancel: () -> Void = {}
    var onStart: () -> Void = {}
    @Environment(\.barly) private var t
    @Environment(\.barlySnapshot) private var snapshot
    /// 打开时的文件夹（默认值）：文件夹还是它，才显示来源
    @State private var initialFolder: String?
    @State private var commandOpen = false

    /// 截图用：固定草稿
    public init(draft: NewSessionDraft, fixture: Fixture = .normal, recentFolders: [String] = [], origin: String? = nil) {
        _draft = .constant(draft)
        self.fixture = fixture
        self.recentFolders = recentFolders
        self.origin = origin
    }

    /// app 里用：可编辑
    public init(draft: Binding<NewSessionDraft>, installed: [CLIKind], recentFolders: [String],
                savedCommandFor: @escaping (CLIKind) -> String? = { _ in nil },
                hosts: [Host] = [], recentFoldersFor: @escaping (String) -> [String] = { _ in [] },
                origin: String? = nil,
                onCancel: @escaping () -> Void, onStart: @escaping () -> Void) {
        self.savedCommandFor = savedCommandFor
        self.hosts = hosts
        self.recentFoldersFor = recentFoldersFor
        self.origin = origin
        _draft = draft
        fixture = .normal
        self.installed = installed
        self.recentFolders = recentFolders
        self.onCancel = onCancel
        self.onStart = onStart
    }

    private var expandedFolder: String { (draft.folder as NSString).expandingTildeInPath }
    private var isRemote: Bool { draft.hostID != Host.localID }
    /// 当前主机装了的 CLI
    private var hostCLIs: [CLIKind] { isRemote ? (hosts.first { $0.id == draft.hostID }?.installedCLIs ?? CLIKind.allCases) : installed }
    private var folders: [String] { isRemote ? recentFoldersFor(draft.hostID) : recentFolders }
    /// 「换成」：最近的文件夹里去掉现在填的这个
    private var otherFolders: [String] {
        folders.filter { $0 != expandedFolder && $0 != draft.folder }.prefix(4).map { $0 }
    }
    private var folderExists: Bool {
        if fixture == .missingFolder { return false }
        if isRemote { return true }   // 主机上的目录启动时由主机检查
        var isDir: ObjCBool = false
        return snapshot || draft.folder.isEmpty || (FileManager.default.fileExists(atPath: expandedFolder, isDirectory: &isDir) && isDir.boolValue)
    }
    private var problem: String? { draft.startProblem(folderExists: folderExists) }
    private var showsCommand: Bool { commandOpen || draft.isEditingCommand || fixture == .editing || fixture == .invalidCommand }

    public var body: some View {
        SheetFrame(title: L("新会话"), subtitle: L("在项目文件夹里启动一个 CLI，会话立刻出现在侧栏。"), width: 600) {
            VStack(alignment: .leading, spacing: 16) {
                FieldRow(label: L("启动")) { targetPicker }
                FieldRow(label: L("文件夹"), note: folderNote) { folderField }
                FieldRow(label: L("主机"), note: isRemote ? L("路径是主机上的；~ 是主机的家目录。主机上的会话用它自己的 tmux。") : nil) { hostPicker }
                FieldRow(label: "") { commandRow }
            }
        } buttons: {
            if fixture == .missingFolder {
                Text("文件夹会连同缺失的上级一起创建").barlyText(.product.caption, color: t.text3)
            } else if let problem, !draft.folder.isEmpty {
                Text(problem).barlyText(.product.caption, color: t.text3)
            }
            Spacer()
            BarlyButton(L("取消"), variant: .outline, size: .md, action: onCancel)
                .keyboardShortcut(.cancelAction)
            BarlyButton(!folderExists ? L("创建文件夹并开始") : L("开始会话"), variant: .primary, size: .md) {
                if !folderExists { try? FileManager.default.createDirectory(atPath: expandedFolder, withIntermediateDirectories: true) }
                onStart()
            }
            .keyboardShortcut(.return, modifiers: .command)
            .help("⌘↩")
            .disabled(draft.isEditingCommand || draft.folder.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(fixture == .editing || fixture == .invalidCommand || draft.folder.isEmpty ? 0.4 : 1)
        }
        .onAppear { if initialFolder == nil { initialFolder = draft.folder } }
    }

    // MARK: 启动方式

    /// 一排分段卡：选中 = 强调色浅底 + 细边 + 右上角小勾，图标也是强调色
    private var targetPicker: some View {
        let options: [(NewSessionDraft.Target, String)] =
            CLIKind.allCases.filter { hostCLIs.contains($0) }.map { (.cli($0), $0.title) } + [(.terminal, L("终端"))]
        let shape = RoundedRectangle(cornerRadius: BarlyRadius.md, style: .continuous)
        return HStack(spacing: 6) {
            ForEach(options, id: \.1) { option in
                let on = option.0 == draft.target
                VStack(spacing: 6) {
                    Group {
                        if case .cli(let cli) = option.0 {
                            CLIMark(cli, size: 18, color: on ? t.accent : nil)
                        } else {
                            Image(systemName: "terminal").font(.system(size: BarlyScale.pt(12)))
                        }
                    }
                    .foregroundStyle(on ? t.accent : t.text3)
                    .frame(height: 18)
                    Text(option.1).barlyText(.product.caption.weight(on ? 600 : 500), color: on ? t.text : t.text2)
                        .lineLimit(1).minimumScaleFactor(0.85)
                }
                .padding(.horizontal, 4)
                .frame(maxWidth: .infinity)
                .frame(height: BarlyScale.pt(58))
                .background(on ? t.accent.opacity(0.12) : t.shellHover, in: shape)
                .overlay(shape.strokeBorder(on ? t.accent.opacity(0.75) : t.hairline, lineWidth: on ? 1.5 : 1))
                .overlay(alignment: .topTrailing) {
                    if on { Image(systemName: "checkmark.circle.fill").font(.system(size: BarlyScale.pt(11))).foregroundStyle(t.accent).padding(5) }
                }
                .contentShape(Rectangle())
                .tapButton {
                    draft.target = option.0
                    if case .cli(let cli) = option.0 { draft.savedCommand = savedCommandFor(cli) } else { draft.savedCommand = nil }
                    draft.editingCommand = nil
                }
                .handCursor()
                .help(option.1)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }

    // MARK: 文件夹

    private var folderField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "folder.fill").font(.system(size: BarlyScale.pt(12))).foregroundStyle(t.text3)
                    FolderTextField(text: $draft.folder)
                }
                .padding(.horizontal, 10)
                .frame(height: BarlyScale.pt(32))
                .background(t.fieldBg, in: RoundedRectangle(cornerRadius: BarlyRadius.sm, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: BarlyRadius.sm, style: .continuous).strokeBorder(!folderExists ? t.danger : t.borderStrong))
                if !isRemote { BarlyButton(L("选择…"), variant: .outline, size: .sm, action: chooseFolder) }
            }
            if let origin, !draft.folder.isEmpty, draft.folder == (initialFolder ?? draft.folder) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.turn.down.right").font(.system(size: BarlyScale.pt(9), weight: .semibold))
                    Text(verbatim: origin).lineLimit(1).truncationMode(.middle)
                }
                .barlyText(.product.caption, color: t.accent)
            }
            if !otherFolders.isEmpty {
                HStack(spacing: 6) {
                    Text("换成").barlyText(.product.caption, color: t.text4)
                    ForEach(otherFolders, id: \.self) { folder in
                        HStack(spacing: 5) {
                            Image(systemName: "folder").font(.system(size: BarlyScale.pt(9.5)))
                            Text((folder as NSString).lastPathComponent).lineLimit(1)
                        }
                        .barlyText(.product.caption, color: t.text2)
                        .padding(.horizontal, 9).frame(height: BarlyScale.pt(24))
                        .background(t.shellHover, in: Capsule())
                        .overlay(Capsule().strokeBorder(t.hairline))
                        .contentShape(Capsule())
                        .tapButton { draft.folder = isRemote ? folder : abbreviate(folder) }
                        .handCursor()
                        .help(folder)
                    }
                }
            }
        }
    }

    private var folderNote: String? {
        if !folderExists { return L("这台 Mac 上没有 \(draft.folder)。") }
        return draft.target == .terminal ? L("终端不是会话：不进会话库、不走 tmux，关标签就结束。") : nil
    }

    // MARK: 主机

    @ViewBuilder private var hostPicker: some View {
        if hosts.count > 1 {
            Picker("", selection: $draft.hostID) {
                ForEach(hosts) { Text($0.isLocal ? L("这台 Mac") : $0.displayName).tag($0.id) }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
            .handCursor()
            .onChange(of: draft.hostID) { _, _ in
                draft.folder = ""
                if case .cli(let cli) = draft.target, !hostCLIs.contains(cli) { draft.target = hostCLIs.first.map { .cli($0) } ?? .terminal }
            }
        } else {
            HStack(spacing: 8) {
                Image(systemName: "laptopcomputer").font(.system(size: BarlyScale.pt(12))).foregroundStyle(t.text3)
                Text("这台 Mac").barlyText(.product.small, color: t.text)
            }
            .frame(height: BarlyScale.pt(30))
        }
    }

    // MARK: 启动命令（收成一行，点开才编辑）

    @ViewBuilder private var commandRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeOut(duration: 0.15)) { commandOpen.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right").font(.system(size: BarlyScale.pt(8), weight: .bold))
                        .rotationEffect(.degrees(showsCommand ? 90 : 0))
                    Text("启动命令")
                    Text(draft.savedCommand ?? draft.effectiveCommand).barlyText(.product.caption.monospaced, color: t.text2)
                    Text(verbatim: draft.savedCommand == nil ? L("· 默认") : L("· 你保存的")).foregroundStyle(t.text4)
                }
                .barlyText(.product.caption, color: t.text3)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .handCursor()
            if showsCommand {
                commandField
                if let note = commandNote { Text(note).barlyText(.product.caption, color: t.text3).fixedSize(horizontal: false, vertical: true) }
            }
        }
    }

    private var commandNote: String? {
        switch fixture {
        case .invalidCommand:
            return NewSessionDraft.commandProblem(draft.editingCommand ?? "")
        case .editing:
            return L("像在 shell 里那样写；引号、~、前置 NAME=value 都行，别名不行。Switchboard 会在后面补上自己的参数（比如要恢复的会话）。")
        default:
            if let editing = draft.editingCommand, let problem = NewSessionDraft.commandProblem(editing) { return problem }
            return draft.savedCommand == nil ? L("空着就用默认命令。这个 CLI 在这台主机上恢复、分叉都会用它。") : nil
        }
    }

    @ViewBuilder private var commandField: some View {
        if draft.editingCommand != nil {
            let editing = Binding(get: { draft.editingCommand ?? "" }, set: { draft.editingCommand = $0 })
            let invalid = fixture == .invalidCommand || NewSessionDraft.commandProblem(editing.wrappedValue) != nil
            HStack(spacing: 6) {
                HStack {
                    BarlyBareField(placeholder: draft.effectiveCommand, text: editing, style: .product.small.monospaced)
                }
                .padding(.horizontal, 10)
                .frame(height: BarlyScale.pt(30))
                .background(t.fieldBg, in: RoundedRectangle(cornerRadius: BarlyRadius.sm, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: BarlyRadius.sm, style: .continuous).stroke(invalid ? t.danger : t.text3, lineWidth: invalid ? 1 : 1.5))
                BarlyButton(L("取消"), variant: .ghost, size: .sm) { draft.editingCommand = nil }
                BarlyButton(L("保存"), variant: .outline, size: .sm) {
                    guard !invalid else { return }
                    let trimmed = editing.wrappedValue.trimmingCharacters(in: .whitespaces)
                    draft.savedCommand = trimmed.isEmpty ? nil : trimmed
                    draft.editingCommand = nil
                }
            }
        } else {
            HStack(spacing: 6) {
                ValueBox(text: draft.savedCommand ?? draft.effectiveCommand, icon: "lock", mono: true, dim: draft.savedCommand == nil)
                BarlyButton(L("编辑"), variant: .outline, size: .sm) { draft.editingCommand = draft.savedCommand ?? "" }
                    .disabled(draft.target == .terminal || isRemote)
                    .help(isRemote ? "主机上用 CLI 的默认命令（按主机保存命令以后支持）" : "")
            }
        }
    }

    private func abbreviate(_ path: String) -> String {
        let home = NSHomeDirectory()
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    private func chooseFolder() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = L("选择")
        if panel.runModal() == .OK, let url = panel.url { draft.folder = abbreviate(url.path) }
        #endif
    }
}

/// 新会话的文件夹框：打开时系统把焦点给它并全选整条路径（一大片选中底色、一打字就整条没了），
/// 这里改成光标停在末尾
private struct FolderTextField: View {
    @Binding var text: String
    @State private var selection: TextSelection?
    @Environment(\.barly) private var t
    @Environment(\.barlySnapshot) private var snapshot

    var body: some View {
        if snapshot {
            BarlyBareField(placeholder: L("~/code/项目"), text: $text, style: .product.small.monospaced)
        } else {
            TextField("", text: $text, selection: $selection, prompt: Text(L("~/code/项目")).foregroundStyle(t.text3))
                .textFieldStyle(.plain)
                .barlyText(.product.small.monospaced, color: t.text)
                .tint(t.accent)
                .task {
                    // 系统全选发生在 sheet 出现之后：下一轮再把选区换成末尾的光标
                    try? await Task.sleep(for: .milliseconds(60))
                    selection = TextSelection(insertionPoint: text.endIndex)
                }
        }
    }
}

// MARK: - 关闭标签确认

public struct CloseTabDialog: View {
    let tabTitle: String
    let hostName: String
    var onEnd: (Bool) -> Void = { _ in }
    var onCancel: () -> Void = {}
    var onKeep: (Bool) -> Void = { _ in }
    @State private var remember = false
    /// 打开时焦点在「继续运行」：焦点默认落在第一个按钮（结束会话）的话，空格就会结束会话，还多一圈焦点环的颜色
    @FocusState private var keepFocused: Bool
    @Environment(\.barly) private var t

    /// onEnd / onKeep 的参数：是否勾了「不再询问」
    public init(tabTitle: String, hostName: String = L("这台 Mac"), onEnd: @escaping (Bool) -> Void = { _ in },
                onCancel: @escaping () -> Void = {}, onKeep: @escaping (Bool) -> Void = { _ in }) {
        self.tabTitle = tabTitle
        self.hostName = hostName
        self.onEnd = onEnd
        self.onCancel = onCancel
        self.onKeep = onKeep
    }

    public var body: some View {
        SheetFrame(title: L("关闭「\(tabTitle)」？"), width: 460) {
            VStack(alignment: .leading, spacing: 14) {
                Text("CLI 正在 tmux 里运行。让它继续跑的话，关掉标签、退出 Switchboard 都不影响；之后点这个会话就会重新接上。")
                    .barlyText(.product.small, color: t.text2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Checkbox(remember)
                    Text("在\(hostName)上不再询问，以后照这次的选择做").barlyText(.product.small, color: t.text2)
                }
                .contentShape(Rectangle())
                .tapButton { remember.toggle() }
                .handCursor()
            }
        } buttons: {
            BarlyButton(L("结束会话"), variant: .danger, size: .md) { onEnd(remember) }
            Spacer()
            BarlyButton(L("取消"), variant: .ghost, size: .md, action: onCancel)
                .keyboardShortcut(.cancelAction)
            BarlyButton(L("继续运行"), variant: .primary, size: .md) { onKeep(remember) }
                .keyboardShortcut(.defaultAction)
                .focused($keepFocused)
        }
        .defaultFocus($keepFocused, true)
    }
}
