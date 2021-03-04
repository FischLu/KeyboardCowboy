import ViewKit
import SwiftUI

enum ApplicationState: Equatable {
  static func == (lhs: ApplicationState, rhs: ApplicationState) -> Bool {
    lhs.stringValue == rhs.stringValue
  }

  case initial
  case launching
  case launched
  case needsPermission(PermissionsView)
  case content(MainView)

  var stringValue: String {
    switch self {
    case .initial:
      return "initial"
    case .launching:
      return "launching"
    case .launched:
      return "launched"
    case .content:
      return "content"
    case .needsPermission:
      return "needsPermission"
    }
  }

  var currentView: AnyView? {
    switch self {
    case .launching, .launched, .initial:
      return nil
    case .needsPermission(let view):
      return view.erase()
    case .content(let view):
      return view.erase()
    }
  }
}
