import Carbon
import KeyCodes
import Foundation

final class TypeCommandRunner {
  enum NaturalTyping: TimeInterval {
    case disabled = 0
    case slow = 0.0275
    case medium = 0.0175
    case fast = 0.01
  }

  private let keyboardCommandRunner: KeyboardCommandRunner
  private var naturalTyping: NaturalTyping = .fast

  internal init(_ keyboardCommandRunner: KeyboardCommandRunner) {
    self.keyboardCommandRunner = keyboardCommandRunner
  }

  func run(_ command: TypeCommand) async throws {
    let input = command.input
    let newLines = CharacterSet.newlines

    for character in input {
      let characterString = String(character)
      var flags = CGEventFlags()
      let keyCode: Int
      if let virtualKey = keyboardCommandRunner.virtualKey(for: characterString, matchDisplayValue: true) {
        keyCode = virtualKey.keyCode
      } else if let virtualKey = keyboardCommandRunner.virtualKey(for: characterString, modifiers: [.shift], matchDisplayValue: true) {
        keyCode = virtualKey.keyCode
        flags.insert(.maskShift)
      } else if let virtualKey = keyboardCommandRunner.virtualKey(for: characterString, modifiers: [.option], matchDisplayValue: true) {
        keyCode = virtualKey.keyCode
        flags.insert(.maskAlternate)
      } else if CharacterSet(charactersIn: characterString).isSubset(of: newLines) {
        keyCode = 36
      } else {
        continue
      }

      try keyboardCommandRunner.machPort?.post(keyCode, type: .keyDown, flags: flags)
    }
  }
}