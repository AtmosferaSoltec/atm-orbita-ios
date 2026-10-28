import Foundation

/// Where the app takes its data from. It always talks to the real Orbita API; the in-memory demo
/// only exists for a Debug build that asks for it.
enum AppConfig {
    static let productionURL = "https://orbita-api.atmosferast.com/api/v1"

    /// The production API over HTTPS, in Release and in Debug alike, so pressing Run in Xcode
    /// already uses the real server. A Debug build can instead use, in the Xcode scheme
    /// (*Edit Scheme > Run > Arguments > Environment Variables*):
    /// - `API_BASE_URL`: another API, e.g. `http://192.168.1.10:3001/api/v1`;
    /// - `ORBITA_DEMO` = `1`: the sample data in memory, with no server (the same as Android
    ///   without `API_BASE_URL`).
    static var apiBaseURL: URL? {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        if environment["ORBITA_DEMO"] == "1" { return nil }
        if let raw = environment["API_BASE_URL"], !raw.isEmpty { return URL(string: raw) }
        #endif
        return URL(string: productionURL)
    }
}
