// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "audioset45",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        // Домен + приложение (чистое ядро, без зависимостей от фреймворков).
        .target(name: "AudioSetCore"),
        // Driven-адаптеры: CoreAudio и JSON-хранилище.
        .target(name: "AudioSetInfrastructure", dependencies: ["AudioSetCore"]),
        // Driving-адаптер (меню-бар) + composition root.
        .executableTarget(
            name: "AudioSet",
            dependencies: ["AudioSetCore", "AudioSetInfrastructure"]),
        .testTarget(
            name: "AudioSetTests",
            dependencies: ["AudioSetCore", "AudioSetInfrastructure"]),
    ]
)
