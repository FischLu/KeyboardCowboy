import SwiftUI
import UniformTypeIdentifiers

struct WorkflowCommandListView: View {
  static let animation: Animation = .spring(response: 0.3, dampingFraction: 0.65, blendDuration: 0.2)

  @Environment(\.openWindow) var openWindow
  @ObservedObject private var selectionManager: SelectionManager<CommandViewModel>
  @Binding var isPrimary: Bool
  private let workflowId: String
  private var namespace: Namespace.ID
  private let triggerPublisher: TriggerPublisher
  private let publisher: CommandsPublisher
  private let scrollViewProxy: ScrollViewProxy?
  private let onAction: (SingleDetailView.Action) -> Void
  private let focus: FocusState<AppFocus?>.Binding

  init(_ focus: FocusState<AppFocus?>.Binding,
       namespace: Namespace.ID,
       workflowId: String,
       isPrimary: Binding<Bool>,
       publisher: CommandsPublisher,
       triggerPublisher: TriggerPublisher,
       selectionManager: SelectionManager<CommandViewModel>,
       scrollViewProxy: ScrollViewProxy? = nil,
       onAction: @escaping (SingleDetailView.Action) -> Void) {
    _isPrimary = isPrimary
    self.focus = focus
    self.publisher = publisher
    self.triggerPublisher = triggerPublisher
    self.workflowId = workflowId
    self.namespace = namespace
    self.selectionManager = selectionManager
    self.scrollViewProxy = scrollViewProxy
    self.onAction = onAction
  }

  @ViewBuilder
  var body: some View {
    if publisher.data.commands.isEmpty {
      WorkflowCommandEmptyListView(namespace: namespace,
                                   workflowId: publisher.data.id,
                                   isPrimary: $isPrimary,
                                   onAction: onAction)
    } else {
      WorkflowCommandListHeaderView(namespace: namespace, workflowId: workflowId, onAction: onAction)
      WorkflowCommandListScrollView(focus,
                                    publisher: publisher,
                                    triggerPublisher: triggerPublisher,
                                    namespace: namespace,
                                    workflowId: workflowId,
                                    selectionManager: selectionManager,
                                    scrollViewProxy: scrollViewProxy,
                                    onAction: onAction)
    }
  }
}

struct WorkflowCommandListView_Previews: PreviewProvider {
  @Namespace static var namespace
  @FocusState static var focus: AppFocus?
  static var previews: some View {
    WorkflowCommandListView($focus,
                            namespace: namespace,
                            workflowId: "workflowId",
                            isPrimary: .constant(true),
                            publisher: CommandsPublisher(DesignTime.detail.commandsInfo),
                            triggerPublisher: TriggerPublisher(DesignTime.detail.trigger),
                            selectionManager: .init()) { _ in }
      .frame(height: 900)
  }
}
