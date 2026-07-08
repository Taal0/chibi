import AppKit
import Foundation

struct MonitorRegion {
  var left: CGFloat
  var right: CGFloat
  var top: CGFloat
  var bottom: CGFloat
  var floorY: CGFloat
  var primary: Bool
}

struct VirtualDesktop {
  var originAppKit: CGPoint
  var width: CGFloat
  var height: CGFloat
  var vsMaxY: CGFloat
  var monitors: [MonitorRegion]

  func webPoint(fromAppKit p: NSPoint) -> CGPoint {
    CGPoint(x: p.x - originAppKit.x, y: vsMaxY - p.y)
  }
}

enum ScreenLayout {
  static func capture() -> VirtualDesktop {
    let screens = NSScreen.screens
    guard !screens.isEmpty else {
      return VirtualDesktop(
        originAppKit: .zero,
        width: 1440,
        height: 900,
        vsMaxY: 900,
        monitors: [
          MonitorRegion(left: 0, right: 1440, top: 0, bottom: 900, floorY: 892, primary: true)
        ]
      )
    }

    let frames = screens.map(\.frame)
    let vsMinX = frames.map(\.minX).min()!
    let vsMinY = frames.map(\.minY).min()!
    let vsMaxX = frames.map(\.maxX).max()!
    let vsMaxY = frames.map(\.maxY).max()!

    // screens[0] is the menu-bar / arrangement primary. NSScreen.main is
    // unreliable for LSUIElement (.accessory) apps with no key window.
    let primaryFrame = screens[0].frame

    let monitors: [MonitorRegion] = screens.map { screen in
      let f = screen.frame
      let vf = screen.visibleFrame
      let left = f.minX - vsMinX
      let top = vsMaxY - f.maxY
      let right = left + f.width
      let bottom = top + f.height
      let floorY = (vsMaxY - vf.minY) - PetConstants.floorBottomInset
      let isPrimary =
        abs(f.origin.x - primaryFrame.origin.x) < 0.5
        && abs(f.origin.y - primaryFrame.origin.y) < 0.5
      return MonitorRegion(
        left: left, right: right, top: top, bottom: bottom,
        floorY: floorY, primary: isPrimary
      )
    }

    return VirtualDesktop(
      originAppKit: CGPoint(x: vsMinX, y: vsMinY),
      width: vsMaxX - vsMinX,
      height: vsMaxY - vsMinY,
      vsMaxY: vsMaxY,
      monitors: monitors
    )
  }

  static func spawnVisible(on desktop: VirtualDesktop) -> CGPoint {
    let primary = desktop.monitors.first(where: \.primary) ?? desktop.monitors[0]
    return spawn(on: primary)
  }

  static func spawn(on monitor: MonitorRegion) -> CGPoint {
    let x = (monitor.left + monitor.right) / 2 - PetConstants.displayWidth / 2
    let y = monitor.floorY - PetConstants.displayHeight
    return CGPoint(x: x, y: y)
  }

  /// Absolute AppKit screen rect on the menu-bar display floor (debug / force place).
  static func primaryFloorPanelRect() -> NSRect {
    let screen = NSScreen.screens.first ?? NSScreen.main!
    let vf = screen.visibleFrame
    return NSRect(
      x: vf.midX - PetConstants.displayWidth / 2,
      y: vf.minY + PetConstants.floorBottomInset,
      width: PetConstants.displayWidth,
      height: PetConstants.displayHeight
    )
  }
}
