// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ConfBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ConfBar", targets: ["ConfBar"])
    ],
    targets: [
        .executableTarget(
            name: "ConfBar",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("JavaScriptCore"),
                .linkedFramework("UserNotifications")
            ]
        )
    ]
)
