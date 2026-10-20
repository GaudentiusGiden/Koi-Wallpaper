// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KoiWallpaper",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "KoiWallpaper",
            targets: ["KoiWallpaper"]
        ),
        .executable(
            name: "KoiWallpaperVerify",
            targets: ["KoiWallpaperVerify"]
        ),
        .executable(
            name: "KoiWallpaperPreview",
            targets: ["KoiWallpaperPreview"]
        ),
        .executable(
            name: "KoiWallpaperSimTest",
            targets: ["KoiWallpaperSimTest"]
        ),
        .library(
            name: "KoiWallpaperCore",
            targets: ["KoiWallpaperCore"]
        )
    ],
    targets: [
        .target(
            name: "KoiWallpaperCore",
            path: "Sources/KoiWallpaperCore"
        ),
        .executableTarget(
            name: "KoiWallpaper",
            dependencies: ["KoiWallpaperCore"],
            path: "Sources/KoiWallpaper"
        ),
        .executableTarget(
            name: "KoiWallpaperVerify",
            dependencies: ["KoiWallpaperCore"],
            path: "Sources/KoiWallpaperVerify"
        ),
        .executableTarget(
            name: "KoiWallpaperPreview",
            dependencies: ["KoiWallpaperCore"],
            path: "Sources/KoiWallpaperPreview"
        ),
        .executableTarget(
            name: "KoiWallpaperSimTest",
            dependencies: ["KoiWallpaperCore"],
            path: "Sources/KoiWallpaperSimTest"
        )
    ]
)
