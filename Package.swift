// swift-tools-version: 5.9
import PackageDescription
import Foundation

// The linker resolves -sectcreate paths relative to its own working directory,
// which is not the package root — a relative path silently embeds an empty
// section. Anchor it to this manifest's location instead.
let plistPath = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("Resources/Info.plist")
    .path

let package = Package(
    name: "DeskArt",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "DeskArt",
            path: "Sources/DeskArt",
            linkerSettings: [
                // Embed Info.plist directly into the executable so the Apple Events
                // usage description is present for the TCC prompt. Required because
                // this is a SwiftPM binary, not an Xcode-produced .app bundle.
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", plistPath,
                ])
            ]
        )
    ]
)
