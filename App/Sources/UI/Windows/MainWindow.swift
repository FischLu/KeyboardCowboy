import AppKit
import Bonzai
import SwiftUI

@MainActor
final class MainWindow: NSObject, NSWindowDelegate {
  private var window: NSWindow?
  private let core: Core
  private let windowOpener: WindowOpener

  init(core: Core) {
    self.core = core
    self.windowOpener = WindowOpener(core: core)
  }

  func open() {
    let content = MainWindowView(core: core, onSceneAction: onSceneAction(_:))
      .environmentObject(windowOpener)
    let styleMask: NSWindow.StyleMask = [
      .titled, .closable, .resizable, .fullSizeContentView
    ]

    let window = ZenSwiftUIWindow(styleMask: styleMask, content: content)
    window.titlebarAppearsTransparent = true
    window.titleVisibility = .hidden
    window.identifier = .init(rawValue: KeyboardCowboyApp.mainWindowIdentifier)
    window.delegate = self
    if let frameDescriptor = UserDefaults.standard.string(forKey: "MainWindowFrame") {
      window.setFrame(from: frameDescriptor)
    } else {
      window.center()
    }
    window.orderFrontRegardless()
    window.makeKeyAndOrderFront(nil)
    KeyboardCowboyApp.activate(setActivationPolicy: true)
    self.window = window
  }

  func windowWillClose(_ notification: Notification) {
    if let mainWindow = window {
      UserDefaults.standard.set(mainWindow.frameDescriptor, forKey: "MainWindowFrame")
    }
    self.window = nil
  }

  func onSceneAction(_ scene: AppScene) {
    guard KeyboardCowboyApp.env() != .previews else { return }
    switch scene {
    case .permissions:
      windowOpener.openPermissions()
      KeyboardCowboyApp.activate()
    case .mainWindow:
      if let mainWindow = KeyboardCowboyApp.mainWindow {
        mainWindow.makeKeyAndOrderFront(nil)
      } else {
        open()
      }
      KeyboardCowboyApp.activate()
    case .addGroup:
      windowOpener.openGroup(.add(WorkflowGroup.empty()))
    case .editGroup(let groupId):
      if let workflowGroup = core.groupStore.group(withId: groupId) {
        windowOpener.openGroup(.edit(workflowGroup))
      } else {
        assertionFailure("Unable to find workflow group")
      }
    case .addCommand(let workflowId):
      windowOpener.openNewCommandWindow(.newCommand(workflowId: workflowId))
    }
  }
}
