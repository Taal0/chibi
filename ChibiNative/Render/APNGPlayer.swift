import Foundation
import ImageIO
import CoreGraphics

struct APNGFrame {
  let image: CGImage
  let delay: TimeInterval // seconds
}

enum APNGPlayer {
  static func load(url: URL) -> [APNGFrame] {
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return [] }
    let n = CGImageSourceGetCount(src)
    var frames: [APNGFrame] = []
    frames.reserveCapacity(n)
    for i in 0..<n {
      guard let img = CGImageSourceCreateImageAtIndex(src, i, nil) else { continue }
      let props = CGImageSourceCopyPropertiesAtIndex(src, i, nil) as? [CFString: Any]
      let png = props?[kCGImagePropertyPNGDictionary] as? [CFString: Any]
      var delay =
        (png?[kCGImagePropertyAPNGUnclampedDelayTime] as? Double)
        ?? (png?[kCGImagePropertyAPNGDelayTime] as? Double)
        ?? 0
      if delay < 0.001 { delay = 0.1 }
      frames.append(APNGFrame(image: img, delay: delay))
    }
    return frames
  }
}

/// Frame cache keyed by asset filename.
final class APNGCache {
  static let shared = APNGCache()
  private var cache: [String: [APNGFrame]] = [:]

  func frames(for file: String) -> [APNGFrame] {
    if let hit = cache[file] { return hit }
    guard let url = Theme.assetURL(file: file) else { return [] }
    let loaded = APNGPlayer.load(url: url)
    cache[file] = loaded
    return loaded
  }

  func preloadHot() {
    // Idle only at launch; other assets load lazily on first play.
    _ = frames(for: Theme.data.states.idle[0])
  }
}
