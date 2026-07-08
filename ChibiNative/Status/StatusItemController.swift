import AppKit

final class StatusItemController: NSObject {
  private var statusItem: NSStatusItem?

  override init() {
    super.init()
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    if let button = item.button {
      if let url = Bundle.main.url(forResource: "tray", withExtension: "png"),
         let image = NSImage(contentsOf: url)
      {
        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        button.image = image
      } else {
        button.title = "🐱"
      }
    }
    let menu = NSMenu()
    let quit = NSMenuItem(title: "Quit Chibi", action: #selector(quit), keyEquivalent: "q")
    quit.target = self
    menu.addItem(quit)
    item.menu = menu
    statusItem = item
  }

  @objc private func quit() {
    NSApp.terminate(nil)
  }
}
