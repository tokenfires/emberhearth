// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "EmberHearth",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "EmberHearth",
            targets: ["EmberHearth"]
        )
    ],
    targets: [
        .executableTarget(
            name: "EmberHearth",
            path: "src",
            exclude: [
                "EmberHearth.entitlements",
                "Info.plist"
            ],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]
        ),
        .testTarget(
            name: "EmberHearthTests",
            dependencies: ["EmberHearth"],
            path: "tests"
        )
    ]
)
