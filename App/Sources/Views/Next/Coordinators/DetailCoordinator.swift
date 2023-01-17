import Apps
import SwiftUI

final class DetailCoordinator {
  let applicationStore: ApplicationStore
  let contentStore: ContentStore
  let keyboardCowboyEngine: KeyboardCowboyEngine
  let groupStore: GroupStore
  let publisher: DetailPublisher = .init(.empty)

  init(applicationStore: ApplicationStore,
       contentStore: ContentStore,
       keyboardCowboyEngine: KeyboardCowboyEngine,
       groupStore: GroupStore) {
    self.applicationStore = applicationStore
    self.keyboardCowboyEngine = keyboardCowboyEngine
    self.contentStore = contentStore
    self.groupStore = groupStore
  }

  func handle(_ action: ContentView.Action) {
    switch action {
    case .selectWorkflow(let content):
      Task { await render(content.map(\.id)) }
    default:
      break
    }
  }

  func process(_ payload: NewCommandPayload, workflowId: Workflow.ID) {
    Task {
      guard var workflow = groupStore.workflow(withId: workflowId) else { return }
      let command: Command
      switch payload {
      case .placeholder:
        return
      case .script(let value, let kind, let scriptExtension):
        let source: ScriptCommand.Source
        let name: String
        switch kind {
        case .file:
          source = .path(value)
          name = "Run '\((value as NSString).lastPathComponent.replacingOccurrences(of: "." + scriptExtension.rawValue, with: ""))'"
        case .source:
          source = .inline(value)
          switch scriptExtension {
          case .appleScript:
            name = "Run AppleScript"
          case .shellScript:
            name = "Run ShellScript"
          }
        }

        switch scriptExtension {
        case .appleScript:
          command = .script(.appleScript(id: UUID().uuidString, isEnabled: true, name: name, source: source))
        case .shellScript:
          command = .script(.shell(id: UUID().uuidString, isEnabled: true, name: name, source: source))
        }
      case .type(let text):
        command = .type(.init(name: text, input: text))
      case .shortcut(let name):
        command = .shortcut(.init(id: UUID().uuidString, shortcutIdentifier: name,
                                  name: name, isEnabled: true))
      case .application(let application, let action,
                        let inBackground, let hideWhenRunning, let ifNotRunning):
        var modifiers = [ApplicationCommand.Modifier]()
        if inBackground { modifiers.append(.background) }
        if hideWhenRunning { modifiers.append(.hidden) }
        if ifNotRunning { modifiers.append(.onlyIfNotRunning) }

        let commandAction: ApplicationCommand.Action
        switch action {
        case .close:
          commandAction = .close
        case .open:
          commandAction = .open
        }

        command = Command.application(.init(action: commandAction,
                                            application: application,
                                            modifiers: modifiers))
      case .open(let path, let application):
        let resolvedPath = (path as NSString).expandingTildeInPath
        command = Command.open(.init(name: "Open \(path)", application: application, path: resolvedPath))
      case .url(let targetUrl, let application):
        let urlString = targetUrl.absoluteString
        command = Command.open(.init(name: "Open \(urlString)", application: application, path: urlString))
      }
      workflow.commands.append(command)

      await groupStore.receive([workflow])
      await render([workflow.id], animation: .easeInOut(duration: 0.2))
    }
  }

  func handle(_ action: DetailView.Action) async {
      switch action {
      case .singleDetailView(let action):
        guard var workflow = groupStore.workflow(withId: action.workflowId) else { return }

        switch action {
        case .commandView(_, let action):
          await handleCommandAction(action, workflow: &workflow)
        case .moveCommand(_, let fromOffsets, let toOffset):
          workflow.commands.move(fromOffsets: fromOffsets, toOffset: toOffset)
        case .updateName(_, let name):
          workflow.name = name
        case .setIsEnabled(_, let isEnabled):
          workflow.isEnabled = isEnabled
        case .removeCommands(_, let commandIds):
          workflow.commands.removeAll(where: { commandIds.contains($0.id) })
        case .trigger(_, let action):
          switch action {
          case .addKeyboardShortcut:
            workflow.trigger = .keyboardShortcuts([])
          case .removeKeyboardShortcut:
            Swift.print("Remove keyboard shortcut")
          case .addApplication:
            workflow.trigger = .application([])
          }
        case .removeTrigger(_):
          workflow.trigger = nil
        case .applicationTrigger(_, let action):
          switch action {
          case .addApplicationTrigger(let application, let uuid):
            var applicationTriggers = [ApplicationTrigger]()
            if case .application(let previousTriggers) = workflow.trigger {
              applicationTriggers = previousTriggers
            }
            applicationTriggers.append(.init(id: uuid.uuidString, application: application))
            workflow.trigger = .application(applicationTriggers)
          case .removeApplicationTrigger(let trigger):
            var applicationTriggers = [ApplicationTrigger]()
            if case .application(let previousTriggers) = workflow.trigger {
              applicationTriggers = previousTriggers
            }
            applicationTriggers.removeAll(where: { $0.id == trigger.id })
            workflow.trigger = .application(applicationTriggers)
          case .updateApplicationTriggerContext(let viewModelTrigger):
            if case .application(var previousTriggers) = workflow.trigger,
               let index = previousTriggers.firstIndex(where: { $0.id == viewModelTrigger.id }) {
              var newTrigger = previousTriggers[index]

              if viewModelTrigger.contexts.contains(.closed) {
                newTrigger.contexts.insert(.closed)
              } else {
                newTrigger.contexts.remove(.closed)
              }

              if viewModelTrigger.contexts.contains(.frontMost) {
                newTrigger.contexts.insert(.frontMost)
              } else {
                newTrigger.contexts.remove(.frontMost)
              }

              if viewModelTrigger.contexts.contains(.launched) {
                newTrigger.contexts.insert(.launched)
              } else {
                newTrigger.contexts.remove(.launched)
              }

              previousTriggers[index] = newTrigger
              workflow.trigger = .application(previousTriggers)
            }
          }
        }

        await groupStore.receive([workflow])
        await render([workflow.id], animation: .easeInOut(duration: 0.2))
    }
  }

  func handleCommandAction(_ commandAction: CommandView.Action, workflow: inout Workflow) async {
    guard var command: Command = workflow.commands.first(where: { $0.id == commandAction.commandId }) else {
      fatalError("Unable to find command.")
    }

    switch commandAction {
    case .run(_, _):
      break
    case .remove(_, let commandId):
      workflow.commands.removeAll(where: { $0.id == commandId })
    case .modify(let kind):
      switch kind {
      case .application(let action, _, _):
        guard case .application(var applicationCommand) = command else {
          fatalError("Wrong command type")
        }

        switch action {
        case .changeApplication(let application):
          applicationCommand.application = application
          command = .application(applicationCommand)
          workflow.updateOrAddCommand(command)
        case .updateName(let newName):
          command.name = newName
          workflow.updateOrAddCommand(command)
        case .changeApplicationAction(let action):
          switch action {
          case .open:
            applicationCommand.action = .open
          case .close:
            applicationCommand.action = .close
          }
          command = .application(applicationCommand)
          workflow.updateOrAddCommand(command)
        case .changeApplicationModifier(let modifier, let newValue):
          if newValue {
            applicationCommand.modifiers.insert(modifier)
          } else {
            applicationCommand.modifiers.remove(modifier)
          }
          command = .application(applicationCommand)
          workflow.updateOrAddCommand(command)
        case .commandAction(let action):
          await handleCommandContainerAction(action, command: command, workflow: &workflow)
        }
      case .keyboard(let action, _, _):
        switch action {
        case .updateName(let newName):
          command.name = newName
          workflow.updateOrAddCommand(command)
        case .commandAction(let action):
          await handleCommandContainerAction(action, command: command, workflow: &workflow)
        }
      case .open(let action, _, _):
        switch action {
        case .updateName(let newName):
          command.name = newName
          workflow.updateOrAddCommand(command)
        case .openWith:
          break
        case .commandAction(let action):
          await handleCommandContainerAction(action, command: command, workflow: &workflow)
        case .reveal(let path):
          NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
        }
      case .script(let action, _, _):
        switch action {
        case .updateName(let newName):
          command.name = newName
          workflow.updateOrAddCommand(command)
        case .open(let source):
          Task {
            let path = (source as NSString).expandingTildeInPath
            await keyboardCowboyEngine.run([
              .open(.init(path: path))
            ], serial: true)
          }
        case .reveal(let path):
          NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
        case .edit:
          break
        case .commandAction(let action):
          await handleCommandContainerAction(action, command: command, workflow: &workflow)
        }
      case .shortcut(let action, _, _):
        switch action {
        case .updateName(let newName):
          command.name = newName
          workflow.updateOrAddCommand(command)
        case .openShortcuts:
          break
        case .commandAction(let action):
          await handleCommandContainerAction(action, command: command, workflow: &workflow)
        }
      case .type(let action, _, _):
        switch action {
        case .updateName(let newName):
          command.name = newName
          workflow.updateOrAddCommand(command)
        case .updateSource(let newInput):
          switch command {
          case .type(var typeCommand):
            typeCommand.input = newInput
            command = .type(typeCommand)
          default:
            fatalError("Wrong command type")
          }
          workflow.updateOrAddCommand(command)
        case .commandAction(let action):
          await handleCommandContainerAction(action, command: command, workflow: &workflow)
        }
      }
    }
  }

  private func handleCommandContainerAction(_ action: CommandContainerAction,
                                            command: Command,
                                            workflow: inout Workflow) async {
    switch action {
    case .run:
      break
    case .delete:
      workflow.commands.removeAll(where: { $0.id == command.id })
    }
  }

  private func render(_ ids: [Workflow.ID], animation: Animation? = nil) async {
    let workflows = groupStore.groups
      .flatMap(\.workflows)
      .filter { ids.contains($0.id) }

    var viewModels: [DetailViewModel] = []
    for workflow in workflows {
      var workflowCommands = [DetailViewModel.CommandViewModel]()
      for command in workflow.commands {
        let kind: DetailViewModel.CommandViewModel.Kind
        let name: String
        switch command {
        case .application(let applicationCommand):
          let inBackground = applicationCommand.modifiers.contains(.background)
          let hideWhenRunning = applicationCommand.modifiers.contains(.hidden)
          let onlyIfRunning = applicationCommand.modifiers.contains(.onlyIfNotRunning)
          kind = .application(action: applicationCommand.action.displayValue,
                              inBackground: inBackground,
                              hideWhenRunning: hideWhenRunning,
                              ifNotRunning: onlyIfRunning)

          name = applicationCommand.name.isEmpty
          ? applicationCommand.application.displayName
          : command.name
        case .builtIn(_):
          kind = .plain
          name = command.name
        case .keyboard(let keyboardCommand):
          kind = .keyboard(key: keyboardCommand.keyboardShortcut.key,
                           modifiers: keyboardCommand.keyboardShortcut.modifiers ?? [])
          name = command.name
        case .open(let openCommand):
          let appName: String?
          let appPath: String?
          if let app = openCommand.application {
            appName = app.displayName
            appPath = app.path
          } else if let url = URL(string: openCommand.path),
                    let appUrl = NSWorkspace.shared.urlForApplication(toOpen: url),
                    let app = applicationStore.application(at: appUrl) {
            appName = app.displayName
            appPath = app.path
          } else {
            appName = nil
            appPath = nil
          }

          kind = .open(path: openCommand.path, applicationPath: appPath, appName: appName)

          if openCommand.isUrl {
            name = openCommand.path
          } else {
            name = openCommand.path
          }
        case .shortcut(_):
          kind = .shortcut
          name = command.name
        case .script(let script):
          switch script {
          case .appleScript(_ , _, _, let source),
              .shell(_ , _, _, let source):
            switch source {
            case .path(let source):
              let fileExtension = (source as NSString).pathExtension
              kind = .script(.path(id: script.id,
                                   source: source,
                                   fileExtension: fileExtension.uppercased()))
            case .inline(_):
              let type: String
              switch script {
              case .shell:
                type = "sh"
              case .appleScript:
                type = "scpt"
              }
              kind = .script(.inline(id: script.id, type: type))
            }
          }
          name = command.name
        case .type(let type):
          kind = .type(input: type.input)
          name = command.name
        }

        workflowCommands.append(DetailViewModel.CommandViewModel(
          id: command.id,
          name: name,
          kind: kind,
          image: command.nsImage,
          isEnabled: command.isEnabled
        ))
      }

      let viewModel = DetailViewModel(
        id: workflow.id,
        name: workflow.name,
        isEnabled: workflow.isEnabled,
        trigger: workflow.trigger?.asViewModel(),
        commands: workflowCommands)
      viewModels.append(viewModel)
    }

    let state: DetailViewState
    if viewModels.count > 1 {
      state = .multiple(viewModels)
    } else if let viewModel = viewModels.first {
      state = .single(viewModel)
    } else {
      state = .empty
    }

    if let animation {
      await MainActor.run {
        withAnimation(animation) {
          publisher.publish(state)
        }
      }
    } else {
      await publisher.publish(state)
    }
  }
}

private extension Command {
  var nsImage: NSImage? {
    switch self {
    case .application(let command):
      return NSWorkspace.shared.icon(forFile: command.application.path)
    case .builtIn:
      return nil
    case .keyboard:
      return nil
    case .open(let command):
      let nsImage: NSImage
      if let application = command.application, command.isUrl {
        nsImage = NSWorkspace.shared.icon(forFile: application.path)
      } else if command.isUrl {
        nsImage = NSWorkspace.shared.icon(forFile: "/System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app")
      } else {
        nsImage = NSWorkspace.shared.icon(forFile: command.path)
      }
      return nsImage
    case .script(let kind):
      return NSWorkspace.shared.icon(forFile: kind.path)
    case .shortcut:
      return nil
    case .type:
      return nil
    }
  }
}

extension Workflow.Trigger {
  func asViewModel() -> DetailViewModel.Trigger {
    switch self {
    case .application(let triggers):
      return .applications(
        triggers.map { trigger in
          DetailViewModel.ApplicationTrigger(id: trigger.id,
                                             name: trigger.application.displayName,
                                             image: NSWorkspace.shared.icon(forFile: trigger.application.path),
                                             contexts: trigger.contexts.map {
            switch $0 {
            case .closed:
              return .closed
            case .frontMost:
              return .frontMost
            case .launched:
              return .launched
            }
          })
        }
      )
    case .keyboardShortcuts(let shortcuts):
      let values = shortcuts.map {
        DetailViewModel.KeyboardShortcut(id: $0.id, displayValue: $0.key, modifier: .shift)
      }
      return .keyboardShortcuts(values)
    }
  }
}

extension CommandView.Kind {
  var workflowId: DetailViewModel.ID {
    switch self {
    case .application(_, let workflowId, _),
        .keyboard(_, let workflowId, _),
        .open(_, let workflowId, _),
        .script(_, let workflowId, _),
        .shortcut(_, let workflowId, _),
        .type(_, let workflowId, _):
      return workflowId
    }
  }

  var commandId: DetailViewModel.CommandViewModel.ID {
    switch self {
    case .application(_, _, let commandId),
        .keyboard(_, _, let commandId),
        .open(_, _, let commandId),
        .script(_, _, let commandId),
        .shortcut(_, _, let commandId),
        .type(_, _, let commandId):
      return commandId
    }
  }
}

extension CommandView.Action {
  var workflowId: DetailViewModel.ID {
    switch self {
    case .modify(let kind):
      return kind.workflowId
    case .run(let workflowId, _),
        .remove(let workflowId, _):
      return workflowId
    }
  }

  var commandId: DetailViewModel.CommandViewModel.ID {
    switch self {
    case .modify(let kind):
      return kind.commandId
    case .run(_, let commandId),
        .remove(_, let commandId):
      return commandId
    }
  }

}

extension SingleDetailView.Action {
  var workflowId: String {
    switch self {
    case .removeTrigger(let workflowId):
      return workflowId
    case .setIsEnabled(let workflowId, _):
      return workflowId
    case .removeCommands(let workflowId, _):
      return workflowId
    case .applicationTrigger(let workflowId, _):
      return workflowId
    case .commandView(let workflowId, _):
      return workflowId
    case .moveCommand(let workflowId, _, _):
      return workflowId
    case .trigger(let workflowId, _):
      return workflowId
    case .updateName(let workflowId, _):
      return workflowId
    }
  }
}
