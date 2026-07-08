import Foundation

enum APIConfig {
  /// Mac istemci → PC production API (LAN). Override: `defaults write com.talo.ChibiNative API_URL "http://…"`
  static let defaultURL = "http://192.168.1.233:8000"

  static var baseURL: String {
    let raw = UserDefaults.standard.string(forKey: "API_URL") ?? defaultURL
    return raw.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
  }
}
