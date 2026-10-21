// swift-tools-version:5.9
// BarlyKit — Barly 风格的 SwiftUI 组件包（iOS 17 / macOS 14 共用）
// Sources/BarlyKit/Generated/Theme.generated.swift 由 identity.mjs 生成，new-apple.sh sync 负责拷进来。
import PackageDescription

let package = Package(
    name: "BarlyKit",
    platforms: [.iOS(.v17), .macOS("26.0")],
    products: [
        .library(name: "BarlyKit", targets: ["BarlyKit"]),
        .library(name: "BarlyExamples", targets: ["BarlyExamples"]),
        // 产品自己的屏幕：写在 Sources/Screens/，在 ProductScreens.all 登记，barly-snap 会先截它们
        .library(name: "Screens", targets: ["Screens"]),
        .executable(name: "barly-snap", targets: ["barly-snap"]),
    ],
    dependencies: [
        // 内嵌终端（MIT）。1.20.0 和 JustSessions 的基线一致
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", exact: "1.20.0"),
    ],
    targets: [
        .target(
            name: "BarlyKit",
            resources: [.copy("Resources/Fonts"), .copy("Resources/Brand"), .copy("Resources/Photos")]
        ),
        .target(name: "BarlyExamples", dependencies: ["BarlyKit"]),
        .target(name: "Screens", dependencies: ["BarlyKit", "BarlyExamples",
                                               .product(name: "SwiftTerm", package: "SwiftTerm", condition: .when(platforms: [.macOS]))]),
        .executableTarget(name: "barly-snap", dependencies: ["BarlyKit", "BarlyExamples", "Screens"]),
        .testTarget(name: "ScreensTests", dependencies: ["Screens"]),
    ]
)
