import SwiftUI
import ModelKit

public struct GroupList: View {
  public enum Action {
    case createGroup
    case updateGroup(ModelKit.Group)
    case deleteGroup(ModelKit.Group)
    case moveGroup(from: Int, to: Int)
    case dropFile(URL)
  }

  static let idealWidth: CGFloat = 300

  @EnvironmentObject var userSelection: UserSelection
  let applicationProvider: ApplicationProvider
  let factory: ViewFactory
  @ObservedObject var groupController: GroupController
  let workflowController: WorkflowController
  @State private var editGroup: ModelKit.Group?
  @State private var selection: ModelKit.Group?

  public var body: some View {
    VStack(alignment: .leading) {
      List {
        ForEach(groupController.state, id: \.id) { group in
          NavigationLink(
            destination: VStack {
              NavigationView {
                ZStack(alignment: .bottom) {
                  factory.workflowList(group: group)
                  AddButton(text: "Add Workflow", action: {
                    workflowController.action(.createWorkflow(in: group))()
                  })
                }
              }
            },
            tag: group,
            selection: $userSelection.group,
            label: {
              GroupListCell(
                name: Binding(get: { group.name }, set: { name in
                  var group = group
                  group.name = name
                  groupController.perform(.updateGroup(group))
                }),
                color: Binding(get: { group.color }, set: { color in
                  var group = group
                  group.color = color
                }),
                count: group.workflows.count,
                onCommit: { name, color in
                  var group = group
                  group.name = name
                  group.color = color
                  groupController.perform(.updateGroup(group))
                }
              )
              .onTapGesture(count: 2, perform: {
                editGroup = group
              })
              .id(group.id)
            })
            .navigationViewStyle(DoubleColumnNavigationViewStyle())
            .contextMenu {
              Button("Show Info") { editGroup = group }
              Divider()
              Button("Delete") { groupController.action(.deleteGroup(group))() }
            }
        }.onMove(perform: { indices, newOffset in
          for i in indices {
            groupController.action(.moveGroup(from: i, to: newOffset))()
          }
        })
      }
      .introspectTableView(customize: { tableView in
        tableView.resignFirstResponder()
        tableView.allowsEmptySelection = false
      }).sheet(item: $editGroup, content: editGroup)
      AddButton(text: "Add Group", action: {
        groupController.perform(.createGroup)
      })
    }
  }
}

// MARK: - Subviews

private extension GroupList {
  func editGroup(_ group: ModelKit.Group) -> some View {
    EditGroup(
      name: group.name,
      color: group.color,
      bundleIdentifiers: group.rule?.bundleIdentifiers ?? [],
      applicationProvider: applicationProvider.erase(),
      editAction: { name, color, bundleIdentifers in
        var group = group
        group.name = name
        group.color = color

        var rule = group.rule ?? Rule()

        if !bundleIdentifers.isEmpty {
          rule.bundleIdentifiers = bundleIdentifers
          group.rule = rule
        } else {
          group.rule = nil
        }

        groupController.perform(.updateGroup(group))
        editGroup = nil
      },
      cancelAction: { editGroup = nil })
  }
}

// MARK: - Previews

struct GroupList_Previews: PreviewProvider, TestPreviewProvider {
  static var previews: some View {
    testPreview.previewAllColorSchemes()
  }

  static var testPreview: some View {
    DesignTimeFactory().groupList()
      .environmentObject(UserSelection())
      .frame(width: GroupList.idealWidth)
  }
}
