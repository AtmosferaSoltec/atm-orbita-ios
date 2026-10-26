import Foundation

/// Where the app takes its data from. Without the URL of the Orbita API everything is the
/// in-memory demo (the same as Android without `API_BASE_URL`).
enum AppConfig {
    static let productionURL = "https://orbita-api.atmosferast.com/api/v1"

    /// Release always talks to production over HTTPS. Debug uses the `API_BASE_URL` variable of the
    /// Xcode scheme (e.g. `http://192.168.1.10:3001/api/v1`); without it, the app runs in demo mode.
    static var apiBaseURL: URL? {
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["API_BASE_URL"], !raw.isEmpty {
            return URL(string: raw)
        }
        return nil
        #else
        return URL(string: productionURL)
        #endif
    }
}
