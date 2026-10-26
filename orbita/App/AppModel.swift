import Foundation
import Observation

/// What asking Google for a token ends in.
enum GoogleResult {
    case token(String)
    case cancelled
    case unavailable
}

/// Asks Google for an ID token signed with the API's single-use `nonce`. The app only ships a
/// provider once Google Sign-In is configured for iOS (see docs); without one the button is hidden.
protocol GoogleTokenProvider {
    func idToken(clientId: String, nonce: String) async -> GoogleResult
}

/// What the whole app hangs from: the session, "today", the messages for the user, the back stack
/// and every write. Screens read their data through the repositories of `env` and read it again
/// whenever `revision` changes (after any write, a session change, or coming back to the app).
@Observable
final class AppModel {
    let env: AppEnvironment
    var googleProvider: GoogleTokenProvider?

    private(set) var session: SessionState

    /// Bumped after every successful write, when the session changes and when the app comes back
    /// to the foreground: REST does not tell when something changed, so open screens read again.
    private(set) var revision = 0

    // MARK: Messages

    /// The message on screen (a snackbar); a newer one replaces it instead of queueing behind it.
    private(set) var toast: UiMessage?
    private(set) var toastId = 0

    // MARK: Navigation

    var tab: BottomTab = .home
    var path: [Route] = []

    /// Set when Reportes is opened from a month card of Inicio; the bottom bar clears it.
    var reportFocus: MovementKind?
    var reportSelection: ReportSelection

    // MARK: Signing in

    /// Problem of the last attempt to sign in or sign up, shown in the form itself.
    private(set) var authError: UiMessage?
    private(set) var authBusy = false

    /// The Google client to ask tokens for; nil hides the button (demo, no provider, or the API has none).
    private(set) var googleClientId: String?

    /// A Google token whose email already has an account: its password is asked once to link.
    private struct PendingGoogle {
        let idToken: String
        let nonce: String
        let mainCurrency: String
    }

    private var pendingGoogle: PendingGoogle?
    var googleLinking: Bool { pendingGoogle != nil }

    private var running = false

    init(env: AppEnvironment, googleProvider: GoogleTokenProvider? = nil) {
        self.env = env
        self.googleProvider = googleProvider
        session = env.auth.initialSession
        reportSelection = ReportSelection(today: env.dates.today())
        env.auth.onSessionChange = { [weak self] state in self?.sessionChanged(state) }
        loadGoogleConfig()
    }

    var today: LocalDay { env.dates.today() }

    var isDemo: Bool { env.isDemo }

    var email: String {
        if case .signedIn(let email) = session { return email }
        return ""
    }

    // MARK: Session

    private func sessionChanged(_ state: SessionState) {
        session = state
        // The next person to sign in never sees the previous one's screens.
        path = []
        tab = .home
        reportFocus = nil
        reportSelection = ReportSelection(today: today)
        pendingGoogle = nil
        revision += 1
    }

    /// The app came back to the foreground: everything on screen is read again, since it may
    /// have changed meanwhile on another device.
    func refreshAll() { revision += 1 }

    func signIn(email: String, password: String) {
        let credentials = Credentials(email: email, password: password)
        // The demo has no server to check anything against: it lets anyone in.
        authAction(invalid: isDemo ? nil : credentials.validate()) {
            try await self.env.auth.signIn(credentials)
        }
    }

    /// `name`: how the app calls the user. `mainCurrency`: the currency of their accounts.
    func signUp(name: String, email: String, password: String, mainCurrency: String) {
        let credentials = Credentials(email: email, password: password)
        authAction(invalid: isDemo ? nil : (validateName(name) ?? credentials.validate())) {
            try await self.env.auth.signUp(name: name, credentials: credentials, mainCurrency: mainCurrency)
        }
    }

    func signOut() {
        // Leaving must always work, even offline: the repository drops the local session first.
        Task { await env.auth.signOut() }
    }

    /// Deletes the account and all its data for good. The session ends by itself; a failure
    /// (e.g. a wrong password) is told like any other failed operation.
    func deleteAccount(password: String) {
        if password.isEmpty {
            post(.invalid(.passwordRequired))
            return
        }
        Task {
            do {
                try await env.auth.deleteAccount(password: password)
            } catch {
                post(uiMessage(for: error))
            }
        }
    }

    // MARK: Recovering the password

    /// Asks for the email with the 6-digit code; `onSent` once it is asked.
    func requestPasswordReset(email: String, onSent: @escaping () -> Void) {
        authAction(invalid: validateEmail(email), onDone: onSent) {
            try await self.env.auth.requestPasswordReset(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    /// Checks the code without using it up; `onValid` moves on to the new password.
    func verifyResetCode(email: String, code: String, onValid: @escaping () -> Void) {
        authAction(invalid: validateResetCode(code), onDone: onValid) {
            try await self.env.auth.verifyResetCode(email: email, code: code)
        }
    }

    /// Sets the new password with the code; the user signs in again afterwards.
    func resetPassword(email: String, code: String, password: String, confirmation: String, onDone: @escaping () -> Void) {
        authAction(invalid: validatePasswordChange(password, confirmation: confirmation), onDone: onDone) {
            try await self.env.auth.resetPassword(email: email, code: code, newPassword: password)
        }
    }

    func clearAuthError() { authError = nil }

    /// One step of signing in, signing up or recovering the password. An invalid form is told
    /// in the form itself and nothing is sent; so is a failure. `onDone` runs only on success.
    private func authAction(
        invalid: ValidationError?,
        onDone: @escaping () -> Void = {},
        _ action: @escaping () async throws -> Void
    ) {
        if authBusy { return }
        if let invalid {
            authError = .invalid(invalid)
            return
        }
        authBusy = true
        authError = nil
        Task {
            defer { authBusy = false }
            do {
                try await action()
                onDone()
            } catch is CancellationError {
            } catch {
                authError = uiMessage(for: error)
            }
        }
    }

    // MARK: Continuar con Google

    private func loadGoogleConfig() {
        // Offline, with an older API or without a Google provider there is simply no Google button.
        guard !isDemo, googleProvider != nil else { return }
        Task { googleClientId = try? await env.auth.googleClientId() }
    }

    /// Starts "Continuar con Google": the API's single-use nonce, then the provider for the
    /// token, then the session. `mainCurrency` is only used if the account is new.
    func continueWithGoogle(mainCurrency: String) {
        guard let clientId = googleClientId, let provider = googleProvider else { return }
        pendingGoogle = nil
        authAction(invalid: nil) {
            let nonce = try await self.env.auth.googleNonce()
            switch await provider.idToken(clientId: clientId, nonce: nonce) {
            case .token(let idToken):
                try await self.signInWithGoogle(PendingGoogle(idToken: idToken, nonce: nonce, mainCurrency: mainCurrency), password: nil)
            case .cancelled:
                break
            case .unavailable:
                throw DataException(.googleUnavailable)
            }
        }
    }

    /// Links Google to the account that already has its email, with that account's password.
    func linkGoogle(password: String) {
        guard let pending = pendingGoogle else { return }
        if password.isEmpty {
            authError = .invalid(.passwordRequired)
            return
        }
        authAction(invalid: nil) { try await self.signInWithGoogle(pending, password: password) }
    }

    func cancelGoogleLink() {
        pendingGoogle = nil
        authError = nil
    }

    private func signInWithGoogle(_ pending: PendingGoogle, password: String?) async throws {
        do {
            try await env.auth.signInWithGoogle(
                idToken: pending.idToken, nonce: pending.nonce, mainCurrency: pending.mainCurrency, password: password
            )
            pendingGoogle = nil
        } catch let error as DataException {
            switch error.error {
            case .googleLinkRequired:
                // Not a failure: the screen asks for the password and explains why.
                pendingGoogle = pending
            case .googleInvalid, .googleChallengeExpired:
                // The token cannot be used again: back to the Google button.
                pendingGoogle = nil
                throw error
            default:
                throw error
            }
        }
    }

    // MARK: Writes

    /// Shows `message` on screen for a few seconds.
    func post(_ message: UiMessage) {
        toast = message
        toastId += 1
    }

    func clearToast(id: Int) {
        if toastId == id { toast = nil }
    }

    /// Runs a write. With an `invalid` draft nothing is saved and the user is told why.
    /// `onDone` runs only if `action` succeeds; a failure is reported instead. Taps while a write
    /// is still running are ignored.
    func perform(
        invalid: ValidationError? = nil,
        onDone: @escaping () -> Void = {},
        _ action: @escaping () async throws -> Void
    ) {
        if let invalid {
            post(.invalid(invalid))
            return
        }
        if running { return }
        running = true
        Task {
            defer { running = false }
            do {
                try await action()
                revision += 1
                onDone()
            } catch is CancellationError {
            } catch {
                post(uiMessage(for: error))
            }
        }
    }

    // MARK: Back stack

    func push(_ route: Route) { path.append(route) }

    func pop() {
        if !path.isEmpty { path.removeLast() }
    }

    /// Closes `route` once its save is done, unless the user already left it.
    func close(_ route: Route) {
        if path.last == route { pop() }
    }

    func replaceTop(_ route: Route) {
        if path.isEmpty { path.append(route) } else { path[path.count - 1] = route }
    }

    func open(_ entry: Entry) {
        switch entry {
        case .movement(let movement): push(.movementForm(editing: movement))
        case .transfer(let transfer): push(.transferForm(editing: transfer))
        }
    }

    /// Inicio opens Reportes on the month its cards add up.
    func showReports(focus: MovementKind) {
        reportSelection.mode = .month
        reportSelection.month = today.firstOfMonth
        reportFocus = focus
        tab = .reports
    }
}
