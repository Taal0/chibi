import AppKit
import Foundation

enum CatVisualState: String {
  case idle, drag, poke, roam
  case working
  case error
  case yawning, dozing, sleeping, waking
}

struct HitBox {
  var x: CGFloat
  var y: CGFloat
  var w: CGFloat
  var h: CGFloat

  var cgRect: CGRect { CGRect(x: x, y: y, width: w, height: h) }
}

/// Logical overlay px — Calico viewBox aspect (266×200), +65% vs base 200.
enum PetConstants {
  static let displayWidth: CGFloat = 330
  static let displayHeight: CGFloat = round(330 * (200.0 / 266.0)) // 248
  static let floorBottomInset: CGFloat = 8
  static let dragThresholdPx: CGFloat = 6
  static let clickMaxMs: CFTimeInterval = 300
  static let petId = "chibi-cat"
}

enum Theme {
  private(set) static var data = ThemeData.empty
  static let hitPadPx: CGFloat = 8

  static var petThemeScale: CGFloat {
    PetConstants.displayWidth / CGFloat(data.viewBox.width)
  }

  static var roamFlipAssets: Bool { data.roamFlipAssets }
  static var pokeDurationMs: Int { data.reactions.clickLeft.duration ?? 2500 }
  static var errorDurationMs: Int { data.timings.autoReturn["error"] ?? 5000 }
  static var yawnDurationMs: Int { data.timings.yawnDuration }
  static var wakeDurationMs: Int { data.timings.wakeDuration }
  static var mouseIdleTimeoutMs: Int { data.timings.mouseIdleTimeout }
  static var mouseSleepTimeoutMs: Int { data.timings.mouseSleepTimeout }

  static func loadBundled() {
    guard let url = Bundle.main.url(forResource: "calico", withExtension: "json") else {
      fatalError("calico.json missing from bundle")
    }
    do {
      let raw = try Data(contentsOf: url)
      data = try JSONDecoder().decode(ThemeData.self, from: raw)
    } catch {
      fatalError("Failed to decode calico.json: \(error)")
    }
  }

  static func assetURL(file: String) -> URL? {
    let name = (file as NSString).deletingPathExtension
    let ext = (file as NSString).pathExtension
    if let url = Bundle.main.url(
      forResource: name,
      withExtension: ext,
      subdirectory: "theme/calico/assets"
    ) {
      return url
    }
    // Copy Bundle Resources flattens nested paths to the bundle root.
    return Bundle.main.url(forResource: name, withExtension: ext)
  }

  static func fileForState(_ state: CatVisualState) -> String {
    switch state {
    case .drag: return data.reactions.drag.file
    case .poke: return data.reactions.clickLeft.file
    case .roam: return data.states.roam.first ?? data.states.idle[0]
    case .idle: return data.states.idle[0]
    case .working: return data.states.working.first ?? "calico-working-typing.apng"
    case .error: return data.states.error.first ?? "calico-error.apng"
    case .yawning: return data.states.yawning.first ?? "calico-yawning.apng"
    case .dozing: return data.states.dozing.first ?? "calico-dozing.apng"
    case .sleeping: return data.states.sleeping.first ?? "calico-sleeping.apng"
    case .waking: return data.states.waking.first ?? "calico-waking.apng"
    }
  }

  static func hotAssets() -> [String] {
    var files = [
      data.states.idle[0],
      data.reactions.clickLeft.file,
      data.reactions.drag.file,
    ]
    files.append(contentsOf: data.states.roam)
    files.append(contentsOf: [
      fileForState(.working),
      fileForState(.error),
      fileForState(.yawning),
      fileForState(.dozing),
      fileForState(.sleeping),
      fileForState(.waking),
    ])
    return files.filter { !$0.isEmpty }
  }

  static func hitBoxForState(_ state: CatVisualState) -> HitBox {
    let file = fileForState(state)
    return mapThemeHit(artRectForFile(file), file: file)
  }

  // MARK: - Layout math (port of theme/index.ts)

  private static func themeHitBoxForFile(_ file: String) -> ThemeHitBox {
    if data.sleepingHitboxFiles.contains(file) { return data.hitBoxes.sleeping }
    if data.wideHitboxFiles.contains(file) { return data.hitBoxes.wide }
    return data.hitBoxes.default
  }

  static func artRectForFile(_ file: String) -> HitBox {
    let os = data.objectScale
    let fo = os.fileOffsets[file] ?? ThemeOffset(x: 0, y: 0)
    let fileScale = CGFloat(os.fileScales[file] ?? 1)
    let vb = data.viewBox

    let elW = PetConstants.displayWidth * CGFloat(os.widthRatio)
    let elH = PetConstants.displayHeight * CGFloat(os.heightRatio)
    let elLeft = PetConstants.displayWidth * CGFloat(os.offsetX) + CGFloat(fo.x)
    let elBottom = PetConstants.displayHeight * CGFloat(os.objBottom) + CGFloat(fo.y)
    let elTop = PetConstants.displayHeight - elBottom - elH

    let fit = min(elW / CGFloat(vb.width), elH / CGFloat(vb.height))
    let artW0 = CGFloat(vb.width) * fit
    let artH0 = CGFloat(vb.height) * fit
    let artX0 = elLeft + (elW - artW0) / 2
    let artY0 = elTop + elH - artH0

    let ox = elLeft + elW / 2
    let oy = elTop + elH
    return HitBox(
      x: ox + (artX0 - ox) * fileScale,
      y: oy + (artY0 - oy) * fileScale,
      w: artW0 * fileScale,
      h: artH0 * fileScale
    )
  }

  private static func mapThemeHit(_ art: HitBox, file: String) -> HitBox {
    let vb = data.viewBox
    let themeBox = themeHitBoxForFile(file)
    let sx = art.w / CGFloat(vb.width)
    let sy = art.h / CGFloat(vb.height)
    let x = art.x + CGFloat(themeBox.x) * sx - hitPadPx
    let y = art.y + CGFloat(themeBox.y) * sy - hitPadPx
    let w = CGFloat(themeBox.w) * sx + hitPadPx * 2
    var h = CGFloat(themeBox.h) * sy + hitPadPx * 2

    let artBottom = art.y + art.h
    let hitBottom = max(y + h, artBottom + hitPadPx)
    h = hitBottom - y

    let x2 = max(0, min(x, PetConstants.displayWidth))
    let y2 = max(0, min(y, PetConstants.displayHeight))
    let r = max(x2, min(x + w, PetConstants.displayWidth))
    let b = max(y2, min(y + h, PetConstants.displayHeight))
    return HitBox(x: x2, y: y2, w: max(1, r - x2), h: max(1, b - y2))
  }

  /// Visual style for APNG layer inside the 330×248 pet box (applyVisualStyle port).
  static func visualLayout(for file: String) -> (frame: CGRect, scale: CGFloat, flipX: Bool) {
    let os = data.objectScale
    let fo = os.fileOffsets[file] ?? ThemeOffset(x: 0, y: 0)
    let fileScale = CGFloat(os.fileScales[file] ?? 1)
    let width = PetConstants.displayWidth * CGFloat(os.widthRatio)
    let height = PetConstants.displayHeight * CGFloat(os.heightRatio)
    let left = PetConstants.displayWidth * CGFloat(os.offsetX) + CGFloat(fo.x)
    let bottom = PetConstants.displayHeight * CGFloat(os.objBottom) + CGFloat(fo.y)
    // isFlipped=true: origin top-left; CSS bottom → top = H - bottom - height
    let top = PetConstants.displayHeight - bottom - height
    let frame = CGRect(x: left, y: top, width: width, height: height)
    return (frame, fileScale, false)
  }
}

// MARK: - Codable models

struct ThemeData: Decodable {
  var viewBox: ThemeViewBox
  var roamFlipAssets: Bool
  var states: ThemeStates
  var reactions: ThemeReactions
  var hitBoxes: ThemeHitBoxes
  var wideHitboxFiles: [String]
  var sleepingHitboxFiles: [String]
  var objectScale: ThemeObjectScale
  var timings: ThemeTimings

  static let empty = ThemeData(
    viewBox: ThemeViewBox(x: 0, y: 0, width: 266, height: 200),
    roamFlipAssets: true,
    states: ThemeStates(
      idle: ["calico-idle.apng"],
      roam: ["calico-roam-crabwalk.apng"],
      working: ["calico-working-typing.apng"],
      error: ["calico-error.apng"],
      yawning: ["calico-yawning.apng"],
      dozing: ["calico-dozing.apng"],
      sleeping: ["calico-sleeping.apng"],
      waking: ["calico-waking.apng"]
    ),
    reactions: ThemeReactions(
      drag: ThemeReaction(file: "calico-react-drag.apng", duration: nil),
      clickLeft: ThemeReaction(file: "calico-react-poke.apng", duration: 3500)
    ),
    hitBoxes: ThemeHitBoxes(
      default: ThemeHitBox(x: 40, y: 22, w: 176, h: 150),
      sleeping: ThemeHitBox(x: 60, y: 60, w: 146, h: 100),
      wide: ThemeHitBox(x: 50, y: 20, w: 166, h: 160)
    ),
    wideHitboxFiles: [],
    sleepingHitboxFiles: [],
    objectScale: ThemeObjectScale(
      widthRatio: 0.58,
      heightRatio: 0.44,
      offsetX: 0.21,
      objBottom: 0.05,
      fileScales: [:],
      fileOffsets: [:]
    ),
    timings: ThemeTimings(
      autoReturn: ["error": 5000],
      yawnDuration: 8000,
      wakeDuration: 5800,
      mouseIdleTimeout: 20000,
      mouseSleepTimeout: 60000
    )
  )
}

struct ThemeViewBox: Decodable {
  var x: Double
  var y: Double
  var width: Double
  var height: Double
}

struct ThemeStates: Decodable {
  var idle: [String]
  var roam: [String]
  var working: [String]
  var error: [String]
  var yawning: [String]
  var dozing: [String]
  var sleeping: [String]
  var waking: [String]

  enum CodingKeys: String, CodingKey {
    case idle, roam, working, error, yawning, dozing, sleeping, waking
  }

  init(
    idle: [String],
    roam: [String],
    working: [String] = [],
    error: [String] = [],
    yawning: [String] = [],
    dozing: [String] = [],
    sleeping: [String] = [],
    waking: [String] = []
  ) {
    self.idle = idle
    self.roam = roam
    self.working = working
    self.error = error
    self.yawning = yawning
    self.dozing = dozing
    self.sleeping = sleeping
    self.waking = waking
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    idle = try c.decode([String].self, forKey: .idle)
    roam = try c.decodeIfPresent([String].self, forKey: .roam) ?? []
    working = try c.decodeIfPresent([String].self, forKey: .working) ?? []
    error = try c.decodeIfPresent([String].self, forKey: .error) ?? []
    yawning = try c.decodeIfPresent([String].self, forKey: .yawning) ?? []
    dozing = try c.decodeIfPresent([String].self, forKey: .dozing) ?? []
    sleeping = try c.decodeIfPresent([String].self, forKey: .sleeping) ?? []
    waking = try c.decodeIfPresent([String].self, forKey: .waking) ?? []
  }
}

struct ThemeTimings: Decodable {
  var autoReturn: [String: Int]
  var yawnDuration: Int
  var wakeDuration: Int
  var mouseIdleTimeout: Int
  var mouseSleepTimeout: Int

  enum CodingKeys: String, CodingKey {
    case autoReturn, yawnDuration, wakeDuration, mouseIdleTimeout, mouseSleepTimeout
  }

  init(
    autoReturn: [String: Int],
    yawnDuration: Int,
    wakeDuration: Int,
    mouseIdleTimeout: Int,
    mouseSleepTimeout: Int
  ) {
    self.autoReturn = autoReturn
    self.yawnDuration = yawnDuration
    self.wakeDuration = wakeDuration
    self.mouseIdleTimeout = mouseIdleTimeout
    self.mouseSleepTimeout = mouseSleepTimeout
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    autoReturn = try c.decodeIfPresent([String: Int].self, forKey: .autoReturn) ?? [:]
    yawnDuration = try c.decodeIfPresent(Int.self, forKey: .yawnDuration) ?? 8000
    wakeDuration = try c.decodeIfPresent(Int.self, forKey: .wakeDuration) ?? 5800
    mouseIdleTimeout = try c.decodeIfPresent(Int.self, forKey: .mouseIdleTimeout) ?? 20000
    mouseSleepTimeout = try c.decodeIfPresent(Int.self, forKey: .mouseSleepTimeout) ?? 60000
  }
}

struct ThemeReactions: Decodable {
  var drag: ThemeReaction
  var clickLeft: ThemeReaction
}

struct ThemeReaction: Decodable {
  var file: String
  var duration: Int?
}

struct ThemeHitBoxes: Decodable {
  var `default`: ThemeHitBox
  var sleeping: ThemeHitBox
  var wide: ThemeHitBox
}

struct ThemeHitBox: Decodable {
  var x: Double
  var y: Double
  var w: Double
  var h: Double
}

struct ThemeObjectScale: Decodable {
  var widthRatio: Double
  var heightRatio: Double
  var offsetX: Double
  var objBottom: Double
  var fileScales: [String: Double]
  var fileOffsets: [String: ThemeOffset]

  enum CodingKeys: String, CodingKey {
    case widthRatio, heightRatio, offsetX, objBottom, fileScales, fileOffsets
  }

  init(
    widthRatio: Double,
    heightRatio: Double,
    offsetX: Double,
    objBottom: Double,
    fileScales: [String: Double],
    fileOffsets: [String: ThemeOffset]
  ) {
    self.widthRatio = widthRatio
    self.heightRatio = heightRatio
    self.offsetX = offsetX
    self.objBottom = objBottom
    self.fileScales = fileScales
    self.fileOffsets = fileOffsets
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    widthRatio = try c.decode(Double.self, forKey: .widthRatio)
    heightRatio = try c.decode(Double.self, forKey: .heightRatio)
    offsetX = try c.decode(Double.self, forKey: .offsetX)
    objBottom = try c.decode(Double.self, forKey: .objBottom)
    fileScales = try c.decodeIfPresent([String: Double].self, forKey: .fileScales) ?? [:]
    fileOffsets = try c.decodeIfPresent([String: ThemeOffset].self, forKey: .fileOffsets) ?? [:]
  }
}

struct ThemeOffset: Decodable {
  var x: Double
  var y: Double
}
