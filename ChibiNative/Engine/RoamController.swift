import AppKit
import Foundation
import QuartzCore

/// Free roam — wander across the desk when idle long enough. Port of roam.ts.
final class RoamController: DisplayTickClient {
  private static let idleDelayMs: TimeInterval = 6.0
  private static let betweenDelayMs: TimeInterval = 4.5
  private static let speedPxPerMs: CGFloat = 0.08
  private static let minDist: CGFloat = 180
  private static let maxDist: CGFloat = 520
  private static let marginRatio: CGFloat = 0.1
  private static let targetAttempts = 16
  private static let floorBand: CGFloat = 56

  struct Hooks {
    var getPos: () -> CGPoint
    var setPos: (CGFloat, CGFloat) -> Void
    var getMonitors: () -> [MonitorRegion]
    var onRoamStart: (Bool) -> Void
    var onRoamEnd: () -> Void
    var isAllowed: () -> Bool
  }

  private let hooks: Hooks
  private(set) var enabled = true
  private(set) var active = false
  private var firstRoam = true
  private var pauseTimer: Timer?
  private var ticking = false
  private var animStart: CGPoint = .zero
  private var animDx: CGFloat = 0
  private var animDy: CGFloat = 0
  private var animDuration: CFTimeInterval = 0
  private var animT0: CFTimeInterval = 0

  init(hooks: Hooks) {
    self.hooks = hooks
  }

  func setEnabled(_ value: Bool) {
    guard value != enabled else { return }
    enabled = value
    if !enabled {
      cancel()
    } else {
      firstRoam = true
    }
  }

  func cancel() {
    let wasActive = active
    cleanupTimers()
    active = false
    if wasActive { hooks.onRoamEnd() }
  }

  func onIdle() {
    guard enabled else { return }
    if active || pauseTimer != nil { return }
    scheduleNext()
  }

  func onBusy() {
    firstRoam = true
    cancel()
  }

  func dispose() {
    enabled = false
    cancel()
  }

  // MARK: - Private

  private func cleanupTimers() {
    pauseTimer?.invalidate()
    pauseTimer = nil
    stopTick()
  }

  private func scheduleNext() {
    pauseTimer?.invalidate()
    pauseTimer = nil
    guard enabled else { return }
    let delay = firstRoam ? Self.idleDelayMs : Self.betweenDelayMs
    firstRoam = false
    pauseTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
      guard let self else { return }
      self.pauseTimer = nil
      if !self.enabled || !self.hooks.isAllowed() {
        self.firstRoam = true
        return
      }
      let pos = self.hooks.getPos()
      if let target = Self.pickTarget(x: pos.x, y: pos.y, monitors: self.hooks.getMonitors()) {
        self.animateTo(targetX: target.x, targetY: target.y)
      } else {
        self.firstRoam = false
        self.pauseTimer = Timer.scheduledTimer(withTimeInterval: Self.betweenDelayMs, repeats: false) { [weak self] _ in
          self?.pauseTimer = nil
          self?.scheduleNext()
        }
        if let t = self.pauseTimer {
          RunLoop.main.add(t, forMode: .common)
        }
      }
    }
    if let t = pauseTimer {
      RunLoop.main.add(t, forMode: .common)
    }
  }

  private func animateTo(targetX: CGFloat, targetY: CGFloat) {
    cleanupTimers()
    let start = hooks.getPos()
    let dx = targetX - start.x
    let dy = targetY - start.y
    let dist = hypot(dx, dy)
    let durationMs = max(1000.0, Double(dist) / Double(Self.speedPxPerMs))
    animDuration = durationMs / 1000.0

    hooks.onRoamStart(dx < 0)
    active = true
    animStart = start
    animDx = dx
    animDy = dy
    animT0 = CACurrentMediaTime()
    startTick()
  }

  func displayTick(now: CFTimeInterval) {
    guard active else { return }
    if !hooks.isAllowed() {
      active = false
      firstRoam = true
      stopTick()
      hooks.onRoamEnd()
      return
    }
    let t = min(1.0, (now - animT0) / animDuration)
    let eased = t * (2 - t)
    hooks.setPos(
      round(animStart.x + animDx * CGFloat(eased)),
      round(animStart.y + animDy * CGFloat(eased))
    )
    if t >= 1 {
      active = false
      stopTick()
      hooks.onRoamEnd()
      scheduleNext()
    }
  }

  private func startTick() {
    guard !ticking else { return }
    ticking = true
    DisplayTicker.shared.add(self)
  }

  private func stopTick() {
    guard ticking else { return }
    ticking = false
    DisplayTicker.shared.remove(self)
  }

  static func pickTarget(x: CGFloat, y: CGFloat, monitors: [MonitorRegion]) -> CGPoint? {
    guard !monitors.isEmpty else { return nil }

    let cx = x + PetConstants.displayWidth / 2
    let cy = y + PetConstants.displayHeight / 2
    let wa =
      monitors.first(where: { cx >= $0.left && cx <= $0.right && cy >= $0.top && cy <= $0.bottom })
      ?? monitors.first(where: \.primary)
      ?? monitors[0]

    let marginX = round((wa.right - wa.left) * marginRatio)
    let floorY = wa.floorY - PetConstants.displayHeight
    let xMin = wa.left + marginX
    let xMax = wa.right - PetConstants.displayWidth - marginX
    guard xMax > xMin else { return nil }

    let yMin = max(wa.top, floorY - floorBand)
    let yMax = floorY

    for _ in 0..<targetAttempts {
      let tx = xMin + CGFloat(Int.random(in: 0...Int(xMax - xMin)))
      let t = CGFloat.random(in: 0...1)
      let ty: CGFloat =
        yMax > yMin ? round(yMin + (yMax - yMin) * (1 - t * t)) : floorY
      let dist = hypot(tx - x, ty - y)
      if dist >= minDist && dist <= maxDist {
        return CGPoint(x: tx, y: ty)
      }
    }

    let dir: CGFloat = Bool.random() ? -1 : 1
    let hop = minDist + CGFloat(Int.random(in: 0...Int((maxDist - minDist) * 0.5)))
    let tx = min(xMax, max(xMin, x + dir * hop))
    if abs(tx - x) < 8 { return nil }
    return CGPoint(x: tx, y: floorY)
  }
}
