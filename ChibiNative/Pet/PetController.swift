import AppKit
import Foundation

/// State machine + interaction — port of PetLayer.tsx.
/// Uses a pet-sized floating panel (not fullscreen overlay).
final class PetController: ChatControllerDelegate {
  private let overlay: OverlayWindow
  private let petView: PetView
  private var roam: RoamController!
  private var desktop: VirtualDesktop
  private var monitors: [MonitorRegion] = []
  private let chatController = ChatController()
  private let idleTimer = IdleTimer()

  private var pos = CGPoint.zero
  private var userMoved = false
  private var visualState: CatVisualState = .idle
  private var headingLeft = false
  private var pokeTimer: Timer?
  private var isChatBusy = false

  private struct Track {
    var startLocalX: CGFloat
    var startLocalY: CGFloat
    var startT: CFTimeInterval
    var grabLocalX: CGFloat
    var grabLocalY: CGFloat
    var dragging: Bool
  }

  private var track: Track?

  init(overlay: OverlayWindow) {
    self.overlay = overlay
    self.desktop = ScreenLayout.capture()
    self.monitors = desktop.monitors
    self.petView = PetView(
      frame: CGRect(x: 0, y: 0, width: PetConstants.displayWidth, height: PetConstants.displayHeight)
    )
    overlay.content.addSubview(petView)
    petView.autoresizingMask = [.width, .height]

    petView.onMouseDown = { [weak self] pt in self?.handleMouseDown(pt) }
    petView.onMouseDragged = { [weak self] pt in self?.handleMouseDragged(pt) }
    petView.onMouseUp = { [weak self] pt in self?.handleMouseUp(pt) }
    petView.onRightMouseDown = { [weak self] _ in self?.handleRightClick() }

    chatController.delegate = self
    configureIdleTimer()
  }

  func start() {
    APNGCache.shared.preloadHot()

    let spawn = ScreenLayout.spawnVisible(on: desktop)
    pos = spawn
    applyTransform()
    // Force absolute place on menu-bar screen floor (bypasses any web-coord drift).
    overlay.placeOnPrimaryFloor()
    // Keep `pos` in sync with the forced placement.
    let panel = overlay.frame
    pos = desktop.webPoint(fromAppKit: NSPoint(x: panel.minX, y: panel.maxY))
    playCurrentAsset(restart: true)
    petView.apngView.setContentsScale(overlay.backingScaleFactor)
    syncHitRegion()

    roam = RoamController(hooks: RoamController.Hooks(
      getPos: { [weak self] in self?.pos ?? .zero },
      setPos: { [weak self] x, y in
        guard let self else { return }
        self.pos = CGPoint(x: x, y: y)
        self.applyTransform()
      },
      getMonitors: { [weak self] in self?.monitors ?? [] },
      onRoamStart: { [weak self] left in
        guard let self else { return }
        self.headingLeft = left
        self.setVisualState(.roam)
      },
      onRoamEnd: { [weak self] in
        guard let self else { return }
        if self.visualState == .roam {
          self.setVisualState(.idle)
        }
      },
      isAllowed: { [weak self] in
        guard let self else { return false }
        return !self.isChatBusy && (self.visualState == .idle || self.visualState == .roam)
      }
    ))
    roam.onIdle()
    idleTimer.start()
  }

  func handleScreenChange() {
    desktop = ScreenLayout.capture()
    monitors = desktop.monitors
    petView.apngView.setContentsScale(overlay.backingScaleFactor)
    if !userMoved {
      pos = ScreenLayout.spawnVisible(on: desktop)
    }
    applyTransform()
  }

  func dispose() {
    pokeTimer?.invalidate()
    idleTimer.stop()
    roam?.dispose()
    chatController.hide()
    petView.apngView.stop()
  }

  // MARK: - ChatControllerDelegate

  func chatDidStartStreaming() {
    isChatBusy = true
    noteInteraction()
    setVisualState(.working)
  }

  func chatDidFinishStreaming() {
    isChatBusy = false
    if visualState == .working {
      setVisualState(.idle)
    }
  }

  func chatDidFail(_ message: String) {
    isChatBusy = false
    setVisualState(.error, autoIdleMs: Theme.errorDurationMs)
  }

  func chatDidInteract() {
    noteInteraction()
  }

  // MARK: - Idle / sleep chain

  private func configureIdleTimer() {
    idleTimer.timings = IdleTimer.Timings(
      yawnAfterIdleMs: Theme.mouseIdleTimeoutMs,
      yawnDurationMs: Theme.yawnDurationMs,
      sleepAfterDozeMs: Theme.mouseSleepTimeoutMs,
      wakeDurationMs: Theme.wakeDurationMs
    )
    idleTimer.onEnterYawning = { [weak self] in self?.setVisualState(.yawning) }
    idleTimer.onEnterDozing = { [weak self] in self?.setVisualState(.dozing) }
    idleTimer.onEnterSleeping = { [weak self] in self?.setVisualState(.sleeping) }
    idleTimer.onEnterWaking = { [weak self] in self?.setVisualState(.waking) }
    idleTimer.onReturnIdle = { [weak self] in self?.setVisualState(.idle) }
  }

  private func noteInteraction() {
    idleTimer.noteInteraction()
    if visualState == .sleeping || visualState == .dozing || visualState == .yawning {
      // IdleTimer drives waking → idle; avoid fighting its timers.
      return
    }
  }

  // MARK: - State / visual

  private func setVisualState(_ state: CatVisualState, autoIdleMs: Int? = nil) {
    visualState = state
    pokeTimer?.invalidate()
    pokeTimer = nil
    playCurrentAsset(restart: true)
    syncHitRegion()

    if let ms = autoIdleMs {
      pokeTimer = Timer.scheduledTimer(withTimeInterval: Double(ms) / 1000.0, repeats: false) { [weak self] _ in
        self?.setVisualState(.idle)
      }
      if let t = pokeTimer { RunLoop.main.add(t, forMode: .common) }
    }

    let busy = state != .idle && state != .roam
      && state != .yawning && state != .dozing && state != .sleeping && state != .waking
    idleTimer.setBusy(busy || isChatBusy)

    if state == .idle && !isChatBusy {
      roam?.onIdle()
    } else if state != .roam {
      roam?.onBusy()
    }
  }

  private func playCurrentAsset(restart: Bool) {
    let file = Theme.fileForState(visualState)
    let flip = visualState == .roam && headingLeft != Theme.roamFlipAssets
    petView.apngView.play(file: file, flipX: flip, restart: restart)
  }

  private func applyTransform() {
    overlay.placePet(webOrigin: pos, desktop: desktop)
    syncHitRegion()
  }

  private func syncHitRegion() {
    let box = Theme.hitBoxForState(visualState)
    overlay.updatePetHitRectLocal(box.cgRect)
  }

  // MARK: - Mouse (pet-local coords → web pos)

  private func handleMouseDown(_ local: NSPoint) {
    noteInteraction()
    if visualState == .roam {
      roam?.cancel()
    }
    if visualState == .sleeping || visualState == .dozing || visualState == .yawning {
      // Wake instead of starting a drag/click; IdleTimer already began waking.
      return
    }
    overlay.setInteracting(true)
    track = Track(
      startLocalX: local.x,
      startLocalY: local.y,
      startT: CACurrentMediaTime(),
      grabLocalX: local.x,
      grabLocalY: local.y,
      dragging: false
    )
  }

  private func handleMouseDragged(_ local: NSPoint) {
    guard var t = track else { return }
    let mouse = NSEvent.mouseLocation // AppKit screen
    let web = desktop.webPoint(fromAppKit: mouse)

    if !t.dragging {
      if hypot(local.x - t.startLocalX, local.y - t.startLocalY) <= PetConstants.dragThresholdPx {
        return
      }
      t.dragging = true
      userMoved = true
      pokeTimer?.invalidate()
      pokeTimer = nil
      setVisualState(.drag)
    }
    // Keep grab offset in pet-local space.
    pos = CGPoint(x: web.x - t.grabLocalX, y: web.y - t.grabLocalY)
    track = t
    applyTransform()
  }

  private func handleMouseUp(_ local: NSPoint) {
    guard let t = track else { return }
    track = nil
    overlay.setInteracting(false)

    if t.dragging {
      setVisualState(.idle)
      return
    }

    let dt = (CACurrentMediaTime() - t.startT) * 1000
    let dist = hypot(local.x - t.startLocalX, local.y - t.startLocalY)
    if dt <= PetConstants.clickMaxMs && dist <= PetConstants.dragThresholdPx {
      noteInteraction()
      chatController.toggle(nearPetFrame: overlay.frame)
    }
  }

  private func handleRightClick() {
    noteInteraction()
    if visualState == .roam {
      roam?.cancel()
    }
    if visualState == .sleeping || visualState == .dozing || visualState == .yawning {
      return
    }
    setVisualState(.poke, autoIdleMs: Theme.pokeDurationMs)
  }
}
