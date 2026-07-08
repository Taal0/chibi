import AppKit

enum ChatPalette {
  static let background = NSColor(srgbRed: 0xF5 / 255, green: 0xF0 / 255, blue: 0xE6 / 255, alpha: 1)
  static let userText = NSColor(srgbRed: 0x5C / 255, green: 0x40 / 255, blue: 0x33 / 255, alpha: 1)
  static let chibiText = NSColor(srgbRed: 0x8B / 255, green: 0x69 / 255, blue: 0x14 / 255, alpha: 1)
  static let systemText = NSColor(srgbRed: 0x8A / 255, green: 0x7A / 255, blue: 0x65 / 255, alpha: 1)
  static let border = NSColor(srgbRed: 0xD4 / 255, green: 0xC4 / 255, blue: 0xA8 / 255, alpha: 1)
  static let headerFill = NSColor(srgbRed: 0xED / 255, green: 0xE6 / 255, blue: 0xD8 / 255, alpha: 1)
  /// Near-black for input — stays readable even when the app is in dark appearance.
  static let inputText = NSColor(srgbRed: 0x1A / 255, green: 0x12 / 255, blue: 0x0C / 255, alpha: 1)
  static let inputFill = NSColor(srgbRed: 0xFF / 255, green: 0xFC / 255, blue: 0xF7 / 255, alpha: 1)

  static let mono = NSFont(name: "SF Mono", size: 13)
    ?? NSFont(name: "Menlo", size: 13)
    ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

  static let monoInput = NSFont(name: "SF Mono", size: 15)
    ?? NSFont(name: "Menlo", size: 15)
    ?? NSFont.monospacedSystemFont(ofSize: 15, weight: .medium)
}

private final class ChatHeaderView: NSView {
  override func mouseDown(with event: NSEvent) {
    window?.performDrag(with: event)
  }
}

final class ChatView: NSView, NSTextFieldDelegate {
  var onClose: (() -> Void)?
  var onNewSession: (() -> Void)?
  var onSubmit: ((String) -> Void)?

  private let header = ChatHeaderView()
  private let sessionLabel = NSTextField(labelWithString: "new session")
  private let newButton = NSButton(title: "New", target: nil, action: nil)
  private let closeButton = NSButton(title: "✕", target: nil, action: nil)
  private let scrollView = NSScrollView()
  private let textView = NSTextView()
  private let inputField = NSTextField(string: "")
  private let promptLabel = NSTextField(labelWithString: "you>")

  private var latestMessages: [ChatMessage] = []
  private var thinkingTimer: Timer?
  private var thinkingFrame = 0
  private static let thinkingFrames = [".  ", ".. ", "..."]

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    wantsLayer = true
    layer?.backgroundColor = ChatPalette.background.cgColor
    layer?.cornerRadius = 10
    layer?.borderWidth = 1
    layer?.borderColor = ChatPalette.border.cgColor

    setupHeader()
    setupTranscript()
    setupInput()
    layoutSubtree()
  }

  deinit {
    thinkingTimer?.invalidate()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError() }

  override var isFlipped: Bool { true }

  override func layout() {
    super.layout()
    layoutSubtree()
  }

  func render(messages: [ChatMessage], sessionLabel text: String, isStreaming: Bool) {
    latestMessages = messages
    sessionLabel.stringValue = text
    inputField.isEnabled = !isStreaming
    updateThinkingAnimation(isStreaming: isStreaming, messages: messages)
    paintTranscript()
  }

  private func updateThinkingAnimation(isStreaming: Bool, messages: [ChatMessage]) {
    let waiting = isStreaming && messages.contains {
      $0.role == .assistant && $0.isStreaming && $0.content.isEmpty
    }
    if waiting {
      if thinkingTimer == nil {
        thinkingFrame = 0
        let timer = Timer(timeInterval: 0.4, repeats: true) { [weak self] _ in
          guard let self else { return }
          self.thinkingFrame = (self.thinkingFrame + 1) % Self.thinkingFrames.count
          self.paintTranscript()
        }
        RunLoop.main.add(timer, forMode: .common)
        thinkingTimer = timer
      }
    } else {
      thinkingTimer?.invalidate()
      thinkingTimer = nil
      thinkingFrame = 0
    }
  }

  private func paintTranscript() {
    let attributed = NSMutableAttributedString()
    for message in latestMessages {
      let prefix: String
      let color: NSColor
      switch message.role {
      case .user:
        prefix = "you> "
        color = ChatPalette.userText
      case .assistant:
        prefix = "chibi> "
        color = ChatPalette.chibiText
      case .system:
        prefix = ""
        color = ChatPalette.systemText
      }

      let body: String
      if message.role == .assistant && message.isStreaming && message.content.isEmpty {
        body = Self.thinkingFrames[thinkingFrame % Self.thinkingFrames.count]
      } else if message.isStreaming {
        body = message.content + "▍"
      } else {
        body = message.content
      }

      let line = "\(prefix)\(body)\n"
      attributed.append(NSAttributedString(string: line, attributes: [
        .font: ChatPalette.mono,
        .foregroundColor: color,
      ]))
    }

    textView.textStorage?.setAttributedString(attributed)
    textView.scrollToEndOfDocument(nil)
  }

  func focusInput() {
    window?.makeFirstResponder(inputField)
  }

  // MARK: - Setup

  private func setupHeader() {
    header.wantsLayer = true
    header.layer?.backgroundColor = ChatPalette.headerFill.cgColor
    addSubview(header)

    sessionLabel.font = ChatPalette.mono
    sessionLabel.textColor = ChatPalette.userText
    sessionLabel.isEditable = false
    sessionLabel.isBordered = false
    sessionLabel.backgroundColor = .clear
    header.addSubview(sessionLabel)

    styleChromeButton(newButton, title: "New")
    newButton.target = self
    newButton.action = #selector(newTapped)
    header.addSubview(newButton)

    styleChromeButton(closeButton, title: "✕")
    closeButton.target = self
    closeButton.action = #selector(closeTapped)
    header.addSubview(closeButton)
  }

  private func setupTranscript() {
    textView.isEditable = false
    textView.isSelectable = true
    textView.drawsBackground = false
    textView.backgroundColor = .clear
    textView.textContainerInset = NSSize(width: 10, height: 8)
    textView.font = ChatPalette.mono
    textView.textColor = ChatPalette.userText

    scrollView.documentView = textView
    scrollView.hasVerticalScroller = true
    scrollView.borderType = .noBorder
    scrollView.drawsBackground = false
    scrollView.backgroundColor = .clear
    addSubview(scrollView)
  }

  private func setupInput() {
    promptLabel.font = ChatPalette.monoInput
    promptLabel.textColor = ChatPalette.inputText
    promptLabel.isBordered = false
    promptLabel.backgroundColor = .clear
    addSubview(promptLabel)

    // Force light field chrome so dark system appearance doesn't wash out typed text.
    inputField.appearance = NSAppearance(named: .aqua)
    inputField.font = ChatPalette.monoInput
    inputField.textColor = ChatPalette.inputText
    inputField.drawsBackground = true
    inputField.backgroundColor = ChatPalette.inputFill
    inputField.placeholderAttributedString = NSAttributedString(
      string: "mesaj…  (/help)",
      attributes: [
        .font: ChatPalette.monoInput,
        .foregroundColor: ChatPalette.systemText,
      ]
    )
    inputField.isBordered = true
    inputField.isBezeled = true
    inputField.bezelStyle = .roundedBezel
    inputField.focusRingType = .none
    inputField.delegate = self
    inputField.target = self
    inputField.action = #selector(submitInput)
    if let cell = inputField.cell as? NSTextFieldCell {
      cell.textColor = ChatPalette.inputText
      cell.backgroundColor = ChatPalette.inputFill
      cell.drawsBackground = true
    }
    addSubview(inputField)
  }

  private func styleChromeButton(_ button: NSButton, title: String) {
    button.title = title
    button.bezelStyle = .inline
    button.isBordered = false
    button.font = ChatPalette.mono
    button.contentTintColor = ChatPalette.userText
  }

  private func layoutSubtree() {
    let w = bounds.width
    let h = bounds.height
    let headerH: CGFloat = 34
    let inputH: CGFloat = 32
    let pad: CGFloat = 10

    header.frame = NSRect(x: 0, y: 0, width: w, height: headerH)
    closeButton.frame = NSRect(x: w - 34, y: 4, width: 28, height: 26)
    newButton.frame = NSRect(x: w - 90, y: 4, width: 50, height: 26)
    sessionLabel.frame = NSRect(x: pad, y: 6, width: w - 100, height: 22)

    let inputY = h - pad - inputH
    promptLabel.frame = NSRect(x: pad, y: inputY + 5, width: 48, height: 22)
    inputField.frame = NSRect(x: pad + 48, y: inputY, width: w - pad * 2 - 48, height: inputH)

    scrollView.frame = NSRect(
      x: 0,
      y: headerH,
      width: w,
      height: max(40, inputY - headerH - 6)
    )
    textView.frame = NSRect(origin: .zero, size: scrollView.contentSize)
  }

  // MARK: - Actions

  @objc private func closeTapped() { onClose?() }
  @objc private func newTapped() { onNewSession?() }

  @objc private func submitInput() {
    let text = inputField.stringValue
    inputField.stringValue = ""
    onSubmit?(text)
  }

  func controlTextDidBeginEditing(_ obj: Notification) {
    guard let editor = window?.fieldEditor(false, for: inputField) as? NSTextView else { return }
    editor.appearance = NSAppearance(named: .aqua)
    editor.font = ChatPalette.monoInput
    editor.textColor = ChatPalette.inputText
    editor.insertionPointColor = ChatPalette.inputText
    editor.backgroundColor = ChatPalette.inputFill
    editor.drawsBackground = true
  }

  func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
    if commandSelector == #selector(NSResponder.insertNewline(_:)) {
      submitInput()
      return true
    }
    return false
  }
}
