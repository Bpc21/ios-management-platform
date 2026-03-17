// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OpenClawManagementIOS",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .executable(
            name: "OpenClawManagementIOS",
            targets: ["OpenClawManagementIOS"]
        ),
    ],
    dependencies: [
        .package(path: "../shared/OpenClawKit")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "OpenClawManagementIOS",
            dependencies: [
                .product(name: "OpenClawKit", package: "OpenClawKit"),
                .product(name: "OpenClawProtocol", package: "OpenClawKit"),
                .product(name: "OpenClawChatUI", package: "OpenClawKit")
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
    ]
)
