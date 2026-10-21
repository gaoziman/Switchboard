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
            case .tools(let n, let s): out += [L("*\(n) 次工具调用：\(s)*"), ""]
            case .code(let lang, let code): out += ["```\(lang)", code, "```", ""]
            case .image(let c): out += ["*［\(c)］*", ""]
            }
        }
        return out.joined(separator: "\n")
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

    func exportConversation(_ session: Session) async {
        #if os(macOS)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        let safe = session.displayTitle.replacingOccurrences(of: "/", with: "-").prefix(60)
        panel.nameFieldStringValue = "\(safe).md"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let text = TranscriptExport.markdown(session, project: project(for: session), entries: await TranscriptExport.fullEntries(session))
        try? text.write(to: url, atomically: true, encoding: .utf8)
        #endif
    }
}
