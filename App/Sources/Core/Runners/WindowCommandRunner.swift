import AXEssibility
import Cocoa
import Foundation

enum WindowCommandRunnerError: Error {
  case unableToResolveFrontmostApplication
  case unabelToResolveWindowFrame
}

final class WindowCommandRunner {
  private var fullscreenCache = [CGWindowID: CGRect]()

  @MainActor
  func run(_ command: WindowCommand) async throws {
    switch command.kind {
    case .decreaseSize(let byValue, let direction, let value):
      try decreaseSize(byValue, in: direction, constrainedToScreen: value)
    case .increaseSize(let byValue, let direction, let value):
      try increaseSize(byValue, in: direction, constrainedToScreen: value)
    case .move(let toValue, let direction, let value):
      try move(toValue, in: direction, constrainedToScreen: value)
    case .fullscreen(let padding):
      try fullscreen(with: padding)
    case .center:
      try center()
    case .moveToNextDisplay(let mode):
      try moveToNextDisplay(mode)
    }
  }

  // MARK: Private methods

  private func center(_ screen: NSScreen? = NSScreen.main) throws {
    guard let screen = screen else { return }

    let (window, windowFrame) = try getFocusedWindow()
    let screenFrame = screen.frame
    let x: Double = screenFrame.midX - (windowFrame.width / 2)
    let y: Double = (screenFrame.height / 2) - (windowFrame.height / 2)
    let origin: CGPoint = .init(x: x, y: y)

    window.frame?.origin = origin
  }

  private func fullscreen(with padding: Int) throws {
    guard let screen = NSScreen.main else { return }
    let (window, windowFrame) = try getFocusedWindow()

    let value: CGFloat
    if padding > 1 {
      value = CGFloat(padding / 2)
    } else {
      value = 0
    }

    var newValue = screen.visibleFrame.insetBy(dx: value, dy: value)

    let dockSize = getDockSize(screen)
    if getDockPosition(screen) == .bottom { newValue.origin.y -= dockSize }
    let delta = ((window.frame?.size.width) ?? 0) - newValue.size.width
    let shouldToggle = delta >= -1 && delta <= 1
    if shouldToggle, let cachedFrame = fullscreenCache[window.id] {
      window.frame = cachedFrame
    } else {
      let statusBarHeight = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        .button?
        .window?
        .frame
        .height ?? 0
      newValue.origin.y -= statusBarHeight + NSStatusBar.system.thickness
      window.frame = newValue
      fullscreenCache[window.id] = windowFrame
    }
  }

  private func move(_ byValue: Int, in direction: WindowCommand.Direction,
                    constrainedToScreen: Bool) throws {
    let newValue = CGFloat(byValue)
    var (window, windowFrame) = try getFocusedWindow()
    let oldWindowFrame = windowFrame

    switch direction {
    case .leading:
      windowFrame.origin.x -= newValue
    case .topLeading:
      windowFrame.origin.x -= newValue
      windowFrame.origin.y -= newValue
    case .top:
      windowFrame.origin.y -= newValue
    case .topTrailing:
      windowFrame.origin.x += newValue
      windowFrame.origin.y -= newValue
    case .trailing:
      windowFrame.origin.x += newValue
    case .bottomTrailing:
      windowFrame.origin.x += newValue
      windowFrame.origin.y += newValue
    case .bottom:
      windowFrame.origin.y += newValue
    case .bottomLeading:
      windowFrame.origin.y += newValue
      windowFrame.origin.x -= newValue
    }

    if let screen = NSScreen.screens.first(where: { $0.frame.contains(oldWindowFrame) }), constrainedToScreen {
      if windowFrame.maxX >= screen.frame.maxX {
        windowFrame.origin.x = screen.frame.maxX - windowFrame.size.width
      } else if windowFrame.origin.x <= 0 {
        windowFrame.origin.x = screen.frame.origin.x
      } else if windowFrame.origin.x < screen.frame.origin.x {
        windowFrame.origin.x = screen.frame.origin.x
      }

      if windowFrame.maxY >= screen.visibleFrame.maxY {
        windowFrame.origin.y = screen.visibleFrame.maxY - windowFrame.size.height
      } else if windowFrame.origin.y >= screen.visibleFrame.maxY {
        windowFrame.origin.y = screen.visibleFrame.maxY
      }
    }

    window.frame?.origin = windowFrame.origin
  }

  private func increaseSize(_ byValue: Int, in direction: WindowCommand.Direction,
                            constrainedToScreen: Bool) throws {
    let newValue = CGFloat(byValue)
    var (window, windowFrame) = try getFocusedWindow()

    switch direction {
    case .leading:
      windowFrame.origin.x -= newValue
      windowFrame.size.width += newValue
    case .topLeading:
      windowFrame.origin.x -= newValue
      windowFrame.size.width += newValue
      windowFrame.origin.y -= newValue
      windowFrame.size.height += newValue
    case .top:
      windowFrame.origin.y -= newValue
      windowFrame.size.height += newValue
    case .topTrailing:
      windowFrame.origin.y -= newValue
      windowFrame.size.height += newValue
      windowFrame.size.width += newValue
    case .trailing:
      windowFrame.size.width += newValue
    case .bottomTrailing:
      windowFrame.size.width += newValue
      windowFrame.size.height += newValue
    case .bottom:
      windowFrame.size.height += newValue
    case .bottomLeading:
      windowFrame.origin.x -= newValue
      windowFrame.size.width += newValue
      windowFrame.size.height += newValue
    }

    if constrainedToScreen {
      windowFrame.origin.x = max(0, windowFrame.origin.x)
    }

    window.frame = windowFrame
  }

  private func decreaseSize(_ byValue: Int, in direction: WindowCommand.Direction,
                            constrainedToScreen: Bool) throws {
    let newValue = CGFloat(byValue)
    var (window, windowFrame) = try getFocusedWindow()
    let oldValue = windowFrame

    switch direction {
    case .leading:
      windowFrame.origin.x += newValue
      windowFrame.size.width -= newValue
      window.frame = windowFrame

      if window.frame?.width != windowFrame.width {
        window.frame?.origin.x = oldValue.origin.x
      }
    case .topLeading:
      windowFrame.size.width -= newValue
      windowFrame.size.height -= newValue
      window.frame = windowFrame
    case .top:
      windowFrame.size.height -= newValue
      window.frame = windowFrame
    case .topTrailing:
      windowFrame.origin.x += newValue
      windowFrame.size.height -= newValue
      windowFrame.size.width -= newValue
      window.frame = windowFrame

      if window.frame?.width != windowFrame.width {
        window.frame?.origin = oldValue.origin
      }
    case .trailing:
      windowFrame.size.width -= newValue
      window.frame = windowFrame
    case .bottomTrailing:
      windowFrame.origin.x += newValue
      windowFrame.origin.y += newValue
      windowFrame.size.width -= newValue
      windowFrame.size.height -= newValue
      window.frame = windowFrame
    case .bottom:
      windowFrame.origin.y += newValue
      windowFrame.size.height -= newValue
      window.frame = windowFrame
    case .bottomLeading:
      windowFrame.origin.y += newValue
      windowFrame.size.width -= newValue
      windowFrame.size.height -= newValue
      window.frame = windowFrame

      if window.frame?.width != windowFrame.width {
        window.frame?.origin = oldValue.origin
      }
    }
  }

  private func moveToNextDisplay(_ mode: WindowCommand.Mode) throws {
    guard let mainScreen = NSScreen.main else { return }

    var nextScreen: NSScreen? = NSScreen.screens.first
    var foundMain: Bool = false
    for screen in NSScreen.screens {
      if foundMain {
        nextScreen = screen
        break
      } else if mainScreen == nextScreen {
        foundMain = true
      }
    }

    guard let nextScreen else { return }
    let (window, windowFrame) = try getFocusedWindow()


    switch mode {
    case .center:
      window.frame?.origin.x = nextScreen.frame.origin.x
      try self.center(nextScreen)
    case .relative:
      let currentFrame = mainScreen.frame
      let nextFrame = nextScreen.frame
      var windowFrame = windowFrame

      // Make window frame relative to the next frame
      windowFrame.origin.x -= currentFrame.origin.x
      windowFrame.origin.y -= currentFrame.origin.y

      let screenMultiplier = CGSize(
        width: nextFrame.width / currentFrame.width,
        height: nextFrame.height / currentFrame.height
      )

      let width = windowFrame.size.width * screenMultiplier.width
      let height = windowFrame.size.height * screenMultiplier.height
      let x = nextFrame.origin.x + (windowFrame.origin.x * screenMultiplier.width)
      let y = nextFrame.origin.y  + (windowFrame.origin.y * screenMultiplier.height)
      let newFrame: CGRect = .init(x: x, y: y, width: width, height: height)

      window.frame = newFrame
    }
  }

  private func getFocusedWindow() throws -> (WindowAccessibilityElement, CGRect) {
    guard let frontmostApplication = NSWorkspace.shared.frontmostApplication else {
      throw WindowCommandRunnerError.unableToResolveFrontmostApplication
    }

    let window = try AppAccessibilityElement(frontmostApplication.processIdentifier)
      .focusedWindow()

    guard let windowFrame = window.frame else {
      throw WindowCommandRunnerError.unabelToResolveWindowFrame
    }

    return (window, windowFrame)
  }
}

enum DockPosition: Int {
  case bottom = 0
  case left = 1
  case right = 2
}

func getDockPosition(_ screen: NSScreen) -> DockPosition {
  if screen.visibleFrame.origin.y == screen.frame.origin.y {
    if screen.visibleFrame.origin.x == screen.frame.origin.x {
      return .right
    } else {
      return .left
    }
  } else {
    return .bottom
  }
}

func getDockSize(_ screen: NSScreen) -> CGFloat {
  switch getDockPosition(screen) {
  case .right:
    return screen.frame.width - screen.visibleFrame.width
  case .left:
    return screen.visibleFrame.origin.x
  case .bottom:
    return screen.visibleFrame.origin.y
  }
}

func isDockHidden(_ screen: NSScreen) -> Bool {
  getDockSize(screen) < 25
}