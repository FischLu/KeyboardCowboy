import Apps
import SwiftUI

struct ApplicationTriggerView: View {
  @ObserveInjection var inject
  @Binding var trigger: ApplicationTrigger

  var body: some View {
    HStack(spacing: 0) {
      IconView(path: trigger.application.path)
        .frame(width: 32, height: 32, alignment: .center)
        .padding(4)
      Divider()
        .padding(.trailing, 4)
        .opacity(0.5)
        .offset(x: -1, y: 0)

      VStack(alignment: .leading, spacing: 4) {
        Text(trigger.application.displayName)
        HStack {
          TogglesView(ApplicationTrigger.Context.allCases,
                      enabled: $trigger.contexts, id: \.id)
          .font(.caption)
          Spacer()
        }
      }
      .padding(.leading, 2)
    }
    .enableInjection()
  }

  struct ApplicationTriggerItem_Previews: PreviewProvider {
    static var previews: some View {
      ApplicationTriggerView(trigger: .constant(
        ApplicationTrigger(
          application: Application.finder(),
          contexts: [.frontMost])
      ))
    }
  }
}