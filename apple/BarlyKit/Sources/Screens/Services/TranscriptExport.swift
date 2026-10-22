import Foundation
#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

/// 把对话导成 Markdown：标题、来源、你的消息、回复、工具调用摘要（读整个文件，不受预览分页限制）
public enum TranscriptExport {
    public static func markdown(_ session: Session, project: Project?, entries: [TranscriptEntry]) -> String {
        var out = ["# \(session.displayTitle)", ""]
        var meta = [session.cli.title, project?.path ?? session.projectPath]
        if let model = session.model { meta.append(model) }
        meta.append(L("会话 \(session.id)"))
        out.append("> " + meta.joined(separator: " · "))
        out.append("")
        for e in entries {
            switch e.kind {
            case .user(let t): out += [L("## 你"), "", t, ""]
            case .assistant(let t): out += [t, ""]
            case .tools(let calls): out += [L("*\(calls.count) 次工具调用：\(ToolCall.summary(of: calls))*"), ""]
            case .code(let lang, let code): out += ["```\(lang)", code, "```", ""]
            case .image(let c): out += ["*［\(c)］*", ""]
            }
        }
        return out.joined(separator: "\n")
    }

    /// 纯文本：没有 Markdown 记号，给不认 Markdown 的地方贴（邮件、工单）
    public static func plainText(_ session: Session, project: Project?, entries: [TranscriptEntry]) -> String {
        var out = [session.displayTitle]
        var meta = [session.cli.title, project?.path ?? session.projectPath]
        if let model = session.model { meta.append(model) }
        meta.append(L("会话 \(session.id)"))
        out += [meta.joined(separator: " · "), ""]
        for e in entries {
            switch e.kind {
            case .user(let t): out += [L("你：") + t, ""]
            case .assistant(let t): out += [stripMarkdown(t), ""]
            case .tools(let calls): out += [L("（\(calls.count) 次工具调用：\(ToolCall.summary(of: calls))）"), ""]
            case .code(_, let code): out += [code, ""]
            case .image(let c): out += ["［\(c)］", ""]
            }
        }
        return out.joined(separator: "\n")
    }

    /// 去掉行首的 #、加粗 / 行内代码的记号（足够贴进纯文本的地方）
    static func stripMarkdown(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false).map { line in
            var l = String(line)
            while l.hasPrefix("#") { l.removeFirst() }
            if l.hasPrefix(" "), line.hasPrefix("#") { l.removeFirst() }
            return l.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "`", with: "")
        }.joined(separator: "\n")
    }

    public enum Format: CaseIterable, Sendable {
        case markdown, plainText, original
    }

    /// 先拷到目标旁边再换过去：拷失败（源文件没了、磁盘满）时目标位置原来的文件还在
    static func copyOriginal(from source: URL, to destination: URL) throws {
        let fm = FileManager.default
        let temp = destination.deletingLastPathComponent().appendingPathComponent(".\(destination.lastPathComponent).\(UUID().uuidString).tmp")
        try fm.copyItem(at: source, to: temp)
        do {
            if fm.fileExists(atPath: destination.path) {
                _ = try fm.replaceItemAt(destination, withItemAt: temp)
            } else {
                try fm.moveItem(at: temp, to: destination)
            }
        } catch {
            try? fm.removeItem(at: temp)
            throw error
        }
    }

    /// 读整个会话（最多 256 MB）
    static func fullEntries(_ session: Session) async -> [TranscriptEntry] {
        await Task.detached(priority: .userInitiated) { TranscriptLoader.load(session, maxBytes: 256 << 20) }.value
    }
}

@MainActor
public extension WorkspaceStore {
    func copyConversation(_ session: Session) async {
        let text = TranscriptExport.markdown(session, project: project(for: session), entries: await TranscriptExport.fullEntries(session))
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }

    /// 导出对话：Markdown / 纯文本 / CLI 自己的原始会话文件（OpenCode 在数据库里，没有单独文件）
    func exportConversation(_ session: Session, as format: TranscriptExport.Format = .markdown) async {
        #if os(macOS)
        let ext: String
        switch format {
        case .markdown: ext = "md"
        case .plainText: ext = "txt"
        case .original:
            guard let path = session.sourcePath, session.cli != .opencode else { return }
            ext = (path as NSString).pathExtension
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: ext) ?? .plainText]
        let safe = session.displayTitle.replacingOccurrences(of: "/", with: "-").prefix(60)
        panel.nameFieldStringValue = "\(safe).\(ext)"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            switch format {
            case .original:
                guard let path = session.sourcePath else { return }
                // 保存面板已经问过要不要覆盖
                try TranscriptExport.copyOriginal(from: URL(fileURLWithPath: path), to: url)
            case .markdown, .plainText:
                let entries = await TranscriptExport.fullEntries(session)
                let text = format == .markdown
                    ? TranscriptExport.markdown(session, project: project(for: session), entries: entries)
                    : TranscriptExport.plainText(session, project: project(for: session), entries: entries)
                try text.write(to: url, atomically: true, encoding: .utf8)
            }
        } catch {
            // 磁盘满、没权限、源文件被删了：别让人以为导出好了
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = L("没能导出「\(session.displayTitle)」")
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
        #endif
    }
}
