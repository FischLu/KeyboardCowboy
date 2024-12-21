import Apps
import AXEssibility
import Bonzai
import Inject
import SwiftUI

@MainActor
final class WindowSwitcherPublisher: ObservableObject {
  @Published var items: [WindowSwitcherView.Item] = []
  @Published var selections: Set<WindowSwitcherView.Item.ID> = []
  @Published var query: String = ""

  init(items: [WindowSwitcherView.Item], selections: [WindowSwitcherView.Item.ID]) {
    self.items = items
    self.selections = Set(selections)
  }

  func publish(_ items: [WindowSwitcherView.Item]) {
    self.items = items
  }

  func publish(_ selections: [WindowSwitcherView.Item.ID]) {
    self.selections = Set(selections)
  }
}


struct WindowSwitcherView: View {
  struct Item: Identifiable, Equatable {
    let id: String
    let title: String
    let app: Application
    let window: WindowAccessibilityElement

    static func == (lhs: Item, rhs: Item) -> Bool {
      lhs.id == rhs.id &&
      lhs.title == rhs.title &&
      lhs.app == rhs.app
    }
  }

  enum Focus: Hashable {
    case textField
  }

  @FocusState var focus: Focus?
  @ObserveInjection var inject
  @ObservedObject private var publisher: WindowSwitcherPublisher

  init(publisher: WindowSwitcherPublisher) {
    self.publisher = publisher
  }

  var body: some View {
    VStack(spacing: 0) {
      TextField(text: $publisher.query, prompt: Text("Filter"), label: {
        Text(publisher.query)
      })
      .textFieldStyle(
        .zen(
          .init(
            calm: true,
            color: .custom(.clear),
            backgroundColor: Color.clear,
            cornerRadius: 0,
            font: .largeTitle,
            glow: false,
            focusEffect: .constant(false),
            grayscaleEffect: .constant(false),
            hoverEffect: .constant(false),
            padding: .zero,
            unfocusedOpacity: 0.8
          )
        )
      )
      .padding(.horizontal, 8)
      .padding(.top, 4)
      .focused($focus, equals: .textField)

      ZenDivider()

      ScrollViewReader { proxy in
        CompatList {
          ForEach(publisher.items) { item in
            HStack(spacing: 4) {
              WindowView(item, selected: Binding<Bool>.readonly({ publisher.selections.contains(item.id) }))
            }
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .compositingGroup()
            .onTapGesture {
              publisher.selections.removeAll()
              publisher.selections.insert(item.id)
            }
          }
        }
        .animation(.linear, value: publisher.items)
        .onChange(of: publisher.query) { newValue in
          if newValue.isEmpty {
            proxy.scrollTo(publisher.selections.first)
          }
        }
        .onChange(of: publisher.selections, perform: { newValue in
          proxy.scrollTo(newValue.first)
          focus = .textField
        })
      }
    }
    .onAppear {
      DispatchQueue.main.async {
        focus = .textField
      }
    }
    .background(ZenVisualEffectView(material: .headerView, blendingMode: .behindWindow, state: .active))
    .ignoresSafeArea()
    .enableInjection()
  }
}

fileprivate struct WindowView: View {
  @ObserveInjection var inject
  private let item: WindowSwitcherView.Item
  private var selected: Binding<Bool>
  @State private var animated: Bool = false

  init(_ item: WindowSwitcherView.Item, selected: Binding<Bool>) {
    self.item = item
    self.selected = selected
  }

  var body: some View {
    HStack {
      IconView(icon: Icon.init(item.app),
               size: CGSize(width: 32, height:32))
      Text(item.title)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
      Spacer()
      Text(item.app.displayName)
        .foregroundStyle(Color.secondary)
        .padding(.trailing, 4)
        .font(.caption)
    }
    .shadow(radius: 1, y: 1)
    .padding(.vertical, 2)
    .padding(.horizontal, 4)
    .background {
      LinearGradient(stops: [
        Gradient.Stop(color: Color.accentColor
          .opacity(selected.wrappedValue ? 0.5 : 0), location: 0.0),
        Gradient.Stop(color: Color.clear, location: 1.0),
      ], startPoint: .top, endPoint: .bottom)
    }
    .overlay {
      RoundedRectangle(cornerRadius: 6)
        .stroke(
          LinearGradient(
            stops: gradientColorStops(for: selected.wrappedValue),
            startPoint: .top,
            endPoint: .bottom
          ), lineWidth: 1
        )
        .opacity(selected.wrappedValue ? 1 : 0)
        .animation(.smooth, value: animated)
    }
    .padding(.vertical, 3)
    .onAppear {
      if selected.wrappedValue {
        withAnimation(.smooth) {
          animated = true
        }
      }
    }
    .onChange(of: selected.wrappedValue) { newValue in
      animated = newValue
    }
    .enableInjection()
  }

  private func gradientColorStops(for selected: Bool) -> [Gradient.Stop] {
    if selected && animated {
      [
        Gradient.Stop(color: Color(nsColor: .controlAccentColor.withSystemEffect(.pressed)).opacity(0.9), location: 0.0),
        Gradient.Stop(color: Color.white.opacity(0.3), location: 1.0),
      ]
    } else {
      [
        Gradient.Stop(color: Color.white.opacity(0.2), location: 0.0),
        Gradient.Stop(color: Color.clear, location: 1.0),
      ]
    }
  }
}
//
//#Preview {
//  let publisher = WindowSwitcherPublisher(items: [
//    WindowSwitcherView.Item(id: "1", title: "~", app: .finder()),
//    WindowSwitcherView.Item(id: "2", title: "Work", app: .calendar()),
//    WindowSwitcherView.Item(id: "3", title: "~", app: .systemSettings()),
//  ], selections: ["1"])
//  return WindowSwitcherView(publisher: publisher)
//}
