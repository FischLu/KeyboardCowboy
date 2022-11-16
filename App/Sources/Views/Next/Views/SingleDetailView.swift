import SwiftUI
import Apps

struct SingleDetailView: View {
  enum Action {
    case addCommand
    case applicationTrigger(WorkflowApplicationTriggerView.Action)
    case trigger(WorkflowTriggerView.Action)
  }

  enum Sheet: Int, Identifiable {
    var id: Int { self.rawValue }
    case newCommand
  }

  @ObserveInjection var inject
  @State private var model: DetailViewModel
  @State private var sheet: Sheet?
  private let onAction: (Action) -> Void

  init(_ model: DetailViewModel, onAction: @escaping (Action) -> Void) {
    _model = .init(initialValue: model)
    self.onAction = onAction
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading) {
        WorkflowInfoView($model)
          .padding([.leading, .trailing, .bottom], 8)

        Group {
          switch model.trigger {
          case .keyboardShortcuts(let shortcuts):
            Label("Keyboard Shortcuts:", image: "")
              .padding([.leading, .trailing], 8)
            WorkflowShortcutsView(shortcuts)
          case .applications(let triggers):
            Label("Application trigger:", image: "")
              .padding([.leading, .trailing], 8)
            WorkflowApplicationTriggerView(triggers) { action in
              onAction(.applicationTrigger(action))
            }
          case .none:
            Label("Add a trigger:", image: "")
              .padding([.leading, .trailing, .bottom], 8)
            WorkflowTriggerView(onAction: { action in
              onAction(.trigger(action))
            })
          }
        }
      }
      .padding()
      .background(Color(.textBackgroundColor))

      VStack(alignment: .leading, spacing: 0) {
        Label("Commands:", image: "")
          .padding([.leading, .trailing, .bottom], 8)
        EditableStack($model.commands, spacing: 1) { command in
          CommandView(command)
        }
        .padding(.bottom, 2)
      }
      .padding()
    }
    .background(gradient)
    .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
    .labelStyle(HeaderLabelStyle())
    .toolbar {
      ToolbarItemGroup(placement: .primaryAction) {
        HStack {
          Button(
            action: {
              sheet = .newCommand
            },
            label: {
              Label(title: {
                Text("Add command")
              }, icon: {
                Image(systemName: "plus.square.dashed")
                  .renderingMode(.template)
                  .foregroundColor(Color(.systemGray))
              })
            })
        }
      }
    }
    .sheet(item: $sheet, content: { kind in
      switch kind {
      case .newCommand:
        NewCommandSheetView { action in
          switch action {
          case .close:
            sheet = nil
          }
        }
      }
    })
    .enableInjection()
  }

  var gradient: some View {
    LinearGradient(
      gradient: Gradient(
        stops: [
          .init(color: Color(.windowBackgroundColor).opacity(0.25), location: 0.5),
          .init(color: Color(.gridColor).opacity(0.75), location: 1.0),
        ]),
      startPoint: .top,
      endPoint: .bottom)
  }
}

struct WorkflowApplicationTriggerView: View {
  enum Action {
    case addApplicationTrigger(Application)
    case removeApplicationTrigger(DetailViewModel.ApplicationTrigger)
  }

  @ObserveInjection var inject
  @EnvironmentObject var applicationStore: ApplicationStore

  @State private var triggers: [DetailViewModel.ApplicationTrigger]
  @State private var selection: String = UUID().uuidString
  private let onAction: (Action) -> Void

  init(_ triggers: [DetailViewModel.ApplicationTrigger], onAction: @escaping (Action) -> Void) {
    _triggers = .init(initialValue: triggers)
    self.onAction = onAction
  }

  var body: some View {
    VStack(alignment: .leading) {
      HStack {
        Picker("Application:", selection: $selection) {
          ForEach(applicationStore.applications, id: \.id) {
            Text($0.displayName)
              .tag($0.id)
          }
        }

        Button("Add", action: {
          if let application = applicationStore.application(for: selection) {
            onAction(.addApplicationTrigger(application))
          }
        })
      }
      EditableStack($triggers, lazy: true, spacing: 2) { trigger in
        HStack {
          Image(nsImage: trigger.image.wrappedValue)
            .resizable()
            .frame(width: 36, height: 36)
          VStack(alignment: .leading, spacing: 4) {
            Text(trigger.name.wrappedValue)
            HStack {
              ForEach(DetailViewModel.ApplicationTrigger.Context.allCases) { context in
                Toggle(context.displayValue, isOn: Binding<Bool>(get: {
                  trigger.contexts.wrappedValue.contains(context)
                }, set: { newValue in
                  if newValue {
                    trigger.contexts.wrappedValue.append(context)
                  } else {
                    trigger.contexts.wrappedValue.removeAll(where: { $0 == context })
                  }
                }))
                .font(.caption)
              }
            }
          }
          Spacer()
          Button(action: { onAction(.removeApplicationTrigger(trigger.wrappedValue)) },
                 label: { Image(systemName: "xmark.circle") })
          .buttonStyle(PlainButtonStyle())
          .padding()
        }
        .padding(4)
      }
      .padding(2)
      .background(Color(.windowBackgroundColor).opacity(0.5))
      .cornerRadius(8)
    }
    .enableInjection()
  }
}

struct WorkflowTriggerView: View {
  enum Action {
    case addApplication
    case addKeyboardShortcut
  }

  @ObserveInjection var inject
  private let onAction: (Action) -> Void

  init(onAction: @escaping (Action) -> Void) {
    self.onAction = onAction
  }

  var body: some View {
    VStack(alignment: .leading) {
      HStack {
        Button("Application", action: { onAction(.addApplication) })
        Button("Keyboard Shortcut", action: { onAction(.addKeyboardShortcut) })
        Spacer()
      }
    }
    .enableInjection()
  }
}

struct WorkflowInfoView: View {
  @ObserveInjection var inject
  @Binding var workflow: DetailViewModel

  init(_ workflow: Binding<DetailViewModel>) {
    _workflow = workflow
  }

  var body: some View {
    HStack {
      TextField("Workflow name", text: $workflow.name)
        .textFieldStyle(LargeTextFieldStyle())
      Spacer()
      Toggle("", isOn: $workflow.isEnabled)
        .toggleStyle(SwitchToggleStyle())
        .font(.callout)
    }
    .enableInjection()
  }
}

struct WorkflowShortcutsView: View {
  @ObserveInjection var inject
  @State private var keyboardShortcuts: [DetailViewModel.KeyboardShortcut]

  init(_ keyboardShortcuts: [DetailViewModel.KeyboardShortcut]) {
    _keyboardShortcuts = .init(initialValue: keyboardShortcuts)
  }

  var body: some View {
    VStack(alignment: .leading) {
      HStack {
        ScrollView(.horizontal, showsIndicators: false) {
          EditableStack($keyboardShortcuts, axes: .horizontal, lazy: true) { keyboardShortcut in
            HStack {
              ModifierKeyIcon(key: .function)
                .frame(width: 32)
              RegularKeyIcon(letter: keyboardShortcut.displayValue.wrappedValue)
            }
            .padding(6)
          }
        }
        Spacer()
        Divider()
        Button(action: {},
               label: { Image(systemName: "plus") })
        .buttonStyle(KCButtonStyle())
        .font(.callout)
        .padding(.horizontal, 16)
      }
      .padding(4)
      .background(Color(.windowBackgroundColor))
      .cornerRadius(8)
      .shadow(color: Color(.shadowColor).opacity(0.15), radius: 3, x: 0, y: 1)
    }
    .enableInjection()
  }
}

struct CommandView: View {
  @ObserveInjection var inject
  @Binding var command: DetailViewModel.CommandViewModel

  init(_ command: Binding<DetailViewModel.CommandViewModel>) {
    _command = command
  }

  var body: some View {
    HStack {
      HStack {
        ZStack {
          Rectangle()
            .fill(Color(nsColor: .controlAccentColor).opacity(0.1))
          if let image = command.image {
            Image(nsImage: image)
              .resizable()
              .aspectRatio(contentMode: .fit)
          }
        }
        .frame(width: 32, height: 32)
        .cornerRadius(8, antialiased: false)

        Text(command.name)
      }
      Spacer()
      Toggle("", isOn: $command.isEnabled)
        .toggleStyle(.switch)
    }
    .padding(8)
    .background(.background)
    .cornerRadius(8)
    .enableInjection()
  }
}

struct SingleDetailView_Previews: PreviewProvider {
  static var previews: some View {
    SingleDetailView(DesignTime.detail) { _ in }
  }
}