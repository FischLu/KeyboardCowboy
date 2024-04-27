import Bonzai
import SwiftUI

@MainActor
final class CommandPanelViewPublisher: ObservableObject {
  @MainActor
  @Published private(set) var state: CommandWindowView.CommandState

  @MainActor
  init(state: CommandWindowView.CommandState = .ready) {
    self.state = state
  }

  @MainActor
  func publish(_ newState: CommandWindowView.CommandState) {
    self.state = newState
  }
}

struct CommandWindowView: View {
  enum CommandState: Hashable, Equatable {
    case ready
    case running
    case error(String)
    case done(String)
  }

  @ObservedObject var publisher: CommandPanelViewPublisher
  @State var output: String = ""
  @State var scriptContents: String

  let command: ScriptCommand
  let action: () -> Void

  init(publisher: CommandPanelViewPublisher,
       command: ScriptCommand,
       action: @escaping () -> Void) {
    _scriptContents = .init(initialValue: command.source.contents)
    self.publisher = publisher
    self.command = command
    self.action = action
  }

  var body: some View {
    VStack(spacing: 0) {
      CommandWindowHeaderView(
        state: publisher.state,
        name: command.name,
        action: action
      )

      ZenDivider()

      ScrollView {
        VStack(spacing: 4) {
          switch command.source {
          case .path(let path):
            CommandWindowPathView(path: path)
              .padding([.top, .leading, .trailing], 12)
          case .inline(let contents):
            CommandWindowInlineView(contents: contents)
              .padding([.top, .leading, .trailing], 12)
          }

          CommandWindowOutputView(state: publisher.state)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
        }
      }
      .background()
    }
    .frame(minWidth: 200)
    .roundedContainer(padding: 0, margin: 0)
  }

  @MainActor
  static func preview(_ state: CommandWindowView.CommandState, command: ScriptCommand) -> some View {
    let publisher = CommandPanelViewPublisher(state: state)
    return CommandWindowView(publisher: publisher, command: command) {
      switch publisher.state {
      case .ready:   publisher.publish(.running)
      case .running: publisher.publish(.error("ops!"))
      case .error:   publisher.publish(.done("done"))
      case .done:    publisher.publish(.ready)
      }
    }
    .padding()
  }
}

private struct CommandWindowHeaderView: View {
  let state: CommandWindowView.CommandState
  let name: String
  let action: () -> Void

  var body: some View {
    HStack {
      ScriptIconView(size: 24)
      Text(name)
        .font(.headline)
      Spacer()
      Button(action: action,
             label: {
        Text(Self.buttonText(state))
          .frame(minWidth: 80)
      })
      .buttonStyle(.zen(.init(color: Self.buttonColor(state))))
      .fixedSize()
      .animation(.easeIn, value: state)
    }
    .roundedContainer(0, padding: 8, margin: 0)
  }

  private static func buttonColor(_ state: CommandWindowView.CommandState) -> ZenColor {
    switch state {
    case .ready: .systemGray
    case .running: .accentColor
    case .error: .systemRed
    case .done: .systemGreen
    }
  }

  private static func buttonText(_ state: CommandWindowView.CommandState) -> String {
    switch state {
    case .ready: "Run"
    case .running: "Cancel"
    case .error: "Run again…"
    case .done: "Run"
    }
  }
}

private struct CommandWindowOutputView: View {
  let state: CommandWindowView.CommandState

  var body: some View {
      switch state {
      case .ready:
        Color.clear
      case .running:
        ProgressView()
          .padding()
      case .error(let contents):
        CommandWindowErrorView(contents: contents)
      case .done(let contents):
        CommandWindowSuccessView(contents: contents)
      }
  }
}

private struct CommandWindowErrorView: View {
  let contents: String

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: 4) {
          Text("[Exit Code]")
          ZenDivider(.vertical)
          Text("Error Message")
            .frame(maxWidth: .infinity, alignment: .leading)
          ErrorIconView(size: 16)
        }
        .font(.headline)
        .padding(8)
        .background(
          LinearGradient(stops: [
            .init(color: Color(.systemRed).opacity(0.4), location: 0),
            .init(color: Color(.systemRed.withSystemEffect(.disabled)).opacity(0.2), location: 1),
          ], startPoint: .top, endPoint: .bottom)
        )
        ZenDivider()
        Text(contents)
          .textSelection(.enabled)
          .fontDesign(.monospaced)
          .frame(maxWidth: .infinity, alignment: .leading)
          .font(.system(.callout))
          .padding(8)
      }
      .roundedContainer(padding: 0, margin: 4)
    }
  }
}

private struct CommandWindowSuccessView: View {
  private let searchSets = [
    SearchSet(regexPattern: { _ in "\\{|\\}|\\[|\\]|\"" },
              color: Color(.controlAccentColor.withSystemEffect(.pressed))),
    SearchSet(regexPattern: { _ in "\\d+" },
              color: Color(.systemRed.withAlphaComponent(0.7))),
  ]

  let contents: String
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 4) {
        Text("Result")
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .font(.headline)
      .padding(8)
      .background(
        LinearGradient(stops: [
          .init(color: Color(.systemGreen).opacity(0.2), location: 0),
          .init(color: Color(.systemGreen.withSystemEffect(.disabled)).opacity(0.1), location: 1),
        ], startPoint: .top, endPoint: .bottom)
      )

      ZenDivider()

      Text(AttributedString(contents).syntaxHighlight(searchSets: searchSets).linkDetector(contents))
        .textSelection(.enabled)
        .allowsTightening(true)
        .fontDesign(.monospaced)
        .frame(maxWidth: .infinity, alignment: .leading)
        .font(.system(.callout))
        .padding(8)
    }
    .roundedContainer(padding: 0, margin: 4)
  }
}

private struct CommandWindowPathView: View {
  let path: String
  var body: some View {
    HStack {
      Text("Path")
      Text(path)
      Button(action: {}, label: { Text("Open") })
      Button(action: {}, label: { Text("Reveal") })
    }
  }
}

private struct CommandWindowInlineView: View {
  @State private var contents: String

  init(contents: String) {
    self.contents = contents
  }

  var body: some View {
    ZenTextEditor(text: $contents, placeholder: "")
      .fontDesign(.monospaced)
      .frame(maxWidth: .infinity, maxHeight: 120, alignment: .leading)
      .font(.system(.callout))
      .padding(4)
      .roundedContainer(padding: 0, margin: 4)
  }
}


let prCommand = ScriptCommand(
  kind: .shellScript,
  source: .inline("gh pr ls"),
  meta: .init(name: "This is a script")
)

let prCommandResult = """
Showing 1 of 1 open pull request in zenangst/KeyboardCowboy

ID    TITLE                          BRANCH                         CREATED AT
#453  Feature Keyboard Cowboy stats  feature/keyboard-cowboy-stats  about 4 months ago
"""

let prCommandWithJQ = ScriptCommand(
  kind: .shellScript,
  source: .inline("gh pr ls --json url,title,number,headRefName,reviewDecision,changedFiles,deletions"),
  meta: .init(name: "Run GitHub CLI with jq")
)

let prCommandWithJQResult = """
[
  {
  "changedFiles": 2,
  "deletions": 0,
  "headRefName": "feature/keyboard-cowboy-stats",
  "number": 453,
  "reviewDecision": "",
  "title": "Feature Keyboard Cowboy stats",
  "url": "https://github.com/zenangst/KeyboardCowboy/pull/453"
  }
]
"""

#Preview("gh pr ls - with JQ") { CommandWindowView.preview(.done(prCommandWithJQResult), command: prCommandWithJQ) }
#Preview("gh pr ls") { CommandWindowView.preview(.done(prCommandResult), command: prCommand) }
#Preview("Error") { CommandWindowView.preview(.error("Oh shit!"), command: prCommand) }
#Preview("Ready") { CommandWindowView.preview(.ready, command: prCommand) }

extension AttributedString {
  func linkDetector(_ originalString: String) -> AttributedString {
    var attributedString = self

    let types = NSTextCheckingResult.CheckingType.link.rawValue

    guard let detector = try? NSDataDetector(types: types) else {
      return attributedString
    }

    let matches = detector.matches(
      in: originalString,
      options: [],
      range: NSRange(location: 0, length: originalString.count)
    )

    for match in matches {
      let range = match.range
      let startIndex = attributedString.index(
        attributedString.startIndex,
        offsetByCharacters: range.lowerBound
      )
      let endIndex = attributedString.index(
        startIndex,
        offsetByCharacters: range.length
      )

      switch match.resultType {
      case .link:
        if let url = match.url {
          attributedString[startIndex..<endIndex].link = url
          attributedString[startIndex..<endIndex].foregroundColor = Color(nsColor: .controlAccentColor.withSystemEffect(.deepPressed))
        }
      default:
        continue
      }

    }
    return attributedString
  }
  func syntaxHighlight(searchSets: [SearchSet]) -> AttributedString {
    var attrInText: AttributedString = self

    searchSets.forEach { searchSet in
      searchSet.words?.forEach({ word in
        guard let regex = try? Regex<Substring>(searchSet.regexPattern(word))
        else {
          fatalError("Failed to create regular expession")
        }
        processMatches(attributedText: &attrInText,
                       regex: regex,
                       color: searchSet.color)
      })
    }

    return attrInText
  }

  private func processMatches(attributedText: inout AttributedString,
                              regex: Regex<Substring>,
                              color: Color) {
    let orignalText: String = (
      attributedText.characters.compactMap { c in
        String(c)
      } as [String]).joined()

    orignalText.matches(of: regex).forEach { match in
      if let swiftRange = Range(match.range, in: attributedText) {
        attributedText[swiftRange].foregroundColor = NSColor(color)
      }
    }
  }
}

struct SearchSet {
  let words: [String]?
  let regexPattern: (String) -> String
  let color: Color

  init(words: [String]? = nil,
       regexPattern: @escaping (String) -> String,
       color: Color) {
    self.words = words ?? [""]
    self.regexPattern = regexPattern
    self.color = color
  }
}
