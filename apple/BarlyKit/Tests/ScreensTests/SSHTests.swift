import Foundation
import Testing
@testable import Screens

@Suite("SSH")
struct SSHTests {
    @Test func normalize() {
        #expect(SSH.normalize("  ssh devbox ") == "devbox")
        #expect(SSH.normalize("leo@10.0.0.2") == "leo@10.0.0.2")
    }

    @Test("ssh -G 解析（不连接）")
    func resolve() {
        let t = SSH.resolve("leo@example.invalid")
        #expect(t?.user == "leo")
        #expect(t?.hostname == "example.invalid")
        #expect(t?.port == "22")
    }

    @Test("远程启动：进目录、用主机 tmux、命令里的引号和空格都转义")
    func launch() {
        let (exe, args) = SSH.launch(alias: "devbox", directory: "/home/leo/my project",
                                     command: ["claude", "--resume", "abc", "--append", "it's"], tmuxName: "claude-abc")
        #expect(exe == "/usr/bin/ssh")
        #expect(args.prefix(2) == ["-t", "-o"])
        #expect(args.contains("devbox"))
        let remote = args.last!
        #expect(remote.hasPrefix("SWITCHBOARD=1 exec"))
        // 用 sh 解开一层引号，看主机上的 shell 实际收到什么
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", "printf '%s' " + remote.replacingOccurrences(of: "SWITCHBOARD=1 exec \"${SHELL:-/bin/sh}\" -lc ", with: "")]
        let pipe = Pipe(); p.standardOutput = pipe
        try? p.run(); p.waitUntilExit()
        let inner = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        #expect(inner.hasPrefix("cd '/home/leo/my project' && if command -v tmux"))
        #expect(inner.contains("tmux new-session -A -s claude-abc"))
        #expect(inner.contains(#"'it'\''s'"#))
    }

    @Test("没有 tmux 名字 = 普通登录 shell")
    func shell() {
        let (_, args) = SSH.launch(alias: "h", directory: "/srv", command: [], tmuxName: nil)
        #expect(args.last!.contains("cd /srv"))
    }
}

@Suite("SSH 主机上的会话")
struct RemoteSessionTests {
    @Test("主机目录：~ 由主机展开，其余加引号")
    func remoteDir() {
        #expect(SSH.remoteDirectory("~/my app") == #""$HOME"/'my app'"#)
        #expect(SSH.remoteDirectory("~") == #""$HOME""#)
        #expect(SSH.remoteDirectory("/srv/x") == "/srv/x")
    }

    @Test("删除只认镜像里 .claude/projects/项目/会话.jsonl，拒绝 ..")
    func deletePath() {
        let root = SSH.cacheDirectory("devbox").appendingPathComponent("claude/projects").path
        func s(_ path: String) -> Session {
            Session(id: "x", cli: .claude, hostID: "devbox", projectPath: "/srv", title: "", lastActivity: .now, messageCount: 0, sourcePath: path)
        }
        #expect(RemoteSessions.remoteRelativePath(s(root + "/-srv/abc.jsonl")) == ".claude/projects/-srv/abc.jsonl")
        #expect(RemoteSessions.remoteRelativePath(s(root + "/../../etc/abc.jsonl")) == nil)
        #expect(RemoteSessions.remoteRelativePath(s(root + "/-srv/sub/abc.jsonl")) == nil)
        #expect(RemoteSessions.remoteRelativePath(s("/tmp/abc.jsonl")) == nil)
    }

    @Test("解析主机状态：claude 进程状态 + tmux 会话")
    func parseStatus() {
        let out = """
        @claude {"pid":123,"sessionId":"aaa","status":"busy"}
        @claude {"pid":124,"sessionId":"bbb","status":"waiting"}
        @tmux claude-aaa
        @tmux my-own-session
        """
        let snap = RemoteSessions.parse(out)
        #expect(snap.claude == ["aaa": .working, "bbb": .waitingForAnswer])
        #expect(snap.tmux == ["claude-aaa", "my-own-session"])
    }

    @Test("远程启动：主机 tmux 透传标题")
    func titles() {
        let (_, args) = SSH.launch(alias: "h", directory: "~/p", command: ["codex"], tmuxName: "codex-x")
        #expect(args.last!.contains("set-titles on"))
        #expect(args.contains("ControlPath=\(SSH.controlPath)"))
    }
}

@Suite struct PortForwardTests {
    @Test func parsesSS() {
        let out = """
            LISTEN 0 511 127.0.0.1:3000 0.0.0.0:* users:(("node",pid=812,fd=20))
            LISTEN 0 128 0.0.0.0:22 0.0.0.0:*
            LISTEN 0 511 [::]:3000 [::]:* users:(("node",pid=812,fd=21))
            LISTEN 0 4096 10.0.0.5:9000 0.0.0.0:* users:(("app",pid=1,fd=3))
            LISTEN 0 4096 127.0.0.53%lo:53 0.0.0.0:*
            """
        let ports = PortForwarding.parse(out)
        #expect(ports.map(\.port) == [22, 3000])
        #expect(ports.first { $0.port == 3000 }?.program == "node")
        #expect(ports.first { $0.port == 22 }?.program == nil)
    }

    @Test func parsesLsof() {
        let out = """
            node    4242 leo   20u  IPv4 0x1      0t0  TCP 127.0.0.1:5173 (LISTEN)
            python3 4300 leo    3u  IPv6 0x2      0t0  TCP *:8000 (LISTEN)
            """
        let ports = PortForwarding.parse(out)
        #expect(ports == [ListeningPort(port: 5173, program: "node"), ListeningPort(port: 8000, program: "python3")])
    }

    @Test func emptyOutput() {
        #expect(PortForwarding.parse("").isEmpty)
    }
}

@Suite struct SignInConfigTests {
    @Test func roundTrips() throws {
        let c = SignInConfig(command: "kinit", check: "klist -s", hours: 8, lastSignIn: Date(timeIntervalSince1970: 1000))
        let back = try JSONDecoder().decode(SignInConfig.self, from: JSONEncoder().encode(c))
        #expect(back == c)
    }

    @Test("tmux 按名字精确匹配（不然 codex-* 会匹配到别的会话）；= 开头的词要加引号（zsh 会展开）")
    func tmuxExactTarget() {
        #expect(Tmux.target("codex-*") == "=codex-*")
        #expect(Tmux.shellQuote("=claude-abc") == "'=claude-abc'")
        #expect(Tmux.shellQuote("a=b") == "a=b")
        #expect(SSH.killTmuxCommand("codex-*") == "tmux kill-session -t '=codex-*'")
        #expect(SSH.killTmuxCommand("claude-abc") == "tmux kill-session -t '=claude-abc'")
    }

    @Test("复用连接的套接字放在只有自己能进的目录里（/tmp 下别人能抢先占名字）；ssh 建临时套接字时还要加 17 字节，也不能超 104")
    func controlPathIsPrivate() throws {
        let dir = (SSH.controlPath as NSString).deletingLastPathComponent
        #expect(dir != "/tmp")
        #expect(SSH.isPrivateDirectory(dir))
        let expanded = SSH.controlPath.replacingOccurrences(of: "%C", with: String(repeating: "f", count: 40))
        #expect(expanded.utf8.count + 17 < 104)
    }

    @Test("别人的、权限开着的、符号链接都不算私有目录")
    func privateDirectoryCheck() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("sb-priv-\(UUID())")
        defer { try? FileManager.default.removeItem(at: base) }
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let mine = base.appendingPathComponent("mine").path
        #expect(SSH.isPrivateDirectory(mine))                                     // 没有就建一个 0700 的
        let open = base.appendingPathComponent("open").path
        try FileManager.default.createDirectory(atPath: open, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o777])
        chmod(open, 0o777)
        #expect(!SSH.isPrivateDirectory(open))
        let link = base.appendingPathComponent("link").path
        try FileManager.default.createSymbolicLink(atPath: link, withDestinationPath: mine)
        #expect(!SSH.isPrivateDirectory(link))
    }

    @Test("主机家目录：只认标记行，rc 文件的输出不算")
    func parseHome() {
        #expect(SSH.parseHome("Welcome!\n__SB_HOME__/home/leo\n") == "/home/leo")
        #expect(SSH.parseHome("__SB_HOME__/Users/leo") == "/Users/leo")
        #expect(SSH.parseHome("__SB_HOME__\n") == nil)          // $HOME 是空的
        #expect(SSH.parseHome("__SB_HOME__relative") == nil)    // 不是绝对路径
        #expect(SSH.parseHome("/home/leo\n") == nil)
    }

    @Test("主机上的 ~ 展开成它自己的家目录")
    func expandingHome() {
        #expect(SSH.expandingHome("~/proj", home: "/home/leo") == "/home/leo/proj")
        #expect(SSH.expandingHome("~", home: "/home/leo") == "/home/leo")
        #expect(SSH.expandingHome("~/proj/", home: "/home/leo/") == "/home/leo/proj")
        #expect(SSH.expandingHome("/srv/app", home: "/home/leo") == "/srv/app")
        #expect(SSH.expandingHome("~other/x", home: "/home/leo") == "~other/x")   // 别人的家目录不猜
        #expect(SSH.needsHome("~/proj") && SSH.needsHome("~") && !SSH.needsHome("/srv") && !SSH.needsHome("~other"))
    }
}
