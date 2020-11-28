import SwiftUI
import ModelKit

public struct MainView: View {
  @EnvironmentObject var userSelection: UserSelection
  let factory: ViewFactory
  @ObservedObject var searchController: SearchController
  let applicationProvider: ApplicationProvider
  let commandController: CommandController
  let groupController: GroupController
  let openPanelController: OpenPanelController
  let workflowController: WorkflowController
  @State private var newCommandVisible: Bool = false

  public init(factory: ViewFactory,
              applicationProvider: ApplicationProvider,
              commandController: CommandController,
              groupController: GroupController,
              openPanelController: OpenPanelController,
              searchController: SearchController,
              workflowController: WorkflowController) {
    self.factory = factory
    self.applicationProvider = applicationProvider
    self.commandController = commandController
    self.groupController = groupController
    self.openPanelController = openPanelController
    self.searchController = searchController
    self.workflowController = workflowController
  }

  @ViewBuilder
  public var body: some View {
    NavigationView {
      sidebar
      EmptyView()
      EmptyView()
    }.toolbar {
      ToolbarItemGroup(placement: .navigation) {
        Button(action: toggleSidebar,
               label: {
                Image(systemName: "sidebar.left")
                  .renderingMode(.template)
                  .foregroundColor(Color(.systemGray))
               })

        if let group = userSelection.group {
          Button(action: { workflowController.perform(.createWorkflow(in: group)) },
                 label: {
                  Image(systemName: "rectangle.stack.badge.plus")
                    .renderingMode(.template)
                    .foregroundColor(Color(.systemGray))
                 })
        }

        HStack(spacing: 2) {
          Divider()
          Divider()
          Divider()
        }.padding(.trailing, 8)
      }

      ToolbarItemGroup {
        if let workflow = userSelection.workflow {
          Button(action: { newCommandVisible = true },
                 label: {
                  Image(systemName: "plus.app")
                    .renderingMode(.template)
                    .foregroundColor(Color(.systemGray))
                 })
            .sheet(isPresented: $newCommandVisible, content: {
              EditCommandView(
                applicationProvider: applicationProvider,
                openPanelController: openPanelController,
                saveAction: { newCommand in
                  commandController.action(.createCommand(newCommand, in: workflow))()
                  newCommandVisible = false
                },
                cancelAction: {
                  newCommandVisible = false
                },
                selection: Command.application(.init(application: Application.empty())),
                command: Command.application(.init(application: Application.empty())))
            })
        }
      }
    }
  }
}

// MARK: Extensions

private extension MainView {
  var sidebar: some View {
    VStack(alignment: .leading) {
      SearchField(query: Binding<String>(
                    get: { userSelection.searchQuery },
                    set: {
                      userSelection.searchQuery = $0
                      searchController.perform(.search($0))
                    }))
        .frame(height: 48)
        .padding(.horizontal, 12)
      factory.groupList()
        .listStyle(SidebarListStyle())
        .frame(minWidth: 225)
        .navigationViewStyle(DoubleColumnNavigationViewStyle())
    }
  }

  func toggleSidebar() {
    NSApp.keyWindow?.firstResponder?.tryToPerform(
      #selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
  }
}

struct MainView_Previews: PreviewProvider, TestPreviewProvider {
  static var previews: some View {
    testPreview.previewAllColorSchemes()
  }

  static var testPreview: some View {
    DesignTimeFactory().mainView()
      .environmentObject(UserSelection(
                          group: ModelFactory().groupList().first!,
                          workflow: ModelFactory().groupList().first!.workflows.first))
      .frame(width: 960, height: 620, alignment: .leading)
  }
}
