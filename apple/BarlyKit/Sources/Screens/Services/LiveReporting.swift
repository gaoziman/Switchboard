import Foundation

/// OpenCode 和 omp 只会把「在哪个会话、在干什么」告诉跑在它们里面的代码。Switchboard 启动它们时带一个小扩展，
/// 扩展把状态写到 reports/<pid>.json：{"pid", "sessionId", "activity": "working" | "waiting" | "idle", "waitingFor"}。
/// 扩展脚本改自 JustSessions（MIT）的 OpenCodeLiveSessionPlugin / PiLiveSessionExtension，去掉了 SSH 主机的部分
public enum LiveReporting {
    static let reportsVariable = "SWITCHBOARD_LIVE_SESSION_REPORTS"

    static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Switchboard/LiveSessionReporting", isDirectory: true)
    }

    static var reportsDirectory: URL { directory.appendingPathComponent("reports", isDirectory: true) }

    /// 启动这个 CLI 时要加的参数和环境变量；nil = 这个 CLI 不需要 / 写不了扩展
    public static func launchAdditions(for cli: CLIKind) -> (arguments: [String], environment: [String: String])? {
        let env = [reportsVariable: reportsDirectory.path]
        switch cli {
        case .opencode:
            // 用户自己设了 OPENCODE_TUI_CONFIG 就不动它（那个 OpenCode 不报状态）
            guard ProcessInfo.processInfo.environment["OPENCODE_TUI_CONFIG"] == nil else { return nil }
            let plugin = directory.appendingPathComponent("opencode/switchboard-live-session.js")
            let config = directory.appendingPathComponent("opencode/tui.json")
            guard write(openCodePlugin, to: plugin),
                  let json = try? JSONSerialization.data(withJSONObject: ["plugin": [plugin.path]], options: [.prettyPrinted, .withoutEscapingSlashes]),
                  write(String(decoding: json, as: UTF8.self), to: config) else { return nil }
            return ([], env.merging(["OPENCODE_TUI_CONFIG": config.path]) { $1 })
        case .omp:
            let ext = directory.appendingPathComponent("omp/switchboard-live-session.js")
            guard write(ompExtension, to: ext) else { return nil }
            return (["-e", ext.path], env)
        case .claude, .codex:
            return nil
        }
    }

    /// 所有还活着的 CLI 报的状态：会话 ID → 状态
    public static func statuses() -> [String: Activity] {
        let dir = reportsDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { return [:] }
        var out: [String: Activity] = [:]
        for name in files where name.hasSuffix(".json") {
            guard let pid = Int32(name.dropLast(5)) else { continue }
            let file = dir.appendingPathComponent(name)
            // 被强制结束的 CLI 不会删自己的报告：进程不在了就清掉
            guard kill(pid, 0) == 0 || errno == EPERM else { try? FileManager.default.removeItem(at: file); continue }
            guard let data = try? Data(contentsOf: file), let r = JSONLines.object(data),
                  (r["pid"] as? NSNumber)?.int32Value == pid,
                  let id = r["sessionId"] as? String, let activity = activity(r["activity"] as? String) else { continue }
            out[id] = activity
        }
        return out
    }

    static func activity(_ name: String?) -> Activity? {
        switch name {
        case "working": .working
        case "waiting": .waitingForAnswer
        case "idle": .idle
        default: nil
        }
    }

    /// 内容变了才写，原子写，CLI 加载时不会读到半个文件
    private static func write(_ contents: String, to file: URL) -> Bool {
        let data = Data(contents.utf8)
        if (try? Data(contentsOf: file)) == data { return true }
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: file, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    // MARK: 扩展脚本

    /// OpenCode TUI 插件：插件 API 没有「换屏」事件，每半秒看一次当前会话；权限 / 提问在等你 = waiting，busy / retry = working
    static let openCodePlugin = #"""
        // Switchboard 启动 OpenCode 时带这个 TUI 插件（改自 JustSessions，MIT）。它告诉 Switchboard 这个 OpenCode
        // 在哪个会话、在干活 / 等你 / 跑完了。Switchboard 会在它变化时重写这个文件。
        import { mkdirSync, renameSync, rmSync, writeFileSync } from "node:fs";
        import { join } from "node:path";

        export default {
          id: "switchboard-live-session",
          tui: async (api) => {
            const directory = process.env.SWITCHBOARD_LIVE_SESSION_REPORTS;
            if (!directory) return;
            const reportFile = join(directory, `${process.pid}.json`);
            const reportsActivity = typeof api.event?.on === "function"
              && ["get", "status", "permission", "question"].every((name) => typeof api.state?.session?.[name] === "function");
            const askingSessionIds = new Set();
            let reportedJSON;

            const topLevelSessionId = (sessionId) => {
              let id = sessionId;
              for (let depth = 0; depth < 16; depth += 1) {
                const parentId = api.state.session.get(id)?.parentID;
                if (!parentId) return id;
                id = parentId;
              }
              return id;
            };

            const activity = (sessionId) => {
              for (const id of [sessionId, ...askingSessionIds]) {
                if (id !== sessionId && topLevelSessionId(id) !== sessionId) continue;
                if (api.state.session.permission(id).length > 0) return { activity: "waiting", waitingFor: "permission" };
                if (api.state.session.question(id).length > 0) return { activity: "waiting", waitingFor: "question" };
              }
              const status = api.state.session.status(sessionId)?.type;
              return { activity: status === "busy" || status === "retry" ? "working" : "idle" };
            };

            const report = () => {
              const route = api.route.current;
              const sessionId = route.name === "session" ? route.params?.sessionID ?? null : null;
              const sessionActivity = sessionId && reportsActivity ? activity(topLevelSessionId(sessionId)) : {};
              const json = JSON.stringify({ pid: process.pid, sessionId, ...sessionActivity });
              if (json === reportedJSON) return;
              try {
                mkdirSync(directory, { recursive: true });
                writeFileSync(`${reportFile}.partial`, json);
                renameSync(`${reportFile}.partial`, reportFile);
                reportedJSON = json;
              } catch {}
            };

            const unsubscribers = [];
            if (reportsActivity) {
              for (const askedEvent of ["permission.asked", "question.asked"]) {
                unsubscribers.push(api.event.on(askedEvent, (event) => {
                  askingSessionIds.add(event.properties.sessionID);
                  report();
                }));
              }
              for (const changeEvent of ["permission.replied", "question.replied", "question.rejected", "session.status"]) {
                unsubscribers.push(api.event.on(changeEvent, report));
              }
            }

            report();
            const timer = setInterval(report, 500);
            timer.unref?.();
            api.lifecycle.onDispose(() => {
              clearInterval(timer);
              for (const unsubscribe of unsubscribers) unsubscribe?.();
              try { rmSync(reportFile, { force: true }); } catch {}
            });
          },
        };

        """#

    /// omp 扩展（Pi 的分支）：session_start / session_switch 记会话；agent_start → working，
    /// agent_settled 或 agent_end 且已空闲 → idle；扩展弹出的提示（权限门之类）→ waiting
    static let ompExtension = #"""
        // Switchboard 启动 omp 时带这个扩展（改自 JustSessions 的 Pi 扩展，MIT）。它告诉 Switchboard 这个 omp
        // 在哪个会话、在干活 / 等你 / 跑完了。Switchboard 会在它变化时重写这个文件。
        import { mkdirSync, renameSync, rmSync, writeFileSync } from "node:fs";
        import { join } from "node:path";

        export default function (pi) {
          const directory = process.env.SWITCHBOARD_LIVE_SESSION_REPORTS;
          if (!directory) return;
          const reportFile = join(directory, `${process.pid}.json`);
          let session;
          let isRunning = false;
          const openPrompts = [];

          const write = () => {
            if (!session) return;
            const waitingPrompt = isRunning ? openPrompts.at(-1) : undefined;
            const report = { pid: process.pid, ...session, activity: waitingPrompt ? "waiting" : isRunning ? "working" : "idle" };
            if (waitingPrompt?.title) report.waitingFor = waitingPrompt.title;
            try {
              mkdirSync(directory, { recursive: true });
              writeFileSync(`${reportFile}.partial`, JSON.stringify(report));
              renameSync(`${reportFile}.partial`, reportFile);
            } catch {}
          };

          const remember = (ctx) => {
            const manager = ctx?.sessionManager;
            const sessionId = typeof manager?.getSessionId === "function" ? manager.getSessionId() : undefined;
            if (!sessionId) return;
            session = { sessionId, sessionFile: typeof manager.getSessionFile === "function" ? manager.getSessionFile() ?? null : null };
            isRunning = typeof ctx.isIdle === "function" ? !ctx.isIdle() : false;
            openPrompts.length = 0;
            write();
          };

          pi.on("session_start", (_event, ctx) => remember(ctx));
          pi.on("session_switch", (_event, ctx) => remember(ctx));
          pi.on("agent_start", () => { isRunning = true; write(); });
          pi.on("agent_settled", () => { isRunning = false; openPrompts.length = 0; write(); });
          pi.on("agent_end", (event, ctx) => {
            if (event?.willContinue) return;
            if (ctx && typeof ctx.isIdle === "function" && !ctx.isIdle()) return;
            isRunning = false;
            openPrompts.length = 0;
            write();
          });
          pi.on("ui_prompt_start", (event) => { openPrompts.push({ kind: event.kind, title: event.title }); write(); });
          pi.on("ui_prompt_end", (event) => {
            const index = openPrompts.findLastIndex((p) => p.kind === event.kind && p.title === event.title);
            openPrompts.splice(index >= 0 ? index : openPrompts.length - 1, 1);
            write();
          });
          pi.on("session_shutdown", () => {
            try { rmSync(reportFile, { force: true }); } catch {}
          });
        }

        """#
}
