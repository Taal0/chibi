import AppKit

/// Pet box (330×248) filling the floating panel. Hosts the APNG visual.
final class PetView: NSView {
  var onMouseDown: ((NSPoint) -> Void)?
  var onMouseDragged: ((NSPoint) -> Void)?
  var onMouseUp: ((NSPoint) -> Void)?

  private let apng = APNGView(frame: .zero)
  private var tracking = false

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor
    clipsToBounds = false
    addSubview(apng)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError() }

  override var isFlipped: Bool { true }
  override var isOpaque: Bool { false }

  var apngView: APNGView { apng }

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

  override func hitTest(_ point: NSPoint) -> NSView? {
    bounds.contains(point) ? self : nil
  }

  /// Pet-local point (top-left of 330×248 box).
  private func localLocation(of event: NSEvent) -> NSPoint {
    convert(event.locationInWindow, from: nil)
  }

  override func mouseDown(with event: NSEvent) {
    tracking = true
    onMouseDown?(localLocation(of: event))
  }

  override func mouseDragged(with event: NSEvent) {
    guard tracking else { return }
    onMouseDragged?(localLocation(of: event))
  }

  override func mouseUp(with event: NSEvent) {
    guard tracking else { return }
    tracking = false
    onMouseUp?(localLocation(of: event))
  }
}
