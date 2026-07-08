import AppKit

final class ChatPanelWindow: NSPanel {
  static let panelSize = NSSize(width: 340, height: 420)
  static let gap: CGFloat = 12

  private(set) var chatView: ChatView!

  init() {
    super.init(
      contentRect: NSRect(origin: .zero, size: Self.panelSize),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    isOpaque = false
    backgroundColor = .clear
    hasShadow = true
    level = .floating
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
    isMovableByWindowBackground = false
    hidesOnDeactivate = false
    becomesKeyOnlyIfNeeded = true
    ignoresMouseEvents = false

    let view = ChatView(frame: NSRect(origin: .zero, size: Self.panelSize))
    chatView = view
    contentView = view
  }

  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }

  /// Place once beside the pet panel; prefer right, fall back to left.
  func place(besidePetFrame pet: NSRect) {
    let size = Self.panelSize
    guard let screen = NSScreen.screens.first(where: { $0.frame.intersects(pet) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
    else {
      setFrame(NSRect(origin: NSPoint(x: pet.maxX + Self.gap, y: pet.minY), size: size), display: true)
      return
    }

    let visible = screen.visibleFrame
    var origin = NSPoint(x: pet.maxX + Self.gap, y: pet.minY)
    if origin.x + size.width > visible.maxX {
      origin.x = pet.minX - Self.gap - size.width
    }
    origin.x = min(max(origin.x, visible.minX), visible.maxX - size.width)
    origin.y = min(max(origin.y, visible.minY), visible.maxY - size.height)
    setFrame(NSRect(origin: origin, size: size), display: true)
  }
}
