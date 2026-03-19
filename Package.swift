// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CCFDDLMenuBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "CCFDDLMenuBar", targets: ["CCFDDLMenuBar"])
    ],
    targets: [
        .executableTarget(
            name: "CCFDDLMenuBar",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("JavaScriptCore"),
                .linkedFramework("UserNotifications")
            ]
        )
    ]
)
