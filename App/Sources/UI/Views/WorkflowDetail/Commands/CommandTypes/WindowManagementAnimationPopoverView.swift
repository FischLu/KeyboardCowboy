import Bonzai
import Inject
import SwiftUI

struct WindowManagementAnimationPopoverView: View {
  @ObserveInjection var inject
  @State private var animationDuration: String
  @Binding private var windowCommand: CommandViewModel.Kind.WindowManagementModel
  @Binding private var isShown: Bool

  private let onChange: (Double) -> Void

  init(_ windowCommand: Binding<CommandViewModel.Kind.WindowManagementModel>,
       isShown: Binding<Bool>,
       onChange: @escaping (Double) -> Void) {
    _windowCommand = windowCommand
    _isShown = isShown
    _animationDuration = .init(initialValue: String(windowCommand.wrappedValue.animationDuration))
    self.onChange = onChange
  }

  var body: some View {
    HStack {
      TextField("Animation duration", text: $animationDuration) { isEditing in
        guard isShown else { return}
        if !isEditing {
          if let value = Double(self.animationDuration) {
            if value > 0 {
              windowCommand.animationDuration = value
            } else {
              windowCommand.animationDuration = 0
            }
            onChange(value)
          }
        }
      }
      .environment(\.textFieldBackgroundColor, Color(.windowBackgroundColor))

      Button(action: {
        onChange(0)
        windowCommand.animationDuration = 0
        isShown = false
      }, label: {
        Image(systemName: "clear")
      })
    }
    .padding(16)
    .enableInjection()
  }
}

struct WindowManagementAnimationPopoverView_Previews: PreviewProvider {
  static let command = CommandViewModel.Kind.WindowManagementModel.init(
    id: UUID().uuidString,
    kind: .center,
    animationDuration: 0
  )
  static var previews: some View {
    WindowManagementAnimationPopoverView(
      .constant(command),
      isShown: .constant(true),
      onChange: { _ in })
  }
}
