// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ReelVault",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "ReelVaultCore", targets: ["ReelVaultCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.50.0")
    ],
    targets: [
        .target(
            name: "ReelVaultCore",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift")
            ],
            path: "ReelVaultCore"
        )
    ]
)
