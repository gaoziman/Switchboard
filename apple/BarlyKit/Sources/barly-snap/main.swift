// barly-snap：把所有示例屏 × 明暗渲染成 PNG
// 用法：swift run barly-snap --out <目录> [--identity <工程目录>] [--only ios-home,mac-dashboard] [--mode light|dark|both]
//       [--prefix A-] [--method renderer|hosting] [--list]
//       [--shell sidebar|sidebar-gray|rail|rail-list|topnav] [--inspector on|off] [--mobile-home greeting-bottom|hub|orb-center]
//       骨架参数在运行时覆盖身份里的 layout（不用重编译），一次编译就能截全部骨架
// iOS 屏 393×852 @3x，macOS 屏 1440×1024 @2x。Theme.generated.swift 是编译期的——换身份先跑 new-apple.sh sync。
#if os(macOS)
import AppKit
import SwiftUI
import BarlyKit
import BarlyExamples
import Screens

struct Options {
    var out = "./_shots"
    var identity: String?
    var only: Set<String> = []
    var modes: [ColorScheme] = [.light, .dark]
    var prefix = ""
    var method = "renderer"
    var list = false
    var productOnly = false
    var shell: String?
    var inspector: Bool?
    var mobileHome: String?
}

func parse() -> Options {
    var o = Options()
    var it = CommandLine.arguments.dropFirst().makeIterator()
    while let a = it.next() {
        switch a {
        case "--out": o.out = it.next() ?? o.out
        case "--identity": o.identity = it.next()
        case "--only": o.only = Set((it.next() ?? "").split(separator: ",").map(String.init))
        case "--mode":
            switch it.next() ?? "both" {
            case "light": o.modes = [.light]
            case "dark": o.modes = [.dark]
            default: o.modes = [.light, .dark]
            }
        case "--prefix": o.prefix = it.next() ?? ""
        case "--method": o.method = it.next() ?? "renderer"
        case "--list": o.list = true
        case "--product-only": o.productOnly = true
        case "--shell": o.shell = it.next()
        case "--inspector": o.inspector = (it.next() ?? "on") == "on"
        case "--mobile-home": o.mobileHome = it.next()
        case "-h", "--help":
            print("barly-snap --out <dir> [--identity <proj>] [--only id,id] [--mode light|dark|both] [--prefix X-] [--method renderer|hosting] [--list] [--product-only] [--shell s] [--inspector on|off] [--mobile-home m]")
            exit(0)
        default: FileHandle.standardError.write("未知参数 \(a)\n".data(using: .utf8)!)
        }
    }
    return o
}

nonisolated(unsafe) var layoutOpts = Options()

@MainActor
func framed(_ s: ExampleScreen, _ scheme: ColorScheme) -> some View {
    s.make()
        .environment(\.barlyShellOverride, layoutOpts.shell)
        .environment(\.barlyInspectorOverride, layoutOpts.inspector)
        .environment(\.barlyMobileHomeOverride, layoutOpts.mobileHome)
        .frame(width: s.size.width, height: s.size.height)
        .environment(\.colorScheme, scheme)
        .environment(\.barlySnapshot, true)
        .environment(\.barlyTitlebarInset, 0)
        .background(scheme == .dark ? BarlyTokens.dark.bg : BarlyTokens.light.bg)
}

@MainActor
func renderWithImageRenderer(_ s: ExampleScreen, _ scheme: ColorScheme) -> Data? {
    let r = ImageRenderer(content: framed(s, scheme))
    r.scale = s.scale
    r.proposedSize = ProposedViewSize(s.size)
    guard let cg = r.cgImage else { return nil }
    return NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])
}

@MainActor
func renderWithHostingView(_ s: ExampleScreen, _ scheme: ColorScheme) -> Data? {
    let host = NSHostingView(rootView: framed(s, scheme))
    host.frame = CGRect(origin: .zero, size: s.size)
    let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
    window.contentView = host
    window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
    host.layoutSubtreeIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.15))
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(s.size.width * s.scale), pixelsHigh: Int(s.size.height * s.scale),
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
    rep.size = s.size
    host.cacheDisplay(in: host.bounds, to: rep)
    return rep.representation(using: .png, properties: [:])
}

@MainActor
func run() {
    let o = parse()
    layoutOpts = o
    BarlyFonts.register()
    // 产品屏（Sources/Screens/ProductScreens.swift）在前；同 id 时产品屏覆盖示例屏
    let product = ProductScreens.all
    // 没给 --only 时只截通用示例屏 + 本风格族的示例屏（ios-f-<族> / mac-f-<族>）
    let examples = o.only.isEmpty ? ExampleCatalog.forIdentity : ExampleCatalog.all
    let screens = product + (o.productOnly ? [] : examples.filter { e in !product.contains { $0.id == e.id } })
    for s in product where !(s.id.hasPrefix("ios-") || s.id.hasPrefix("mac-")) {
        FileHandle.standardError.write("! 产品屏 id「\(s.id)」没有 ios- / mac- 前缀，present.mjs 会按宽高比猜类型\n".data(using: .utf8)!)
    }
    if o.list {
        for s in screens { print("\(s.id)\t\(s.platform.rawValue)\t\(product.contains { $0.id == s.id } ? "产品" : "示例")\t\(s.title)") }
        return
    }
    if let dir = o.identity {
        let url = URL(fileURLWithPath: dir).appendingPathComponent("design/identity.json")
        if let d = try? Data(contentsOf: url), let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any], let name = j["name"] as? String {
            if name != BarlyTokens.name {
                FileHandle.standardError.write("✗ 编译进来的身份是 \(BarlyTokens.name)，--identity 指向 \(name)。先跑：bash scripts/new-apple.sh sync \(dir)\n".data(using: .utf8)!)
                exit(2)
            }
        } else {
            FileHandle.standardError.write("✗ 读不到 \(url.path)\n".data(using: .utf8)!)
            exit(2)
        }
    }
    try? FileManager.default.createDirectory(atPath: o.out, withIntermediateDirectories: true)
    print("身份 \(BarlyTokens.name) · 风格族 \(BarlyTokens.family) · 骨架 \(o.shell ?? BarlyTokens.Layout.shell)\((o.inspector ?? BarlyTokens.Layout.inspector) ? "+inspector" : "") / \(o.mobileHome ?? BarlyTokens.Layout.mobileHome) · 字体 \(BarlyFonts.families.joined(separator: ", "))")
    var n = 0
    if o.productOnly && product.isEmpty { print("! ProductScreens.all 是空的：先在 Sources/Screens/ProductScreens.swift 登记产品屏") }
    for s in screens where o.only.isEmpty || o.only.contains(s.id) {
        for m in o.modes {
            let data = o.method == "hosting" ? renderWithHostingView(s, m) : renderWithImageRenderer(s, m)
            let path = "\(o.out)/\(o.prefix)\(s.id)-\(m == .dark ? "dark" : "light").png"
            if let data, (try? data.write(to: URL(fileURLWithPath: path))) != nil {
                print("✓ \(path)"); n += 1
            } else {
                print("✗ \(path) 渲染失败")
            }
        }
    }
    print("共 \(n) 张")
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
MainActor.assumeIsolated { run() }
#else
print("barly-snap 只在 macOS 上运行")
#endif
