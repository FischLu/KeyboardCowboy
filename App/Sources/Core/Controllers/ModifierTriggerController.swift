import Cocoa
import Combine
import MachPort

final class ModifierTriggerController: @unchecked Sendable {
  enum State: Sendable {
    case idle
    case keyDown(ModifierTrigger.Kind, held: Bool)

    fileprivate var debugId: String {
      switch self {
      case .idle: "idle"
      case .keyDown(_, let held): "keyDown(\(held))"
      }
    }
  }

  nonisolated(unsafe) static fileprivate var debug: Bool = false

  var machPort: MachPortEventController? {
    willSet {
      if let machPort = newValue  {
        coordinator = ModifierTriggerMachPortCoordinator(machPort: machPort)
      }
    }
  }
  var coordinator: ModifierTriggerMachPortCoordinator?

  private var lastEventTime: Double = 0
  private var workflowGroupsSubscription: AnyCancellable?
  private var cache: [String: ModifierTrigger] = [:]
  private var state: State = .idle
//  {
//    willSet { print("🍒 state: ", state.debugId, newValue.debugId) }
//  }
  private var currentTrigger: ModifierTrigger?
//  {
//    willSet { print("🔫 currentTrigger:", currentTrigger?.id, "==", newValue?.id) }
//  }
  private var workItem: DispatchWorkItem?

  func subscribe(to publisher: Published<[WorkflowGroup]>.Publisher) {
    workflowGroupsSubscription = publisher.sink { [weak self] groups in
      guard let self else { return }
      self.cache(groups)
    }
  }

  @MainActor
  func handleIfApplicable(_ machPortEvent: MachPortEvent) {
    guard let coordinator, !cache.isEmpty else { return }

    workItem?.cancel()

    switch state {
    case .idle:
      handleIdle(machPortEvent, coordinator: coordinator)
    case .keyDown:
      guard let currentTrigger else {
        reset()
        return
      }

      if machPortEvent.event.type == .keyDown {
        handleKeyDown(machPortEvent, coordinator: coordinator, currentTrigger: currentTrigger)
      } else if machPortEvent.event.type == .flagsChanged {
        handleKeyDown(machPortEvent, coordinator: coordinator, currentTrigger: currentTrigger)
      } else if machPortEvent.event.type == .keyUp {
        workItem?.cancel()
        handleKeyUp(machPortEvent, coordinator: coordinator, currentTrigger: currentTrigger)
      }
    }
  }

  func cache(_ groups: [WorkflowGroup]) {
    // MARK: Demo modifiers
    do {
      let key = KeyShortcut.escape
      let signature = CGEventSignature(Int64(key.keyCode!), .maskNonCoalesced)
      let keySignature = createKey(signature: signature, bundleIdentifier: "*", userModeKey: "")
      cache[keySignature] = ModifierTrigger(
        id: keySignature,
        key: key,
        manipulator: ModifierTrigger.Manipulator(
          alone: .init(kind: .key(key), timeout: 100),
          heldDown: .init(kind: .modifiers([.leftControl]), threshold: 75)
        )
      )
    }

    do {
      let key = KeyShortcut.tab
      let signature = CGEventSignature(Int64(key.keyCode!), .maskNonCoalesced)
      let keySignature = createKey(signature: signature, bundleIdentifier: "*", userModeKey: "")
      cache[keySignature] = ModifierTrigger(
        id: keySignature,
        key: key,
        manipulator: ModifierTrigger.Manipulator(
          alone: .init(kind: .key(key), timeout: 100),
          heldDown: .init(kind: .modifiers([.function]), threshold: 75)
        )
      )
    }

    for group in groups where !group.isDisabled {
      let bundleIdentifiers: [String]
      if let rule = group.rule {
        bundleIdentifiers = rule.bundleIdentifiers
      } else {
        bundleIdentifiers = ["*"]
      }

      bundleIdentifiers.forEach { bundleIdentifier in
        for workflow in group.workflows where workflow.isEnabled {
          guard case .modifier(let trigger) = workflow.trigger else { continue }

          let flags = CGEventFlags.maskNonCoalesced
          guard let resolvedKeyCode = trigger.key.keyCode else { continue }

          let keyCode: Int64 = Int64(resolvedKeyCode)
          let signature = CGEventSignature(keyCode, flags)
          let key = createKey(signature: signature,
                              bundleIdentifier: bundleIdentifier,
                              userModeKey: "")
          cache[key] = trigger

          let userModes = group.userModes
          for userMode in userModes {
            let userModeKey: String = userMode.dictionaryKey(true)
            let key = createKey(signature: signature,
                                bundleIdentifier: bundleIdentifier,
                                userModeKey: userModeKey)
            cache[key] = trigger
          }
        }
      }
    }
  }

  // MARK: Private methods

  @MainActor
  private func handleIdle(_ machPortEvent: MachPortEvent,
                          coordinator: ModifierTriggerMachPortCoordinator) {
    guard machPortEvent.type == .keyDown else { return }

    let event = machPortEvent.event
    let signature = CGEventSignature(event.getIntegerValueField(.keyboardEventKeycode), event.flags)
    let trigger = lookup(signature)

    guard let trigger else { return }

    if let heldDown = trigger.manipulator.heldDown {
      lastEventTime = convertTimestampToMilliseconds(DispatchTime.now().uptimeNanoseconds)
      state = .keyDown(heldDown.kind, held: true)
      handleKeyDown(machPortEvent, coordinator: coordinator, currentTrigger: trigger)
    } else {
      state = .keyDown(trigger.manipulator.alone.kind, held: false)
    }

    currentTrigger = trigger
    machPortEvent.result = nil
  }

  private func handleKeyDown(_ machPortEvent: MachPortEvent,
                             coordinator: ModifierTriggerMachPortCoordinator,
                             currentTrigger: ModifierTrigger) {
    switch state {
    case .keyDown(let kind, _):
      switch kind {
      case .key(let key):
        coordinator
          .post(key)
          .set(key, on: machPortEvent)
          .discardSystemEvent(on: machPortEvent)

      case .modifiers(let modifiers):
        if machPortEvent.keyCode == currentTrigger.key.keyCode! {
          coordinator
            .discardSystemEvent(on: machPortEvent)

          guard !machPortEvent.isRepeat else { return }

          workItem = startTimer(delay: Int(currentTrigger.manipulator.alone.threshold), currentTrigger: currentTrigger) { [weak self, coordinator] trigger in
            guard let self else { return }
            coordinator
              .postFlagsChanged(modifiers: modifiers)
            lastEventTime = convertTimestampToMilliseconds(DispatchTime.now().uptimeNanoseconds)
          }
        } else {
          coordinator.decorateEvent(machPortEvent, with: modifiers)
        }
      }
    case .idle: break
    }
  }

  private func handleKeyUp(_ machPortEvent: MachPortEvent,
                           coordinator: ModifierTriggerMachPortCoordinator,
                           currentTrigger: ModifierTrigger) {
    switch state {
    case .keyDown(let kind, let held):
      switch kind {
      case .key(let key):
        coordinator
          .post(key)
          .set(key, on: machPortEvent)
          .discardSystemEvent(on: machPortEvent)
      case .modifiers(let modifiers):
        let currentTimestamp = convertTimestampToMilliseconds(DispatchTime.now().uptimeNanoseconds)
        let elapsedTime = currentTimestamp - lastEventTime

        if held, currentTrigger.manipulator.alone.threshold >= elapsedTime {
          coordinator.post(currentTrigger.key)
          reset()
          workItem?.cancel()
          return
        }

        if machPortEvent.keyCode == currentTrigger.key.keyCode! {
          coordinator
            .discardSystemEvent(on: machPortEvent)
            .postMaskNonCoalesced()
        } else {
          coordinator.decorateEvent(machPortEvent, with: modifiers)
          debugModifier("\(machPortEvent.keyCode), \(machPortEvent.event.flags)")
          return
        }

        coordinator.setMaskNonCoalesced(on: machPortEvent)
      }
    case .idle:
      break
    }

    reset()
  }

  func convertTimestampToMilliseconds(_ timestamp: UInt64) -> Double {
    return Double(timestamp) / 1_000_000 // Convert nanoseconds to milliseconds
  }

  private func reset() {
    self.state = .idle
    self.workItem?.cancel()
    self.workItem = nil
    self.currentTrigger = nil
  }

  private func startTimer(delay: Int, currentTrigger: ModifierTrigger,
                          completion: @Sendable @escaping (ModifierTrigger) -> Void) -> DispatchWorkItem {
    let deadline = DispatchTime.now() + .milliseconds(delay)
    let item = DispatchWorkItem(block: { completion(currentTrigger) })
    DispatchQueue.main.asyncAfter(deadline: deadline, execute: item)
    return item
  }

  @MainActor
  private func lookup(_ signature: CGEventSignature) -> ModifierTrigger? {
    let bundleIdentifiers: [String]

    if let frontmostApplication = NSWorkspace.shared.frontmostApplication,
       let bundleIdentifier = frontmostApplication.bundleIdentifier {
      bundleIdentifiers = [bundleIdentifier, "*"]
    } else {
      bundleIdentifiers = ["*"]
    }

    var trigger: ModifierTrigger?
    outer: for bundleIdentifier in bundleIdentifiers {
      let key = createKey(signature: signature, bundleIdentifier: bundleIdentifier, userModeKey: "")

      if let resolved = cache[key] {
        trigger = resolved
        break outer
      }

      for userMode in UserSpace.shared.userModes {
        let userModeKey = userMode.dictionaryKey(true)
        let key = createKey(signature: signature, bundleIdentifier: bundleIdentifier, userModeKey: userModeKey)
        if let resolved = cache[key] {
          trigger = resolved
          break outer
        }
      }
    }

    return trigger
  }

  private func createKey(signature: CGEventSignature,
                         bundleIdentifier: String,
                         userModeKey: String) -> String {
    let userModeKey = userModeKey.isEmpty ? "" : ".\(userModeKey)"
    return "\(bundleIdentifier).\(userModeKey)\(signature.id)"
  }
}

fileprivate func debugModifier(_ handler: @autoclosure @escaping () -> String, function: StaticString = #function, line: UInt = #line) {
  guard ModifierTriggerController.debug else { return }

  let dateFormatter = DateFormatter()
  dateFormatter.dateStyle = .short
  dateFormatter.timeStyle = .short

  let formattedDate = dateFormatter.string(from: Date())

  print(formattedDate, function, line, handler())
}
