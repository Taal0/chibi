import Foundation

struct ChatMessage: Identifiable {
  enum Role {
    case user
    case assistant
    case system
  }

  let id: UUID
  let role: Role
  var content: String
  var isStreaming: Bool

  init(id: UUID = UUID(), role: Role, content: String, isStreaming: Bool = false) {
    self.id = id
    self.role = role
    self.content = content
    self.isStreaming = isStreaming
  }
}

protocol ChatViewModelDelegate: AnyObject {
  func chatViewModelDidUpdate(_ model: ChatViewModel)
  func chatViewModel(_ model: ChatViewModel, didChangeActivity isActive: Bool)
  func chatViewModelDidFail(_ model: ChatViewModel, message: String)
}

final class ChatViewModel {
  private(set) var messages: [ChatMessage] = []
  private(set) var sessionId: String?
  private(set) var isStreaming = false

  weak var delegate: ChatViewModelDelegate?

  private let client: LLMClient
  private var streamTask: Task<Void, Never>?

  var sessionLabel: String {
    if let sessionId, sessionId.count >= 8 {
      return "session \(sessionId.prefix(8))"
    }
    return "new session"
  }

  init(client: LLMClient = LLMClient()) {
    self.client = client
  }

  func send(_ text: String) {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, !isStreaming else { return }

    let lower = trimmed.lowercased()
    if lower == "/new" {
      newSession()
      return
    }
    if lower == "/help" {
      appendSystem("""
      Komutlar:
        /new   — yeni oturum
        /help  — bu mesaj
      """)
      return
    }

    messages.append(ChatMessage(role: .user, content: trimmed))
    let assistantId = UUID()
    messages.append(ChatMessage(id: assistantId, role: .assistant, content: "", isStreaming: true))
    isStreaming = true
    notify()
    delegate?.chatViewModel(self, didChangeActivity: true)

    streamTask?.cancel()
    streamTask = Task { [weak self] in
      guard let self else { return }
      do {
        for try await event in client.streamChat(message: trimmed, sessionId: sessionId) {
          if Task.isCancelled { break }
          await MainActor.run {
            self.handle(event, assistantId: assistantId)
          }
        }
        await MainActor.run {
          self.finishStreaming(assistantId: assistantId)
        }
      } catch {
        if Task.isCancelled { return }
        await MainActor.run {
          self.failStreaming(assistantId: assistantId, message: error.localizedDescription)
        }
      }
    }
  }

  func newSession() {
    streamTask?.cancel()
    streamTask = nil
    sessionId = nil
    messages.removeAll()
    if isStreaming {
      isStreaming = false
      delegate?.chatViewModel(self, didChangeActivity: false)
    }
    appendSystem("Yeni oturum.")
  }

  private func handle(_ event: StreamEvent, assistantId: UUID) {
    switch event {
    case .session(let id):
      sessionId = id
      notify()
    case .token(let token):
      guard let idx = messages.firstIndex(where: { $0.id == assistantId }) else { return }
      messages[idx].content += token
      notify()
    case .done:
      break
    case .error(let detail):
      failStreaming(assistantId: assistantId, message: detail)
    }
  }

  private func finishStreaming(assistantId: UUID) {
    guard isStreaming else { return }
    if let idx = messages.firstIndex(where: { $0.id == assistantId }) {
      messages[idx].isStreaming = false
      if messages[idx].content.isEmpty {
        messages[idx].content = "(boş yanıt)"
      }
    }
    isStreaming = false
    notify()
    delegate?.chatViewModel(self, didChangeActivity: false)
  }

  private func failStreaming(assistantId: UUID, message: String) {
    if let idx = messages.firstIndex(where: { $0.id == assistantId }) {
      if messages[idx].content.isEmpty {
        messages.remove(at: idx)
      } else {
        messages[idx].isStreaming = false
      }
    }
    isStreaming = false
    appendSystem("Hata: \(message)")
    delegate?.chatViewModel(self, didChangeActivity: false)
    delegate?.chatViewModelDidFail(self, message: message)
  }

  private func appendSystem(_ text: String) {
    messages.append(ChatMessage(role: .system, content: text))
    notify()
  }

  private func notify() {
    delegate?.chatViewModelDidUpdate(self)
  }
}
