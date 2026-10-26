import Observation

/// What a screen shows while its data arrives, when it fails and once it is there.
enum Load<T> {
    case loading
    case failed
    case ready(T)

    var value: T? {
        if case .ready(let value) = self { return value }
        return nil
    }
}

/// The data a screen shows: while it first arrives it is `loading`, and a failure to read (no
/// connection, the server down, the session over) is `failed` instead of crashing the app. A read
/// that fails after the data was there keeps what was shown; coming back to a screen does not
/// blank it again.
@Observable
final class Loader<T> {
    private(set) var state: Load<T> = .loading

    /// Bumped by "Reintentar"; the screen reads again when it changes.
    private(set) var attempt = 0

    func run(_ source: () async throws -> T) async {
        do {
            let value = try await source()
            if !Task.isCancelled { state = .ready(value) }
        } catch is CancellationError {
            return
        } catch {
            if Task.isCancelled { return }
            if state.value == nil { state = .failed }
        }
    }

    /// "Reintentar": shows the loading state again and asks the screen to read again.
    func retry() {
        state = .loading
        attempt += 1
    }
}
