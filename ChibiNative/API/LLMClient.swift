import Foundation

enum StreamEvent {
  case session(id: String)
  case token(String)
  case done(model: String)
  case error(String)
}

enum LLMClientError: LocalizedError {
  case badURL
  case httpStatus(Int, String)
  case decode(String)

  var errorDescription: String? {
    switch self {
    case .badURL: return "Geçersiz API URL"
    case .httpStatus(let code, let body): return "HTTP \(code): \(body)"
    case .decode(let detail): return "Parse hatası: \(detail)"
    }
  }
}

final class LLMClient {
  private let session: URLSession

  init(session: URLSession = .shared) {
    self.session = session
  }

  func checkHealth() async throws {
    guard let url = URL(string: "\(APIConfig.baseURL)/health") else {
      throw LLMClientError.badURL
    }
    var request = URLRequest(url: url)
    request.timeoutInterval = 5
    let (_, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
      let code = (response as? HTTPURLResponse)?.statusCode ?? -1
      throw LLMClientError.httpStatus(code, "health check failed")
    }
  }

  func streamChat(message: String, sessionId: String?) -> AsyncThrowingStream<StreamEvent, Error> {
    AsyncThrowingStream { continuation in
      let task = Task {
        do {
          guard let url = URL(string: "\(APIConfig.baseURL)/chat/stream") else {
            throw LLMClientError.badURL
          }

          var payload: [String: Any] = ["message": message]
          if let sessionId {
            payload["session_id"] = sessionId
          }
          let body = try JSONSerialization.data(withJSONObject: payload)

          var request = URLRequest(url: url)
          request.httpMethod = "POST"
          request.setValue("application/json", forHTTPHeaderField: "Content-Type")
          request.httpBody = body
          request.timeoutInterval = 120

          let (bytes, response) = try await session.bytes(for: request)
          if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            var errBody = ""
            for try await line in bytes.lines {
              errBody += line
              if errBody.count > 500 { break }
            }
            throw LLMClientError.httpStatus(http.statusCode, errBody)
          }

          for try await line in bytes.lines {
            if Task.isCancelled { break }
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard let data = trimmed.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = json["type"] as? String
            else {
              continuation.yield(.error("Bad NDJSON line"))
              continue
            }

            switch type {
            case "session":
              if let id = json["session_id"] as? String {
                continuation.yield(.session(id: id))
              }
            case "token":
              let content = json["content"] as? String ?? ""
              if !content.isEmpty {
                continuation.yield(.token(content))
              }
            case "done":
              let model = json["model"] as? String ?? ""
              continuation.yield(.done(model: model))
            case "error":
              let detail = json["detail"] as? String ?? "bilinmeyen"
              continuation.yield(.error(detail))
            default:
              break
            }
          }
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }
}
