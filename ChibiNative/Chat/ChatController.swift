import AppKit

protocol ChatControllerDelegate: AnyObject {
  func chatDidStartStreaming()
  func chatDidFinishStreaming()
  func chatDidFail(_ message: String)
  func chatDidInteract()
}

final class ChatController: ChatViewModelDelegate {
  weak var delegate: ChatControllerDelegate?

  private let panel = ChatPanelWindow()
  private let viewModel = ChatViewModel()
  private var isVisible = false

  init() {
    viewModel.delegate = self
    let chat = panel.chatView!
    chat.onClose = { [weak self] in self?.hide() }
    chat.onNewSession = { [weak self] in
      self?.delegate?.chatDidInteract()
      self?.viewModel.newSession()
    }
    chat.onSubmit = { [weak self] text in
      self?.delegate?.chatDidInteract()
      self?.viewModel.send(text)
    }
    chat.render(messages: viewModel.messages, sessionLabel: viewModel.sessionLabel, isStreaming: false)
  }

  var isOpen: Bool { isVisible }

  func toggle(nearPetFrame petFrame: NSRect) {
    if isVisible {
      hide()
    } else {
      show(nearPetFrame: petFrame)
    }
  }

  func show(nearPetFrame petFrame: NSRect) {
    if !isVisible {
      panel.place(besidePetFrame: petFrame)
    }
    NSApp.activate(ignoringOtherApps: true)
    panel.orderFrontRegardless()
    panel.makeKeyAndOrderFront(nil)
    isVisible = true
    panel.chatView.focusInput()
    delegate?.chatDidInteract()
  }

  func hide() {
    panel.orderOut(nil)
    isVisible = false
  }

  // MARK: - ChatViewModelDelegate

  func chatViewModelDidUpdate(_ model: ChatViewModel) {
    panel.chatView.render(
      messages: model.messages,
      sessionLabel: model.sessionLabel,
      isStreaming: model.isStreaming
    )
  }

  func chatViewModel(_ model: ChatViewModel, didChangeActivity isActive: Bool) {
    if isActive {
      delegate?.chatDidStartStreaming()
    } else {
      delegate?.chatDidFinishStreaming()
    }
  }

  func chatViewModelDidFail(_ model: ChatViewModel, message: String) {
    delegate?.chatDidFail(message)
  }
}
