import SwiftUI

enum InteractiveViewModifier {
  case command, shift, empty
}

struct InteractiveView<Element, Content, Overlay>: View where Content : View,
                                                              Overlay: View,
                                                              Element: Hashable,
                                                              Element: Identifiable,
                                                              Element.ID : CustomStringConvertible {
  @FocusState var focus: EditableStackFocus<Element>?
  var isFocused: Bool {
    focus == .focused(element.id)
  }
  private let index: Int
  @ViewBuilder
  private let content: () -> Content
  private let element: Element
  private let overlay: (Element, Int) -> Overlay
  private let onClick: (Element, Int, InteractiveViewModifier) -> Void
  private let onKeyDown: (Int, NSEvent.ModifierFlags) -> Void
  private let selectedColor: Color

  init(_ element: Element,
       index: Int,
       selectedColor: Color,
       @ViewBuilder content: @escaping () -> Content,
       @ViewBuilder overlay: @escaping (Element, Int) -> Overlay,
       onClick: @escaping (Element, Int, InteractiveViewModifier) -> Void,
       onKeyDown: @escaping (Int, NSEvent.ModifierFlags) -> Void) {
    self.element = element
    self.selectedColor = selectedColor
    self.index = index
    self.content = content
    self.overlay = overlay
    self.onClick = onClick
    self.onKeyDown = onKeyDown
  }

  var body: some View {
    content()
      .id(element.id)
      .background(FocusableProxy(onKeyDown: { onKeyDown($0, $1) }))
      .shadow(color: isFocused ? selectedColor.opacity(0.8) : Color(.sRGBLinear, white: 0, opacity: 0.33),
              radius: isFocused ? 1.0 : 0.0)
      .overlay(content: { overlay(element, index) })
      .gesture(TapGesture().modifiers(.command)
        .onEnded({ _ in
          onClick(element, index, .command)
        })
      )
      .gesture(TapGesture().modifiers(.shift)
        .onEnded({ _ in
          onClick(element, index, .shift)
        })
      )
      .gesture(TapGesture()
        .onEnded({ _ in
          focus = .focused(element.id)
          onClick(element, index, .empty)
        })
      )
      .focused($focus, equals: .focused(element.id))
    }
}
