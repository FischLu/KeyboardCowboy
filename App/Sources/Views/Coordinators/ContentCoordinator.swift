import Combine
import SwiftUI

final class ContentCoordinator {
  private let store: GroupStore
  let applicationStore: ApplicationStore
  let publisher: ContentPublisher = ContentPublisher()

  private var updateTask: Task<(), Error>?

  init(_ store: GroupStore, applicationStore: ApplicationStore) {
    self.applicationStore = applicationStore
    self.store = store
  }

  @MainActor
  func handle(_ action: SidebarView.Action) {
    switch action {
    case .selectGroups(let groups):
      Task {
        try await render(groups, setSelection: true)
      }
    default:
      break
    }
  }

  @MainActor
  func handle(_ action: DetailView.Action) {
    switch action {
    case .singleDetailView(let action):
      let workflowId = action.workflowId
      updateTask?.cancel()
      updateTask = Task {
        do {
          guard let groups = store.groups
            .first(where: { $0.workflows
                .map { $0.id }
                .contains(workflowId)
            })
          else {
            return
          }

          let viewModels = try await groups.workflows.asViewModels()
          var selections = [ContentViewModel]()
          if let matchedSelection = viewModels.first(where: { $0.id == workflowId }) {
            selections = [matchedSelection]
          }

          try Task.checkCancellation()

          publisher.publish(viewModels, selections: selections)
        }
      }
    }
  }

  private func render(_ groups: [GroupViewModel], setSelection: Bool) async throws {
    let ids = groups.map { $0.id }
    let workflows = store.groups
      .filter { ids.contains($0.id) }
      .flatMap(\.workflows)
    let viewModels = try await workflows.asViewModels()

    try Task.checkCancellation()

    var animation: Animation? = nil
    var newSelections = [ContentViewModel]()

    if setSelection {
      let old = publisher.models
      let new = viewModels
      let diffs = new.difference(from: old).inferringMoves()

      if !old.isEmpty, new.count > 1 {
        for diff in diffs {
          if case .insert(_, let element, let associated) = diff,
             associated == nil {
              newSelections.append(element)
              animation = .default
          }
          if newSelections.count > 1 {
            newSelections = []
            animation = nil
            break
          }
        }
      }

      if !publisher.selections.intersection(viewModels).isEmpty {
        newSelections = Array(publisher.selections)
      } else if newSelections.isEmpty, let first = viewModels.first {
        newSelections = [first]
      }
    }

    try Task.checkCancellation()

    if let animation {
      let mainActorSelections = newSelections
      await MainActor.run {
        withAnimation(animation) {
          publisher.publish(viewModels, selections: mainActorSelections)
        }
      }
    } else {
      await publisher.publish(viewModels, selections: newSelections)
    }
  }
}

extension Workflow {
  func asViewModel() -> ContentViewModel {
    ContentViewModel(
      id: id,
      name: name,
      images: commands.images(),
      binding: trigger?.binding,
      badge: commands.count > 1 ? commands.count : 0,
      badgeOpacity: commands.count > 1 ? 1.0 : 0.0,
      isEnabled: isEnabled)
  }
}

private extension Workflow.Trigger {
  var binding: String? {
    switch self {
    case .keyboardShortcuts(let shortcuts):
      return shortcuts.binding
    case .application:
      return nil
    }
  }
}

private extension Array where Element == Command {
  func images() -> [ContentViewModel.ImageModel] {
    var images = [ContentViewModel.ImageModel]()
    for (offset, element) in self.enumerated() {
      let convertedOffset = Double(offset)
      switch element {
      case .application(let command):
        images.append(
          ContentViewModel.ImageModel(
            id: command.id,
            offset: convertedOffset,
            kind: .nsImage(NSWorkspace.shared.icon(forFile: command.application.path)))
        )
      case .builtIn:
        continue
      case .keyboard(let keyCommand):
        if let keyboardShortcut = keyCommand.keyboardShortcuts.first {
          images.append(.init(id: keyboardShortcut.id, offset: convertedOffset,
                              kind: .command(.keyboard(keys: keyCommand.keyboardShortcuts))))
        }
      case .open(let command):
        let nsImage: NSImage
        if let application = command.application, command.isUrl {
          nsImage = NSWorkspace.shared.icon(forFile: application.path)
        } else if command.isUrl {
          nsImage = NSWorkspace.shared.icon(forFile: "/System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app")
        } else {
          nsImage = NSWorkspace.shared.icon(forFile: command.path)
        }

        images.append(
          ContentViewModel.ImageModel(
            id: command.id,
            offset: convertedOffset,
            kind: .nsImage(nsImage))
        )
      case .script(let script):
        switch script.sourceType {
        case .inline(let source):
          images.append(.init(id: script.id,
                              offset: convertedOffset,
                              kind: .command(.script(.inline(id: script.id,
                                                             source: source, scriptExtension: .appleScript)))))

        case .path(let source):
          images.append(.init(id: script.id,
                              offset: convertedOffset,
                              kind: .command(.script(.path(id: script.id,
                                                           source: source,
                                                           scriptExtension: .appleScript)))))
        }
      case .shortcut(let shortcut):
        images.append(.init(id: shortcut.id, offset: convertedOffset, kind: .command(.shortcut)))
      case .type(let type):
        images.append(.init(id: type.id, offset: convertedOffset, kind: .command(.type(input: type.input))))
      }
    }

    return images
  }
}

private extension Array where Element == Workflow {
  func asViewModels() async throws -> [ContentViewModel] {
    var viewModels = [ContentViewModel]()
    viewModels.reserveCapacity(self.count)
    for model in self {
      try Task.checkCancellation()
      viewModels.append(model.asViewModel())
    }
    return viewModels
  }
}

private extension Array where Element == KeyShortcut {
  var binding: String? {
    if count == 1, let firstMatch = first {
      return "\(firstMatch.modifersDisplayValue)\(firstMatch.key)"
    }
    return nil
  }
}