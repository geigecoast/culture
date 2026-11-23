// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "CultureKit",
    defaultLocalization: "fr",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "CultureCore", targets: ["CultureCore"])
    ],
    targets: [
        // Pure domain logic: models, SRS, streaks, event time zones, feed ranking, validation.
        // Depends only on Foundation so it can be unit-tested quickly with `swift test`.
        .target(name: "CultureCore"),
        .testTarget(name: "CultureCoreTests", dependencies: ["CultureCore"])
    ]
)
