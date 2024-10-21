import AppKit
import AXEssibility
import Bonzai
import Foundation
import SwiftUI
import Windows

final class SystemWindowRelativeFocusNavigation: @unchecked Sendable {
  static let debug: Bool = false

  private lazy var systemElement = SystemAccessibilityElement()

  @MainActor lazy var window: NSWindow = ZenWindow(
    animationBehavior: .none,
    content: RoundedRectangle(cornerRadius: 8).stroke(Color.red, lineWidth: 4))
  @MainActor lazy var windowController: NSWindowController = NSWindowController(window: window)


  fileprivate func rerouteDirectionIfNeeded(_ direction: inout SystemWindowRelativeFocus.Direction, frame: CGRect,
                                            tiling: WindowTiling?, screen: NSScreen) {
    switch direction {
    case .up:
      if frame.minY >= screen.visibleFrame.minY { return }
    case .down:
      if frame.origin.y <= screen.visibleFrame.maxY { return }
    case .left:
      if frame.minX - frame.width / 2 >= screen.visibleFrame.minX { return }
    case .right:
      if frame.maxX + frame.width / 2 <= screen.visibleFrame.maxX { return }
    }

    switch tiling {
    case .left:
      switch direction {
      case .up, .down: direction = .right
      case .right:     direction = .down
      case .left:      break
      }
    case .right, .bottom:
      switch direction {
      case .up, .down: direction = .left
      case .left:      direction = .down
      case .right:     direction = .up
      }
    case .top:
      break
    case .topLeft:
      switch direction {
      case .down:      direction = .right
      case .right:     direction = .down
      case .up, .left: break
      }
    case .topRight:
      switch direction {
      case .down:       direction = .left
      case .left:       direction = .down
      case .up, .right: break
      }
    case .bottomLeft:
      switch direction {
      case .up:          direction = .right
      case .right:       direction = .up
      case .down, .left: break
      }
    case .bottomRight:
      switch direction {
      case .up:           direction = .left
      case .left:         direction = .up
      case .right, .down: break
      }
    default:
      break
    }
  }

  func findNextWindow(_ currentWindow: RelativeWindowModel, windows: [RelativeWindowModel],
                      direction: SystemWindowRelativeFocus.Direction,
                      initialScreen: NSScreen = NSScreen.main!) async throws -> RelativeWindowModel? {
    let initialDirection = direction
    let windowSpacing = max(CGFloat(UserDefaults(suiteName: "com.apple.WindowManager")?.float(forKey: "TiledWindowSpacing") ?? 8), 0)
    let systemWindows = windows.systemWindows
      .sorted { $0.index < $1.index }
      .filter { $0.window != currentWindow }

    if systemWindows.isEmpty { return nil }

    let width = max(min(1, windowSpacing), 20)
    let height = max(min(1, windowSpacing), 20)

    let y = switch direction {
    case .up:    currentWindow.rect.minY - height / 2 // .midY: Verify that doesn't break multi-monitor navigation
    case .down:  currentWindow.rect.minY // .midY: Verify that doesn't break multi-monitor navigation
    case .left:  currentWindow.rect.minY
    case .right: currentWindow.rect.minY
    }

    let x = switch direction {
    case .up:    currentWindow.rect.midX + width
    case .down:  currentWindow.rect.midX - width
    case .left:  currentWindow.rect.minX - width
    case .right: currentWindow.rect.maxX + width
    }

    var direction = initialDirection
    var fieldOfViewRect = CGRect(
      origin: CGPoint(x: x, y: y),
      size: CGSize(width: width, height: height)
    )

    let minX = (systemWindows.map { $0.window.rect.minX }.min() ?? 0) + windowSpacing
    let maxX = (systemWindows.map { $0.window.rect.maxX }.max() ?? 0) + windowSpacing
    let minY = (systemWindows.map { $0.window.rect.minY }.min() ?? 0) + windowSpacing
    let maxY = (systemWindows.map { $0.window.rect.maxY }.max() ?? 0) + windowSpacing

    var searching = true
    var match: RelativeSystemWindowModel?
    var constraint: (RelativeWindowModel) -> Bool
    var tiling: WindowTiling?

    if let screen = currentScreen(fieldOfViewRect).first {
      tiling = SystemWindowTilingRunner.calculateTiling(for: currentWindow.rect, in: screen.visibleFrame.mainDisplayFlipped)

      switch tiling {
      case .topLeft:
        fieldOfViewRect.origin.x = currentWindow.rect.minX + windowSpacing
      case .topRight:
        fieldOfViewRect.origin.x = currentWindow.rect.maxX - windowSpacing - fieldOfViewRect.width
      default:
        break
      }
    }

    updateDebugWindow(fieldOfViewRect)

    while searching {
      try Task.checkCancellation()

      if Self.debug {
        try await Task.sleep(for: .seconds(0.0125))
      }

      let increment: CGFloat = 50
      switch direction {
      case .left:
        fieldOfViewRect.origin.x -= increment
        if fieldOfViewRect.maxX < minX - windowSpacing { searching = false }
        constraint = {
          $0.rect.origin.x < currentWindow.rect.origin.x &&
          abs($0.rect.origin.x - currentWindow.rect.origin.x) > 2
        }
      case .right:
        fieldOfViewRect.origin.x += increment
        if fieldOfViewRect.minX > maxX { searching = false }
        constraint = {
          $0.rect.origin.x > currentWindow.rect.origin.x &&
          $0.rect.maxX != currentWindow.rect.maxX &&
          abs($0.rect.origin.x - currentWindow.rect.origin.x) > 2
        }
      case .up:
        fieldOfViewRect.origin.y -= increment
        if fieldOfViewRect.maxY < minY { searching = false }
        constraint = {
          $0.rect.origin.y != currentWindow.rect.origin.y &&
          abs($0.rect.origin.y - currentWindow.rect.origin.y) > 2
        }
      case .down:
        fieldOfViewRect.origin.y += increment

        if fieldOfViewRect.maxY + fieldOfViewRect.height >= maxY {
          searching = false
        }

        constraint = {
          $0.rect.origin.y > currentWindow.rect.origin.y &&
          abs($0.rect.origin.y - currentWindow.rect.origin.y) > 2
        }
      }

      // Use accessibility to verify the location of the window.
      let elementOrigin = CGPoint(x: fieldOfViewRect.midX, y: fieldOfViewRect.midY)
      if let accessWindow = systemElement.element(at: elementOrigin, as: AnyAccessibilityElement.self)?.window,
         let firstMatch = systemWindows.first(where: { $0.window.id == accessWindow.id }) {
        return firstMatch.window
      }

      for visibleWindow in systemWindows where visibleWindow.window != currentWindow {
        let constraintResult = constraint(visibleWindow.window)
        let intersectionResult = fieldOfViewRect.intersects(visibleWindow.window.rect)

        if constraintResult && intersectionResult {
          match = visibleWindow
          searching = false
          return match?.window
        }
      }

      updateDebugWindow(fieldOfViewRect)

      if let screen = currentScreen(fieldOfViewRect).first {
        rerouteDirectionIfNeeded(&direction, frame: fieldOfViewRect, tiling: tiling, screen: screen)
      } else {
        searching = false
      }
    }

    if let match {
      return match.window
    } else {
      fieldOfViewRect.size = .init(width: initialScreen.visibleFrame.width / 2.5,
                                   height: initialScreen.visibleFrame.height / 2.5)

      if NSScreen.screens.count == 1 {
        fieldOfViewRect.origin.x = initialScreen.visibleFrame.minX - windowSpacing
        fieldOfViewRect.origin.y = initialScreen.visibleFrame.mainDisplayFlipped.midY
      } else {
        switch initialDirection {
        case .up: #warning("Implement this.")
          break
        case .down: #warning("Implement this.")
          break
        case .left:
          fieldOfViewRect.origin.x = initialScreen.visibleFrame.minX - windowSpacing - fieldOfViewRect.width
          fieldOfViewRect.origin.y = initialScreen.visibleFrame.mainDisplayFlipped.midY
        case .right:
          fieldOfViewRect.origin.x = initialScreen.visibleFrame.maxX + windowSpacing + fieldOfViewRect.width
          fieldOfViewRect.origin.y = initialScreen.visibleFrame.mainDisplayFlipped.midY
        }
      }

      let applicableScreens = NSScreen.screens.filter( { $0.frame.intersects(fieldOfViewRect) })
      if let nextScreen = applicableScreens.first {
        fieldOfViewRect.origin.x = nextScreen.frame.midX - fieldOfViewRect.size.width / 2
        fieldOfViewRect.origin.y = nextScreen.frame.mainDisplayFlipped.midY - fieldOfViewRect.size.height / 2

        updateDebugWindow(fieldOfViewRect)

        if NSScreen.screens.count == 1 {
          return nil
          // Add a setting for "wrap-around" when the user hits the edge of the screen.
//          return visibleWindows
//            .filter({ $0.window != currentWindow })
//            .sorted(by: { lhs, rhs in
//              switch initialDirection {
//              case .up:    lhs.window.rect.minY > rhs.window.rect.minY
//              case .down:  lhs.window.rect.maxX < rhs.window.rect.maxY
//              case .left:  lhs.window.rect.minX > rhs.window.rect.minX
//              case .right: lhs.window.rect.maxX < rhs.window.rect.maxX
//              }
//            })
//            .first(where: { $0.window.rect.intersects(fieldOfViewRect) })?.window
        } else if let match = windows
          .filter({ $0 != currentWindow })
          .first(where: { $0.rect.intersects(fieldOfViewRect) }) {

          switch initialDirection {
          case .up, .down:
            if currentWindow.rect.origin.y == match.rect.origin.y { return nil }
          case .left, .right:
            if currentWindow.rect.origin.x == match.rect.origin.x { return nil }
          }
          return match
        }

      }
      return nil
    }
  }

  private func updateDebugWindow(_ frame: CGRect) {
    if Self.debug {
      Task { @MainActor in
        windowController.window?.animator().setFrame(frame.mainDisplayFlipped, display: true)
        window.orderFrontRegardless()
      }
    }
  }

  private func currentScreen(_ rect: CGRect) -> [NSScreen] {
    NSScreen.screens.filter( { $0.visibleFrame.mainDisplayFlipped.intersects(rect) })
  }

  private func targetRect(on screen: NSScreen) -> CGRect {
    let size: CGFloat = 2
    let origin = CGPoint(x: screen.frame.midX - size, y: screen.frame.midY - size)
    let targetRect: CGRect = CGRect(origin: origin, size: CGSize(width: size, height: size))
    return targetRect
  }
}

extension Array<RelativeWindowModel> {
  var systemWindows: [RelativeSystemWindowModel] { enumerated().reduce(into: [], { result, entry in
    result.append(RelativeSystemWindowModel(index: entry.offset, window: entry.element))
  })
  }
}
