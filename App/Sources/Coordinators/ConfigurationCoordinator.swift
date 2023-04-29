import Combine
import SwiftUI

@MainActor
final class ConfigurationCoordinator {
  private var subscription: AnyCancellable?
  let contentStore: ContentStore
  let store: ConfigurationStore
  let publisher: ConfigurationPublisher
  let selectionManager: SelectionManager<ConfigurationViewModel>

  init(contentStore: ContentStore, selectionManager: SelectionManager<ConfigurationViewModel>,
       store: ConfigurationStore) {
    self.contentStore = contentStore
    self.store = store
    self.selectionManager = selectionManager
    self.publisher = ConfigurationPublisher()

    Task {
      // TODO: Should we remove this subscription and make it more explicit when configurations change?
      subscription = store.$selectedConfiguration.sink(receiveValue: { [weak self] selectedConfiguration in
        self?.render(selectedConfiguration: selectedConfiguration)
      })
    }
  }

  func handle(_ action: SidebarView.Action) {
    switch action {
    case .selectConfiguration(let id):
      if let configuration = store.selectConfiguration(withId: id) {
        contentStore.use(configuration)
        render(selectedConfiguration: configuration)
      }
    case .addConfiguration(let name):
      let configuration = KeyboardCowboyConfiguration(id: UUID().uuidString, name: name, groups: [])
      store.add(configuration)
      contentStore.use(configuration)
    default:
      break
    }
  }

  private func render(selectedConfiguration: KeyboardCowboyConfiguration?) {
    var selections = [ConfigurationViewModel]()
    let configurations = store.configurations
      .map { configuration in
        let viewModel = ConfigurationViewModel(
          id: configuration.id,
          name: configuration.name,
          selected: selectedConfiguration?.id == configuration.id)

        if let selectedConfiguration, configuration.id == selectedConfiguration.id {
          selections.append(viewModel)
        }

        return viewModel
      }

    publisher.publish(configurations)
  }
}
