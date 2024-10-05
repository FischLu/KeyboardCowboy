import Cocoa

private let rootFolder = URL(fileURLWithPath: #file).pathComponents
  .prefix(while: { $0 != "KeyboardCowboy" })
  .joined(separator: "/")
  .dropFirst()

struct AppPreferences {
  var hideAppOnLaunch: Bool = true
  var machportIsEnabled = true
  var configLocation: any ConfigurationLocatable

  private static func filename(for functionName: StaticString) -> String {
    "\(functionName)"
      .replacingOccurrences(of: "()", with: "")
      .appending(".json")
  }

  static func user() -> AppPreferences {
    AppPreferences(
      hideAppOnLaunch: true,
      machportIsEnabled: true,
      configLocation: ConfigurationLocation(path: "~/", filename: ".keyboard-cowboy.json"))
  }

  static func development() -> AppPreferences {
    AppPreferences(
      hideAppOnLaunch: false,
      machportIsEnabled: true,
      configLocation: ConfigurationLocation(path: "~/", filename: ".keyboard-cowboy.json"))
  }

  static func emptyFile() -> AppPreferences {
    AppPreferences(
      hideAppOnLaunch: false,
      machportIsEnabled: false,
      configLocation: ConfigurationLocation(path: rootFolder.appending("/KeyboardCowboy/Fixtures/json"),
                                                 filename: filename(for: #function)))
  }

  static func noConfiguration() -> AppPreferences {
    AppPreferences(
      hideAppOnLaunch: false,
      machportIsEnabled: false,
      configLocation: ConfigurationLocation(path: rootFolder.appending("//jsonKeyboardCowboy/Fixtures"),
                                                 filename: filename(for: #function)))
  }

  static func noGroups() -> AppPreferences {
    AppPreferences(
      hideAppOnLaunch: false,
      machportIsEnabled: false,
      configLocation: ConfigurationLocation(path: rootFolder.appending("/KeyboardCowboy/Fixtures/json"),
                                                 filename: filename(for: #function)))

  }

  static func designTime() -> AppPreferences {
    AppPreferences(
      hideAppOnLaunch: false,
      machportIsEnabled: true,
      configLocation: ConfigurationLocation(path: rootFolder.appending("/KeyboardCowboy/Fixtures/json"),
                                                 filename: filename(for: #function)))
  }

  static func performance() -> AppPreferences {
    AppPreferences(
      hideAppOnLaunch: false,
      machportIsEnabled: false,
      configLocation: ConfigurationLocation(path: rootFolder.appending("/KeyboardCowboy/Fixtures/json"),
                                                 filename: filename(for: #function)))

  }
}
