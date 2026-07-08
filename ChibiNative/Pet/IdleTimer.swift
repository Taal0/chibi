import Foundation

/// Tracks AFK time and drives the sleep animation chain.
final class IdleTimer {
  struct Timings {
    var yawnAfterIdleMs: Int = 20_000
    var yawnDurationMs: Int = 8_000
    var sleepAfterDozeMs: Int = 60_000
    var wakeDurationMs: Int = 6_000
  }

  enum Phase {
    case active
    case awaitingYawn
    case yawning
    case dozing
    case sleeping
    case waking
  }

  var onEnterYawning: (() -> Void)?
  var onEnterDozing: (() -> Void)?
  var onEnterSleeping: (() -> Void)?
  var onEnterWaking: (() -> Void)?
  var onReturnIdle: (() -> Void)?

  private(set) var phase: Phase = .active
  var timings: Timings
  private var lastInteraction = Date()
  private var pollTimer: Timer?
  private var phaseTimer: Timer?

  init(timings: Timings = Timings()) {
    self.timings = timings
  }

  func start() {
    lastInteraction = Date()
    phase = .awaitingYawn
    pollTimer?.invalidate()
    let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
      self?.tick()
    }
    RunLoop.main.add(timer, forMode: .common)
    pollTimer = timer
  }

  func stop() {
    pollTimer?.invalidate()
    pollTimer = nil
    phaseTimer?.invalidate()
    phaseTimer = nil
    phase = .active
  }

  /// Call on any user interaction (click, chat, drag, poke).
  func noteInteraction() {
    lastInteraction = Date()
    phaseTimer?.invalidate()
    phaseTimer = nil

    switch phase {
    case .sleeping, .dozing, .yawning:
      beginWaking()
    case .waking:
      break
    case .active, .awaitingYawn:
      phase = .awaitingYawn
    }
  }

  /// Pause AFK progression while busy (working / drag / poke / roam).
  func setBusy(_ busy: Bool) {
    if busy {
      phaseTimer?.invalidate()
      phaseTimer = nil
      if phase == .awaitingYawn || phase == .active {
        phase = .active
      }
    } else if phase == .active || phase == .awaitingYawn {
      lastInteraction = Date()
      phase = .awaitingYawn
    }
  }

  private func tick() {
    guard phase == .awaitingYawn else { return }
    let idleMs = Int(Date().timeIntervalSince(lastInteraction) * 1000)
    if idleMs >= timings.yawnAfterIdleMs {
      beginYawning()
    }
  }

  private func beginYawning() {
    phase = .yawning
    onEnterYawning?()
    schedule(ms: timings.yawnDurationMs) { [weak self] in
      guard let self, self.phase == .yawning else { return }
      self.beginDozing()
    }
  }

  private func beginDozing() {
    phase = .dozing
    lastInteraction = Date()
    onEnterDozing?()
    schedule(ms: timings.sleepAfterDozeMs) { [weak self] in
      guard let self, self.phase == .dozing else { return }
      self.phase = .sleeping
      self.onEnterSleeping?()
    }
  }

  private func beginWaking() {
    phase = .waking
    onEnterWaking?()
    schedule(ms: timings.wakeDurationMs) { [weak self] in
      guard let self, self.phase == .waking else { return }
      self.lastInteraction = Date()
      self.phase = .awaitingYawn
      self.onReturnIdle?()
    }
  }

  private func schedule(ms: Int, block: @escaping () -> Void) {
    phaseTimer?.invalidate()
    let timer = Timer(timeInterval: Double(ms) / 1000.0, repeats: false) { _ in block() }
    RunLoop.main.add(timer, forMode: .common)
    phaseTimer = timer
  }
}
