import ProjectDescription

let dependencies = Dependencies(
    swiftPackageManager: [
      .remote(url: "https://github.com/krzysztofzablocki/Inject.git", requirement: .exact("1.1.0")),
      .remote(url: "https://github.com/sparkle-project/Sparkle.git", requirement: .exact("2.4.1")),
      .remote(url: "https://github.com/zenangst/AXEssibility.git", requirement: .exact("0.0.7")),
      .remote(url: "https://github.com/zenangst/Apps.git", requirement: .exact("1.4.0")),
      .remote(url: "https://github.com/zenangst/Dock.git", requirement: .exact("1.0.1")),
      .remote(url: "https://github.com/zenangst/InputSources.git", requirement: .exact("1.0.1")),
      .remote(url: "https://github.com/zenangst/KeyCodes.git", requirement: .exact("4.0.5")),
      .remote(url: "https://github.com/zenangst/LaunchArguments.git", requirement: .exact("1.0.1")),
      .remote(url: "https://github.com/zenangst/MachPort.git", requirement: .exact("3.0.1")),
      .remote(url: "https://github.com/zenangst/Windows.git", requirement: .exact("1.0.0")),
      .remote(url: "https://github.com/zenangst/ZenViewKit.git", requirement: .revision("7db6e2a11bdb802f5a078fcb9f2717c19440841c")),
    ],
    platforms: [.macOS]
)
