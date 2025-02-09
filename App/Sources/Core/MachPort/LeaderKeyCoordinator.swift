import CoreGraphics
import Foundation
import MachPort

@MainActor
protocol LeaderKeyCoordinatorDelegate: AnyObject {
  func changedState(_ state: LeaderKeyCoordinator.State?)
  func didResignLeader()
}

@MainActor
final class LeaderKeyCoordinator: @unchecked Sendable {
  weak var delegate: LeaderKeyCoordinatorDelegate?
  @MainActor var machPort: MachPortEventController?

  enum State {
    case idle
    case event(_ kind: Kind, holdDuration: Double)

    enum Kind {
      case fallback
      case leader
    }
  }

  private let defaultPartialMatch: PartialMatch
  private var leaderKeyWorkItem: DispatchWorkItem?
  private(set) var state: State = .idle
  private var lastEventTime: Double = 0
  private var switchedEvents: [Int64: Int64] = [Int64: Int64]()

  private var leaderEvent: MachPortEvent? {
    willSet {
      previousLeader = leaderEvent
    }
  }
  private var previousLeader: MachPortEvent?

  init(defaultPartialMatch: PartialMatch = .default()) {
    self.state = .idle
    self.defaultPartialMatch = defaultPartialMatch
  }

  func isLeader(_ event: MachPortEvent) -> Bool {
    if let leaderEvent {
      return  event.keyCode == leaderEvent.keyCode && event.flags == leaderEvent.flags
    } else if let previousLeader {
      return event.keyCode == previousLeader.keyCode && event.flags == previousLeader.flags
    }

    return false
  }

  @MainActor
  func handlePartialMatchIfApplicable(_ partialMatch: PartialMatch?, machPortEvent: MachPortEvent) -> Bool {
    leaderKeyWorkItem?.cancel()

    switch state {
    case .idle:
      return handleIdle(partialMatch, machPortEvent: machPortEvent)
    case .event(let kind, let holdDuration):
      guard let leaderEvent else {
        reset()
        return false
      }

      if !isLeader(machPortEvent), let partialMatch, condition(partialMatch) != nil {
        postKeyDownAndUp(leaderEvent)
        self.leaderEvent = machPortEvent
      }

      if machPortEvent.event.type == .keyDown {
        handleKeyDown(kind, newEvent: machPortEvent, leaderEvent: leaderEvent, holdDuration: holdDuration)
      } else if machPortEvent.event.type == .flagsChanged {
        leaderKeyWorkItem?.cancel()
        handleKeyDown(kind, newEvent: machPortEvent, leaderEvent: leaderEvent, holdDuration: holdDuration)
      } else if machPortEvent.event.type == .keyUp {
        leaderKeyWorkItem?.cancel()
        handleKeyUp(kind, newEvent: machPortEvent, leaderEvent: leaderEvent, holdDuration: holdDuration)
      }

      return true
    }
  }

  // MARK: Private methods

  private func handleIdle(_ partialMatch: PartialMatch?, machPortEvent: MachPortEvent) -> Bool {
    guard let partialMatch, let (_, holdDuration) = condition(partialMatch) else {
      return false
    }
    self.leaderEvent = machPortEvent
    state = .event(.fallback, holdDuration: holdDuration)
    handleKeyDown(.fallback, newEvent: machPortEvent,
                  leaderEvent: machPortEvent,
                  holdDuration: holdDuration)
    machPortEvent.result = nil
    return true
  }

  private func handleKeyDown(_ kind: State.Kind,
                             newEvent: MachPortEvent,
                             leaderEvent: MachPortEvent,
                             holdDuration: Double) {
    guard !newEvent.isRepeat else { return }

    guard isLeader(newEvent) else {
      if case .event(let kind, _) = state,
         kind == .fallback {
        switchedEvents[leaderEvent.keyCode] = newEvent.keyCode
        newEvent.set(leaderEvent.keyCode, type: .keyUp)
        newEvent.result = nil
        leaderKeyWorkItem?.cancel()
        resetTime()
      }
      return
    }
    resetTime()
    let delay = max(Int(holdDuration * 1_000), 125)
    leaderKeyWorkItem = startTimer(delay: delay) { [weak self] in
      guard self != nil else { return }
      let newState = State.event(.leader, holdDuration: holdDuration)
      self?.state = newState
      self?.delegate?.changedState(newState)
    }

    newEvent.result = nil
  }

  private func handleKeyUp(_ kind: State.Kind,
                           newEvent: MachPortEvent,
                           leaderEvent: MachPortEvent,
                           holdDuration: Double) {
    if isLeader(newEvent) {
      switch kind {
      case .fallback:
        if let keyCode = switchedEvents[leaderEvent.keyCode] {
          newEvent.set(keyCode, type: .keyDown)
          postKeyDownAndUp(newEvent)
          switchedEvents[leaderEvent.keyCode] = nil
        } else {
          postKeyDownAndUp(newEvent)
        }
        delegate?.changedState(state)
        self.reset()
      case .leader:
        let currentTimestamp = Self.convertTimestampToMilliseconds(DispatchTime.now().uptimeNanoseconds)
        let elapsedTime = currentTimestamp - lastEventTime
        let threshold = holdDuration * 1_000

        if threshold <= elapsedTime { } else  {
          postKeyDownAndUp(newEvent)
        }

        reset()
        delegate?.changedState(nil)
        delegate?.didResignLeader()
      }
    } else {
      if let keyCode = switchedEvents[leaderEvent.keyCode], newEvent.keyCode == keyCode {
        newEvent.set(keyCode, type: .keyDown)
        postKeyDownAndUp(newEvent)
      }
    }
  }

  private func condition(_ partialMatch: PartialMatch) -> (workflow: Workflow, holdDuration: Double)? {
    if let workflow = partialMatch.workflow,
       workflow.machPortConditions.hasHoldForDelay,
       case .keyboardShortcuts(let keyboardShortcut) = workflow.trigger,
       partialMatch.rawValue != defaultPartialMatch.rawValue,
       let holdDuration = keyboardShortcut.holdDuration, holdDuration > 0 {
      return (workflow: workflow, holdDuration: holdDuration)
    }
    return nil
  }

  func reset() {
    self.state = .idle
    self.leaderKeyWorkItem?.cancel()
    self.leaderKeyWorkItem = nil
    self.leaderEvent = nil
    self.previousLeader = nil
  }

  private func resetTime() {
    lastEventTime = Self.convertTimestampToMilliseconds(DispatchTime.now().uptimeNanoseconds)
  }

  private func startTimer(delay: Int, completion: @MainActor @Sendable @escaping () -> Void) -> DispatchWorkItem {
    let deadline = DispatchTime.now() + .milliseconds(delay)
    let item = DispatchWorkItem(block: { completion() })
    DispatchQueue.main.asyncAfter(deadline: deadline, execute: item)
    return item
  }

  nonisolated static func convertTimestampToMilliseconds(_ timestamp: UInt64) -> Double {
    return Double(timestamp) / 1_000_000 // Convert nanoseconds to milliseconds
  }

  private func postKeyDownAndUp(_ event: MachPortEvent) {
    if let result = event.result {
      result.takeUnretainedValue().type = .keyDown
    } else {
      _ = try? machPort?.post(Int(event.keyCode), type: .keyDown, flags: event.flags)
    }
    _ = try? machPort?.post(Int(event.keyCode), type: .keyUp, flags: event.flags)
  }
}

extension MachPortEvent {
  func set(_ keyCode: Int64, type: CGEventType) {
    result?.takeUnretainedValue().setIntegerValueField(.keyboardEventKeycode, value: keyCode)
    result?.takeUnretainedValue().type = type
  }
}
