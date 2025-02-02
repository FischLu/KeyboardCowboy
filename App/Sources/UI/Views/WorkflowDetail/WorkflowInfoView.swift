import Bonzai
import Inject
import Carbon
import SwiftUI

struct WorkflowInfoView: View {
  @EnvironmentObject private var transaction: UpdateTransaction
  @EnvironmentObject private var updater: ConfigurationUpdater
  @ObserveInjection var inject
  @ObservedObject private var publisher: InfoPublisher
  @State var name: String

  private let onInsertTab: () -> Void
  private var focus: FocusState<AppFocus?>.Binding

  init(_ focus: FocusState<AppFocus?>.Binding, publisher: InfoPublisher, onInsertTab: @escaping () -> Void) {
    self.focus = focus
    _name = .init(initialValue: publisher.data.name)
    self.publisher = publisher
    self.onInsertTab = onInsertTab
  }

  var body: some View {
    HStack(spacing: 0) {
      TextField("Workflow name", text: $name)
        .focused(focus, equals: .detail(.name))
        .fontWeight(.semibold)
        .textFieldStyle { style in
          style.calm = true
          style.font = .title
          style.padding = .small
          style.unfocusedOpacity = 0
        }
        .onChange(of: name) { newName in
          guard newName != publisher.data.name else { return }
          publisher.data.name = newName
          updater.modifyWorkflow(using: transaction) { workflow in
            workflow.name = newName
          }
        }
      Spacer()
      Toggle(isOn: $publisher.data.isEnabled, label: {})
        .onChange(of: publisher.data.isEnabled) { newValue in
          updater.modifyWorkflow(using: transaction, withAnimation: .snappy(duration: 0.125)) { workflow in
            workflow.isDisabled = !newValue
          }
        }
        .switchStyle {
          $0.style = .regular
        }
    }
    .enableInjection()
  }
}

struct WorkflowInfo_Previews: PreviewProvider {
  @FocusState static var focus: AppFocus?
  static var previews: some View {
    WorkflowInfoView($focus, publisher: .init(DesignTime.detail.info), onInsertTab: { })
      .padding()
  }
}
