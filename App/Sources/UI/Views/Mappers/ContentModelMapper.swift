import Bonzai
import Foundation

final class ContentModelMapper {
  func map(_ workflow: Workflow, groupId: String) -> ContentViewModel {
    workflow.asViewModel(nil, groupId: groupId)
  }
}

private extension Array where Element == Workflow {
  func asViewModels(_ groupName: String?, groupId: String) -> [ContentViewModel] {
    var viewModels = [ContentViewModel]()
    viewModels.reserveCapacity(self.count)
    for (offset, model) in self.enumerated() {
      viewModels.append(model.asViewModel(offset == 0 ? groupName : nil, groupId: groupId))
    }
    return viewModels
  }
}

private extension Array where Element == KeyShortcut {
  var binding: String? {
    if count == 1, let firstMatch = first {
      let key: String = firstMatch.key.count == 1
      ? firstMatch.key.uppercaseFirstLetter()
      : firstMatch.key
      return "\(firstMatch.modifersDisplayValue)\(key)"
    } else if count > 1 {
      return compactMap {
        let key: String = $0.key.count == 1 ? $0.key.uppercaseFirstLetter() : $0.key
        return $0.modifersDisplayValue + key
      }.joined(separator: ",")
    }
    return nil
  }
}

private extension String {
    func uppercaseFirstLetter() -> String {
        guard let firstCharacter = self.first else {
            return self
        }
        let uppercaseFirstCharacter = String(firstCharacter).uppercased()
        let remainingString = String(self.dropFirst())
        return uppercaseFirstCharacter + remainingString
    }
}

private extension Workflow {
  func asViewModel(_ groupName: String?, groupId: String) -> ContentViewModel {
    let commandCount = commands.count
    let viewModelTrigger: ContentViewModel.Trigger?
    viewModelTrigger = switch trigger {
    case .application: .application("foo")
    case .keyboardShortcuts(let trigger): .keyboard(trigger.shortcuts.binding ?? "")
    case .snippet(let snippetTrigger): .snippet(snippetTrigger.text)
    case .none: nil
    }

    let execution: ContentViewModel.Execution = switch execution {
    case .concurrent: .concurrent
    case .serial: .serial
    }

    return ContentViewModel(
      id: id,
      groupId: groupId,
      groupName: groupName,
      name: name,
      images: commands.images(limit: 1),
      overlayImages: commands.overlayImages(limit: 3),
      trigger: viewModelTrigger,
      execution: execution,
      badge: commandCount > 1 ? commandCount : 0,
      badgeOpacity: commandCount > 1 ? 1.0 : 0.0,
      isEnabled: isEnabled)
  }
}

private extension Workflow.Trigger {
  var binding: String? {
    switch self {
    case .keyboardShortcuts(let trigger):
      return trigger.shortcuts.binding
    case .application, .snippet:
      return nil
    }
  }
}

private extension Array where Element == Command {
  func overlayImages(limit: Int) -> [ContentViewModel.ImageModel] {
    var images = [ContentViewModel.ImageModel]()

    for (offset, element) in self.enumerated() where element.isEnabled {
      if offset == limit { break }
      let convertedOffset = Double(offset)

      switch element {
      case .open(let command):
        if let application = command.application {
          images.append(ContentViewModel.ImageModel(
            id: command.id,
            offset: convertedOffset,
            kind: .icon(.init(bundleIdentifier: application.bundleIdentifier,
                              path: application.path))))
        }
      default:
        continue
      }
    }

    return images
  }

  func images(limit: Int) -> [ContentViewModel.ImageModel] {
    var images = [ContentViewModel.ImageModel]()
    var offset: Int = 0
    for element in self.reversed() where element.isEnabled {
      // Don't render icons for commands that are not enabled.
      if !element.isEnabled { continue }

      if offset == limit { break }

      let convertedOffset = Double(offset)
      switch element {
      case .application(let command):
        images.append(
          ContentViewModel.ImageModel(
            id: command.id,
            offset: convertedOffset,
            kind: .icon(.init(bundleIdentifier: command.application.bundleIdentifier,
                              path: command.application.path)))
        )
      case .menuBar:              images.append(.menubar(element, offset: convertedOffset))
      case .builtIn(let command): images.append(.builtIn(element, kind: command.kind, offset: convertedOffset))
      case .bundled(let command):
        switch command.kind {
        case .appFocus: images.append(.bundled(element, offset: convertedOffset, kind: .appFocus))
        case .workspace: images.append(.bundled(element, offset: convertedOffset, kind: .workspace))
        }
      case .mouse:
        images.append(.mouse(element, offset: convertedOffset))
      case .keyboard(let keyCommand):
        if let keyboardShortcut = keyCommand.keyboardShortcuts.first {
          images.append(.keyboard(element, string: keyboardShortcut.key, offset: convertedOffset))
        }
      case .open(let command):
        let path: String
        if command.isUrl {
          path = "/System/Library/SyncServices/Schemas/Bookmarks.syncschema/Contents/Resources/com.apple.Bookmarks.icns"
        } else {
          path = command.path
        }

        images.append(
          ContentViewModel.ImageModel(
            id: command.id,
            offset: convertedOffset,
            kind: .icon(.init(bundleIdentifier: path, path: path)))
        )
      case .script(let command): images.append(.script(element, source: command.source, offset: convertedOffset))
      case .shortcut:            images.append(.shortcut(element, offset: convertedOffset))
      case .text(let model):
        switch model.kind {
        case .insertText: images.append(.text(element, kind: .insertText, offset: convertedOffset))
        }
      case .systemCommand(let command): images.append(.systemCommand(element, kind: command.kind, offset: convertedOffset))
      case .uiElement:                  images.append(.uiElement(element, offset: convertedOffset))
      case .windowManagement:           images.append(.windowManagement(element, offset: convertedOffset))
      }
      offset += 1
    }

    return images.reversed()
  }
}
