import Foundation
import Cocoa

final class DetailCommandActionReducer {
  static func reduce(_ action: CommandView.Action,
                     keyboardCowboyEngine: KeyboardCowboyEngine,
                     workflow: inout  Workflow) async {
    guard var command: Command = workflow.commands.first(where: { $0.id == action.commandId }) else {
      fatalError("Unable to find command.")
    }

    switch action {
    case .toggleEnabled(_, _, let newValue):
      command.isEnabled = newValue
      workflow.updateOrAddCommand(command)
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
          await DetailCommandContainerActionReducer.reduce(action, command: command, workflow: &workflow)
        }
      case .keyboard(let action, _, _):
        switch action {
        case .updateKeyboardShortcuts(let keyboardShortcuts):
          command = .keyboard(.init(id: command.id, keyboardShortcuts: keyboardShortcuts))
          workflow.updateOrAddCommand(command)
        case .updateName(let newName):
          command.name = newName
          workflow.updateOrAddCommand(command)
        case .commandAction(let action):
          await DetailCommandContainerActionReducer.reduce(action, command: command, workflow: &workflow)
        }
      case .open(let action, _, _):
        switch action {
        case .updateName(let newName):
          command.name = newName
          workflow.updateOrAddCommand(command)
        case .openWith:
          break
        case .commandAction(let action):
          await DetailCommandContainerActionReducer.reduce(action, command: command, workflow: &workflow)
        case .reveal(let path):
          NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
        }
      case .script(let action, _, _):
        switch action {
        case .updateSource(let newKind):
          let scriptCommand: ScriptCommand
          switch newKind {
          case .path(let id, let source, let kind):
            switch kind {
            case .shellScript:
              scriptCommand = .shell(id: id, isEnabled: command.isEnabled, name: command.name, source: .path(source))
            case .appleScript:
              scriptCommand = .appleScript(id: id, isEnabled: command.isEnabled, name: command.name, source: .path(source))
            }
          case .inline(let id, let source, let kind):
            switch kind {
            case .shellScript:
              scriptCommand = .shell(id: id, isEnabled: command.isEnabled, name: command.name, source: .inline(source))
            case .appleScript:
              scriptCommand = .appleScript(id: id, isEnabled: command.isEnabled, name: command.name, source: .inline(source))
            }
          }
          command = .script(scriptCommand)
          workflow.updateOrAddCommand(command)
        case .updateName(let newName):
          command.name = newName
          workflow.updateOrAddCommand(command)
        case .open(let source):
          let path = (source as NSString).expandingTildeInPath
          await keyboardCowboyEngine.run([
            .open(.init(path: path))
          ], serial: true)
        case .reveal(let path):
          NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
        case .edit:
          break
        case .commandAction(let action):
          await DetailCommandContainerActionReducer.reduce(action, command: command, workflow: &workflow)
        }
      case .shortcut(let action, _, _):
        switch action {
        case .updateName(let newName):
          command.name = newName
          workflow.updateOrAddCommand(command)
        case .openShortcuts:
          break
        case .commandAction(let action):
          await DetailCommandContainerActionReducer.reduce(action, command: command, workflow: &workflow)
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
          await DetailCommandContainerActionReducer.reduce(action, command: command, workflow: &workflow)
        }
      }
    }
  }
}