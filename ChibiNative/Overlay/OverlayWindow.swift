import AppKit

final class OverlayContentView: NSView {
  override var isFlipped: Bool { true }
  override var isOpaque: Bool { false }

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError() }

  override func hitTest(_ point: NSPoint) -> NSView? {
    let hit = super.hitTest(point)
    return hit === self ? nil : hit
  }
}

/// Pet-sized (330×248) floating panel. Transparent; click-through when cursor
/// is outside the theme hit box (same silhouette as the web pet).
final class OverlayWindow: NSPanel {
  private(set) var content: OverlayContentView!
  private var petHitRectLocal: CGRect = .zero
  private var pollTimer: Timer?
  private var interacting = false
  private var lastIgnore: Bool?

  init() {
    super.init(
      contentRect: NSRect(x: 0, y: 0, width: PetConstants.displayWidth, height: PetConstants.displayHeight),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    isOpaque = false
    backgroundColor = .clear
    hasShadow = false
    level = .statusBar
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    isMovableByWindowBackground = false
    hidesOnDeactivate = false
    becomesKeyOnlyIfNeeded = true
    ignoresMouseEvents = false
    alphaValue = 1

    let view = OverlayContentView(frame: NSRect(
      x: 0, y: 0,
      width: PetConstants.displayWidth,
      height: PetConstants.displayHeight
    ))
    content = view
    contentView = view

    applyIgnore(false)
    startCursorPoll()
  }

  deinit { pollTimer?.invalidate() }

  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }

  func placePet(webOrigin: CGPoint, desktop: VirtualDesktop) {
    let appKitX = desktop.originAppKit.x + webOrigin.x
    let appKitY = desktop.vsMaxY - (webOrigin.y + PetConstants.displayHeight)
    setPanelFrame(NSRect(
      x: appKitX,
      y: appKitY,
      width: PetConstants.displayWidth,
      height: PetConstants.displayHeight
    ))
  }

  func placeOnPrimaryFloor() {
    setPanelFrame(ScreenLayout.primaryFloorPanelRect())
  }

  private func setPanelFrame(_ rect: NSRect) {
    if frame.origin == rect.origin && frame.size == rect.size { return }
    setFrame(rect, display: false)
    content.frame = NSRect(origin: .zero, size: rect.size)
  }

  /// Theme hit box in pet-local web coords (0…330 × 0…248).
  func updatePetHitRectLocal(_ rect: CGRect) {
    petHitRectLocal = rect
    if !interacting { refreshIgnoreFromCursor() }
  }

  func setInteracting(_ value: Bool) {
    interacting = value
    if value { applyIgnore(false) } else { refreshIgnoreFromCursor() }
  }

  func refreshClickThrough() { refreshIgnoreFromCursor() }
  func applyDesktop(_ desktop: VirtualDesktop) {}

  private func startCursorPoll() {
    let timer = Timer(timeInterval: 0.15, repeats: true) { [weak self] _ in
      self?.refreshIgnoreFromCursor()
    }
    RunLoop.main.add(timer, forMode: .common)
    pollTimer = timer
  }

  private func refreshIgnoreFromCursor() {
    if interacting {
      applyIgnore(false)
      return
    }
    let inside = hitScreenRect().insetBy(dx: -4, dy: -4).contains(NSEvent.mouseLocation)
    applyIgnore(!inside)
  }

  private func hitScreenRect() -> CGRect {
    guard petHitRectLocal.width > 0 else { return .zero }
    let inWindow = content.convert(petHitRectLocal, to: nil)
    return convertToScreen(inWindow)
  }

  private func applyIgnore(_ ignore: Bool) {
    if lastIgnore == ignore { return }
    lastIgnore = ignore
    ignoresMouseEvents = ignore
  }
}
