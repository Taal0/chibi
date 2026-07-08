import AppKit
import QuartzCore

protocol DisplayTickClient: AnyObject {
  func displayTick(now: CFTimeInterval)
}

/// Shared vsync tick for APNG + roam — capped ~30 fps to cut idle CPU.
final class DisplayTicker: NSObject {
  static let shared = DisplayTicker()

  private var clients = NSHashTable<AnyObject>.weakObjects()
  private var link: AnyObject?
  private var cvLink: CVDisplayLink?
  private var pendingMain = false
  private var paused = false
  private var lastFire: CFTimeInterval = 0
  private let minInterval: CFTimeInterval = 1.0 / 30.0

  func add(_ client: DisplayTickClient) {
    clients.add(client)
    startIfNeeded()
  }

  func remove(_ client: DisplayTickClient) {
    clients.remove(client)
    if clients.allObjects.isEmpty {
      stop()
    }
  }

  func pause() {
    paused = true
    stop()
  }

  func resume() {
    paused = false
    if !clients.allObjects.isEmpty {
      startIfNeeded()
    }
  }

  private func startIfNeeded() {
    guard !paused else { return }
    guard link == nil, cvLink == nil else { return }

    if #available(macOS 14.0, *), let screen = NSScreen.main {
      let dl = screen.displayLink(target: self, selector: #selector(caTick))
      dl.preferredFrameRateRange = CAFrameRateRange(minimum: 15, maximum: 30, preferred: 30)
      dl.add(to: .main, forMode: .common)
      link = dl
      return
    }

    var created: CVDisplayLink?
    CVDisplayLinkCreateWithActiveCGDisplays(&created)
    guard let created else { return }
    cvLink = created
    let retained = Unmanaged.passUnretained(self)
    CVDisplayLinkSetOutputCallback(created, { _, _, _, _, _, context -> CVReturn in
      let ticker = Unmanaged<DisplayTicker>.fromOpaque(context!).takeUnretainedValue()
      ticker.scheduleMainTick()
      return kCVReturnSuccess
    }, retained.toOpaque())
    CVDisplayLinkStart(created)
  }

  private func stop() {
    if #available(macOS 14.0, *) {
      if let dl = link as? CADisplayLink {
        dl.invalidate()
      }
    }
    link = nil
    if let cv = cvLink {
      CVDisplayLinkStop(cv)
      cvLink = nil
    }
    pendingMain = false
  }

  @objc private func caTick() {
    fire(now: CACurrentMediaTime())
  }

  /// Coalesce multiple CVDisplayLink callbacks into one main-queue hop.
  private func scheduleMainTick() {
    if pendingMain { return }
    pendingMain = true
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.pendingMain = false
      self.fire(now: CACurrentMediaTime())
    }
  }

  private func fire(now: CFTimeInterval) {
    // Frame-skip fallback for CVDisplayLink (and any over-firing CADisplayLink).
    if now - lastFire < minInterval { return }
    lastFire = now
    for case let client as DisplayTickClient in clients.allObjects {
      client.displayTick(now: now)
    }
  }
}
