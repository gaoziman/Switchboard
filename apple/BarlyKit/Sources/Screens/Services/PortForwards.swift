import Foundation

/// 端口转发：只在这台 Mac 的 localhost 上听（别的电脑连不进来），转到主机的 localhost。
/// 每个转发一个 `ssh -N -L` 进程，有 Connect… / 后台的共享连接就走它；断开主机、移除主机、退出 app 时全部停掉
public struct ListeningPort: Identifiable, Hashable, Sendable {
    public var id: Int { port }
    public let port: Int
    /// 是你自己的进程才有名字
    public let program: String?
}

public struct PortForward: Identifiable, Hashable, Sendable {
    public var id: String { "\(host):\(local)" }
    public let host: String
    public let local: Int
    public let remote: Int
    public var address: String { "http://localhost:\(local)" }
}

public enum PortForwarding {
    /// 主机上在 localhost 能连到的监听端口（ss，没有就 lsof）。去重、排序
    static let listScript = #"""
        if command -v ss >/dev/null 2>&1; then ss -Hltnp 2>/dev/null
        elif command -v lsof >/dev/null 2>&1; then lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | tail -n +2
        fi
        true
        """#

    public static func listPorts(_ alias: String) -> [ListeningPort]? {
        guard let r = SSH.run(["/usr/bin/ssh"] + SSH.options(alias) + [alias, listScript], timeout: 15), r.status == 0 else { return nil }
        return parse(r.stdout)
    }

    /// 认 ss（`LISTEN 0 511 127.0.0.1:3000 0.0.0.0:* users:(("node",pid=1,fd=20))`）和 lsof（`node 1 leo 20u IPv4 … TCP *:3000 (LISTEN)`）
    static func parse(_ out: String) -> [ListeningPort] {
        var byPort: [Int: String?] = [:]
        for line in out.split(separator: "\n") {
            let cols = line.split(whereSeparator: \.isWhitespace).map(String.init)
            var address: String?
            var program: String?
            if cols.first == "LISTEN", cols.count >= 4 {             // ss
                address = cols[3]
                if let u = line.range(of: #"users:\(\("([^"]+)""#, options: .regularExpression) {
                    program = String(line[u]).components(separatedBy: "\"").dropFirst().first
                }
            } else if let tcp = cols.firstIndex(of: "TCP"), tcp + 1 < cols.count {   // lsof
                address = cols[tcp + 1]
                program = cols.first
            }
            guard let address, let colon = address.lastIndex(of: ":"), let port = Int(address[address.index(after: colon)...]) else { continue }
            let hostPart = String(address[..<colon]).trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            // localhost 连得到的：127.0.0.1、::1、通配地址（127.0.0.53 这种别的回环地址转到 localhost 是连不上的）
            guard ["127.0.0.1", "0.0.0.0", "::", "*", "::1", "localhost"].contains(hostPart) else { continue }
            if byPort[port] == nil || byPort[port]! == nil { byPort[port] = program }
        }
        return byPort.map { ListeningPort(port: $0.key, program: $0.value) }.sorted { $0.port < $1.port }
    }
}

/// 管着正在跑的转发进程
@MainActor
public final class PortForwardManager {
    public static let shared = PortForwardManager()
    private var processes: [String: Process] = [:]
    public private(set) var forwards: [PortForward] = []

    /// 启动；nil = 成功，否则是 ssh 说的原因（本机端口被占、主机不让转发…）
    public func start(host: String, local: Int, remote: Int) async -> String? {
        let forward = PortForward(host: host, local: local, remote: remote)
        guard !forwards.contains(forward) else { return nil }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        p.arguments = ["-N", "-o", "ExitOnForwardFailure=yes", "-o", "BatchMode=yes", "-o", "ServerAliveInterval=15",
                       // 只当客户端：有共享连接就走它，没有就自己连；自己绝不当共享连接（停掉转发不能连累标签）
                       "-o", "ControlMaster=no", "-o", "ControlPath=\(SSH.controlPath)",
                       "-o", "ClearAllForwardings=no", "-L", "127.0.0.1:\(local):localhost:\(remote)", host]
        let err = Pipe()
        p.standardError = err
        p.standardOutput = FileHandle.nullDevice
        p.standardInput = FileHandle.nullDevice
        do { try p.run() } catch { return error.localizedDescription }
        // 2 秒内退出 = 没建起来
        for _ in 0..<20 where p.isRunning { try? await Task.sleep(for: .milliseconds(100)) }
        guard p.isRunning else {
            let msg = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            return msg.isEmpty ? L("ssh 退出码 \(p.terminationStatus)") : String(msg.suffix(300))
        }
        processes[forward.id] = p
        forwards.append(forward)
        return nil
    }

    public func stop(_ forward: PortForward) {
        processes[forward.id]?.terminate()
        processes[forward.id] = nil
        forwards.removeAll { $0 == forward }
    }

    public func stopAll(host: String? = nil) {
        for f in forwards where host == nil || f.host == host { stop(f) }
    }

    public func forwards(on host: String) -> [PortForward] { forwards.filter { $0.host == host } }
}
