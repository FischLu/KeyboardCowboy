import SwiftUI

struct WorkflowTriggerListView: View {
  @ObserveInjection var inject

  @Namespace var namespace

  private let data: DetailViewModel
  private let onAction: (SingleDetailView.Action) -> Void

  var focus: FocusState<AppFocus?>.Binding

  private let applicationTriggerSelectionManager: SelectionManager<DetailViewModel.ApplicationTrigger>
  private let keyboardShortcutSelectionManager: SelectionManager<KeyShortcut>

  init(_ focus: FocusState<AppFocus?>.Binding, data: DetailViewModel,
       applicationTriggerSelectionManager: SelectionManager<DetailViewModel.ApplicationTrigger>,
       keyboardShortcutSelectionManager: SelectionManager<KeyShortcut>,
       onAction: @escaping (SingleDetailView.Action) -> Void) {
    self.focus = focus
    self.data = data
    self.applicationTriggerSelectionManager = applicationTriggerSelectionManager
    self.keyboardShortcutSelectionManager = keyboardShortcutSelectionManager
    self.onAction = onAction
  }

  var body: some View {
    Group {
      switch data.trigger {
      case .keyboardShortcuts(let shortcuts):
        HStack {
          Button(action: {
            onAction(.removeTrigger(workflowId: data.id))
          },
                 label: { Image(systemName: "xmark") })
          .buttonStyle(.appStyle)
          Label("Keyboard Shortcuts sequence:", image: "")
            .padding(.trailing, 12)
        }
        .padding([.leading, .trailing], 8)

        WorkflowShortcutsView(focus, data: shortcuts, selectionManager: keyboardShortcutSelectionManager) { keyboardShortcuts in
          onAction(.updateKeyboardShortcuts(workflowId: data.id, keyboardShortcuts: keyboardShortcuts))
        }
        .matchedGeometryEffect(id: "workflow-triggers", in: namespace)

      case .applications(let triggers):
        HStack {
          Button(action: {
            onAction(.removeTrigger(workflowId: data.id))
          },
                 label: { Image(systemName: "xmark") })
          .buttonStyle(.gradientStyle(config: .init(nsColor: .systemRed, grayscaleEffect: true)))
          Label("Application trigger:", image: "")
        }
        .padding([.leading, .trailing], 8)
        WorkflowApplicationTriggerView(focus, data: triggers,
                                       selectionManager: applicationTriggerSelectionManager) { action in
          onAction(.applicationTrigger(workflowId: data.id, action: action))
        }
        .padding(.bottom, 16)
        .matchedGeometryEffect(id: "workflow-triggers", in: namespace)
      case .none:
        Label("Add a trigger:", image: "")
          .padding([.leading, .trailing], 8)
        WorkflowTriggerView(onAction: { action in
          onAction(.trigger(workflowId: data.id, action: action))
        })
        .matchedGeometryEffect(id: "workflow-triggers", in: namespace)
      }
    }
    .animation(.spring(response: 0.3, dampingFraction: 0.65, blendDuration: 0.2), value: data.trigger)
  }
}

struct WorkflowTriggerListView_Previews: PreviewProvider {
  @FocusState static var focus: AppFocus?
  static var previews: some View {
    WorkflowTriggerListView($focus, data: DesignTime.detail,
                            applicationTriggerSelectionManager: .init(),
                            keyboardShortcutSelectionManager: .init()) { _ in }
      .frame(height: 900)
  }
}