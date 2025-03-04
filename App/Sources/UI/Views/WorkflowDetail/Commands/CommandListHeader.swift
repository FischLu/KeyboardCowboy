import Bonzai
import Inject
import SwiftUI

struct CommandListHeader: View {
  @ObserveInjection var inject
  @EnvironmentObject var updater: ConfigurationUpdater
  @EnvironmentObject var transaction: UpdateTransaction
  @EnvironmentObject var publisher: CommandsPublisher
  private let namespace: Namespace.ID

  init(namespace: Namespace.ID) {
    self.namespace = namespace
  }

  var body: some View {
    HStack {
      ZenLabel("Commands")
      Spacer()
      Group {
        Menu(content: {
          ForEach(DetailViewModel.Execution.allCases) { execution in
            Button(execution.rawValue, action: {
              updater.modifyWorkflow(using: transaction, withAnimation: .snappy(duration: 0.125)) { workflow in
                switch execution {
                case .concurrent: workflow.execution = .concurrent
                case .serial:     workflow.execution = .serial
                }
              }
            })
          }
        }, label: {
          Text(publisher.data.execution.rawValue)
        })
        .fixedSize()
        CommandListHeaderAddButton(namespace)
          .menuStyle { menu in
            menu.padding = .medium
            menu.backgroundColor = publisher.data.commands.isEmpty ? .systemGreen : .systemGray
            menu.hoverEffect = publisher.data.commands.isEmpty ? false : true
          }
      }
      .menuStyle { menu in
        menu.padding = .medium
        menu.backgroundColor = .systemGray
      }
    }
  }
}

struct WorkflowCommandListHeaderView_Previews: PreviewProvider {
  @Namespace static var namespace
  static var previews: some View {
    CommandListHeader(namespace: namespace)
      .designTime()
  }
}
