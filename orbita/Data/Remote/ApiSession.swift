import Foundation

/// The session against the API: its tokens and every authorized request.
///
/// - With a refresh token stored, the app opens signed in, also offline; the access token is
///   asked for on the first request.
/// - Before a request without an access token, and after a 401, the session is renewed once and
///   the request repeated. Renewing is serialized: five requests that hit a 401 at the same time
///   produce a single renewal (the API revokes a session whose refresh token is reused).
/// - If renewing is refused, the session is over: back to the login form.
/// - A 401 for a wrong password (deleting the account) is not about the session: no renewal.
final class ApiSession {
    let client: ApiClient
    private let tokens: TokenStore
    private var renewal: Task<String, Error>?

    /// Called whenever the session starts or ends, with the new state.
    var onChange: ((SessionState) -> Void)?

    init(client: ApiClient, tokens: TokenStore) {
        self.client = client
        self.tokens = tokens
    }

    var initialState: SessionState {
        tokens.load().map { .signedIn(email: $0.email) } ?? .signedOut
    }

    /// After signing in or up: the API's tokens for `email`.
    func start(email: String, received: TokensDto) {
        tokens.accessToken = received.accessToken
        tokens.save(StoredSession(email: email, refreshToken: received.refreshToken))
        onChange?(.signedIn(email: email))
    }

    /// Forgets the session on this phone. Always works, also offline.
    func end() {
        tokens.clear()
        onChange?(.signedOut)
    }

    func storedRefreshToken() -> String? { tokens.load()?.refreshToken }

    /// A request with the access token, renewing it once if needed.
    func authorized(_ request: ApiRequest) async throws -> ApiResponse {
        let token: String
        if let current = tokens.accessToken {
            token = current
        } else {
            token = try await renew(stale: nil)
        }
        let first = try await client.send(request, token: token)
        if first.status != 401 || first.isWrongPassword { return first }
        return try await client.send(request, token: try await renew(stale: token))
    }

    /// A fresh access token. `stale` is the one that failed: if another request already renewed
    /// it meanwhile, the new one is used instead of renewing again.
    private func renew(stale: String?) async throws -> String {
        if let current = tokens.accessToken, current != stale { return current }
        if let renewal { return try await renewal.value }
        let task = Task { try await self.performRenewal() }
        renewal = task
        defer { renewal = nil }
        return try await task.value
    }

    private func performRenewal() async throws -> String {
        guard let stored = tokens.load() else {
            end()
            throw DataException(.sessionExpired)
        }
        let response = try await client.send(
            try .send("POST", "auth/refresh", RefreshRequest(refreshToken: stored.refreshToken))
        )
        if response.status == 401 {
            end()
            throw DataException(.sessionExpired)
        }
        let renewed = try response.requireSuccess().decode(RefreshResponse.self).tokens
        tokens.accessToken = renewed.accessToken
        tokens.save(StoredSession(email: stored.email, refreshToken: renewed.refreshToken))
        return renewed.accessToken
    }
}
