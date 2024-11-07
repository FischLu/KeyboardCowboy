import Bonzai
import SwiftUI
import UniformTypeIdentifiers

struct WorkflowCommandListView: View {
  static let animation: Animation = .spring(response: 0.3, dampingFraction: 0.65, blendDuration: 0.2)

  @Binding private var isPrimary: Bool
  @State var isTargeted: Bool = false
  @ObservedObject private var selectionManager: SelectionManager<CommandViewModel>
  private let publisher: CommandsPublisher
  private let scrollViewProxy: ScrollViewProxy?
  private let triggerPublisher: TriggerPublisher
  private let workflowId: String
  private var focus: FocusState<AppFocus?>.Binding
  private var namespace: Namespace.ID

  init(_ focus: FocusState<AppFocus?>.Binding,
       namespace: Namespace.ID,
       workflowId: String,
       isPrimary: Binding<Bool>,
       publisher: CommandsPublisher,
       triggerPublisher: TriggerPublisher,
       selectionManager: SelectionManager<CommandViewModel>,
       scrollViewProxy: ScrollViewProxy? = nil) {
    _isPrimary = isPrimary
    self.focus = focus
    self.publisher = publisher
    self.triggerPublisher = triggerPublisher
    self.workflowId = workflowId
    self.namespace = namespace
    self.selectionManager = selectionManager
    self.scrollViewProxy = scrollViewProxy
  }

  @ViewBuilder
  var body: some View {
    if publisher.data.commands.isEmpty {
      WorkflowCommandEmptyListView(focus,
                                   namespace: namespace,
                                   workflowId: publisher.data.id,
                                   isPrimary: $isPrimary)
    } else {
      WorkflowCommandListHeaderView(namespace: namespace)
      WorkflowCommandListScrollView(focus,
                                    publisher: publisher,
                                    triggerPublisher: triggerPublisher,
                                    namespace: namespace,
                                    workflowId: workflowId,
                                    selectionManager: selectionManager,
                                    scrollViewProxy: scrollViewProxy)
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
                            selectionManager: .init()) 
      .frame(height: 900)
      .designTime()
  }
}
