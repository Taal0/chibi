import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
  private var overlayWindow: OverlayWindow?
  private var petController: PetController?
  private var statusItem: StatusItemController?
  private var screenObserver: NSObjectProtocol?
  private var sleepObserver: NSObjectProtocol?
  private var wakeObserver: NSObjectProtocol?

  func applicationDidFinishLaunching(_ notification: Notification) {
    Theme.loadBundled()

    let window = OverlayWindow()
    overlayWindow = window

    let pet = PetController(overlay: window)
    petController = pet
    pet.start()

    statusItem = StatusItemController()

    screenObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification,
      object: nil,
      queue: .main
    ) { [weak pet] _ in
      pet?.handleScreenChange()
    }

    let workspace = NSWorkspace.shared.notificationCenter
    sleepObserver = workspace.addObserver(
      forName: NSWorkspace.screensDidSleepNotification,
      object: nil,
      queue: .main
    ) { _ in
      DisplayTicker.shared.pause()
    }
    wakeObserver = workspace.addObserver(
      forName: NSWorkspace.screensDidWakeNotification,
      object: nil,
      queue: .main
    ) { _ in
      DisplayTicker.shared.resume()
    }

    window.orderFrontRegardless()
  }

  func applicationWillTerminate(_ notification: Notification) {
    if let screenObserver {
      NotificationCenter.default.removeObserver(screenObserver)
    }
    if let sleepObserver {
      NSWorkspace.shared.notificationCenter.removeObserver(sleepObserver)
    }
    if let wakeObserver {
      NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
    }
    petController?.dispose()
  }
}
