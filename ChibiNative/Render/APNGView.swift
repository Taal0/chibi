import AppKit
import QuartzCore

/// APNG visual matching web `applyVisualStyle` / `artRectForFile`.
/// View frame = post-scale art rect; image drawn via a dedicated CALayer so
/// AppKit doesn't clobber flip on setFrame, and we skip CGContext bitmap work.
final class APNGView: NSView, DisplayTickClient {
  private let imageLayer = CALayer()
  private var frames: [APNGFrame] = []
  private var frameIndex = 0
  private var accumulator: CFTimeInterval = 0
  private var lastTick: CFTimeInterval = 0
  private var flipX = false
  private var ticking = false

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    wantsLayer = true
    layerContentsRedrawPolicy = .never
    clipsToBounds = false

    layer?.actions = [
      "contents": NSNull(),
      "bounds": NSNull(),
      "position": NSNull(),
      "transform": NSNull(),
    ]

    imageLayer.magnificationFilter = .linear
    imageLayer.contentsGravity = .resizeAspect
    imageLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
    imageLayer.actions = [
      "contents": NSNull(),
      "transform": NSNull(),
      "bounds": NSNull(),
      "position": NSNull(),
    ]
    layer?.addSublayer(imageLayer)
    layoutImageLayer()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError() }

  override var isFlipped: Bool { true }
  override var isOpaque: Bool { false }
  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  func setContentsScale(_ scale: CGFloat) {
    layer?.contentsScale = scale
    imageLayer.contentsScale = scale
  }

  func play(file: String, flipX: Bool, restart: Bool = true) {
    self.flipX = flipX
    let art = Theme.artRectForFile(file)
    frame = art.cgRect
    frames = APNGCache.shared.frames(for: file)
    if frames.isEmpty {
      NSLog("[Chibi] APNG empty: %@", file)
    }
    if restart || frameIndex >= frames.count {
      frameIndex = 0
      accumulator = 0
    }
    layoutImageLayer()
    renderCurrentFrame()
    applyFlipTransform()
    startTick()
  }

  func setFlipX(_ value: Bool) {
    guard flipX != value else { return }
    flipX = value
    applyFlipTransform()
  }

  override func viewDidChangeBackingProperties() {
    super.viewDidChangeBackingProperties()
    let scale = window?.backingScaleFactor ?? 2
    layer?.contentsScale = scale
    imageLayer.contentsScale = scale
  }

  override func layout() {
    super.layout()
    layoutImageLayer()
  }

  override func setFrameSize(_ newSize: NSSize) {
    super.setFrameSize(newSize)
    layoutImageLayer()
  }

  private func layoutImageLayer() {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    // Centered in bounds; flip rotates around this anchor.
    imageLayer.bounds = CGRect(origin: .zero, size: bounds.size)
    imageLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
    CATransaction.commit()
  }

  private func renderCurrentFrame() {
    guard !frames.isEmpty, frames.indices.contains(frameIndex) else {
      imageLayer.contents = nil
      return
    }
    let pixelScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    imageLayer.contentsScale = pixelScale
    imageLayer.contents = frames[frameIndex].image
    CATransaction.commit()
  }

  private func applyFlipTransform() {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    imageLayer.setAffineTransform(CGAffineTransform(scaleX: flipX ? -1 : 1, y: 1))
    CATransaction.commit()
  }

  private func startTick() {
    guard !ticking else { return }
    ticking = true
    lastTick = CACurrentMediaTime()
    DisplayTicker.shared.add(self)
  }

  func stop() {
    guard ticking else { return }
    ticking = false
    DisplayTicker.shared.remove(self)
  }

  func displayTick(now: CFTimeInterval) {
    guard !frames.isEmpty else { return }
    let dt = now - lastTick
    lastTick = now
    accumulator += min(dt, 0.1)
    var advanced = false
    var guardCount = 0
    while accumulator >= frames[frameIndex].delay, guardCount < frames.count {
      accumulator -= frames[frameIndex].delay
      frameIndex = (frameIndex + 1) % frames.count
      advanced = true
      guardCount += 1
    }
    if advanced {
      renderCurrentFrame()
    }
  }

  deinit { stop() }
}
