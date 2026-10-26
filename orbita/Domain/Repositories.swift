import Foundation

// The screens only know these contracts. Each one has two implementations: in memory (Data/Demo)
// and against the API (Data/Remote); `AppEnvironment` decides which one is used.
//
// Reads return the current data; the stores in `Stores/` read again after every write. Writes
// throw `DataException` on failure; the drafts they receive are expected to be valid already.

/// Why a read or a write could not be completed, already translated out of the data source.
enum DataError: Hashable {
    case network
    case invalidCredentials
    case emailAlreadyRegistered
    case emailNotConfirmed
    case notFound
    /// Another category of the same kind already has that name (ignoring case and accents).
    case nameTaken
    /// Something in a currency other than the main one, before the exchange rate is set.
    case fxNotConfigured
    /// A paid purchase is not edited nor deleted: undo its payment first.
    case purchaseAlreadyPaid
    /// A credit card is not archived while it has pending purchases.
    case cardHasPendingPurchases
    /// The expense of a credit purchase payment only lets its account, amount and date change:
    /// its category and description are those of the purchase.
    case paymentLocked
    /// The session ended on the server (logged out elsewhere, or the refresh token expired).
    case sessionExpired
    /// Too many attempts in a short time; the API asks to wait.
    case tooManyRequests
    /// The code to recover the password is wrong, used, expired or out of attempts.
    case resetCodeInvalid
    /// Deleting the account with a password that is not the current one.
    case wrongPassword
    // Signing in with Google.
    case googleUnavailable
    case googleInvalid
    case googleChallengeExpired
    /// That email already has an account: its password links Google to it, once.
    case googleLinkRequired
    /// The account already has another Google account linked.
    case googleIdentityConflict
    case unknown
}

/// `invalid` is set when the data source rejected the form itself (the API validates everything
/// again): the screen tells it like its own validation, field by field.
struct DataException: Error {
    let error: DataError
    var invalid: ValidationError?

    init(_ error: DataError, invalid: ValidationError? = nil) {
        self.error = error
        self.invalid = invalid
    }
}

/// "Today" for the app. The demo data pins it; the real one follows the device.
protocol DateProvider {
    func today() -> LocalDay
}

struct SystemDateProvider: DateProvider {
    func today() -> LocalDay { LocalDay.today() }
}

/// The date the demo data is built around (2 oct 2026).
struct FixedDateProvider: DateProvider {
    let day: LocalDay
    func today() -> LocalDay { day }
}

protocol AuthRepository: AnyObject {
    /// What the phone remembers when the app opens: signed in (also offline) or signed out.
    var initialSession: SessionState { get }

    /// Called whenever the session starts or ends.
    var onSessionChange: ((SessionState) -> Void)? { get set }

    func signIn(_ credentials: Credentials) async throws

    /// `name` is how the app calls the user (up to 60 characters). `mainCurrency` is the one
    /// they picked on sign-up: their profile and their first account ("Efectivo") start on it.
    func signUp(name: String, credentials: Credentials, mainCurrency: String) async throws
    func signOut() async

    /// Asks for the email with a 6-digit code to choose a new password. It succeeds whether the
    /// email has an account or not, so that nobody can find out which emails are registered.
    func requestPasswordReset(email: String) async throws

    /// Checks the code of that email without using it up, to move on to the new password. It
    /// lasts 15 minutes and allows 5 attempts; fails with `resetCodeInvalid`.
    func verifyResetCode(email: String, code: String) async throws

    /// Sets the new password with the code and ends every session; it does not sign in.
    func resetPassword(email: String, code: String, newPassword: String) async throws

    /// The Google client the API accepts tokens for, or nil when it offers no Google sign-in.
    func googleClientId() async throws -> String?

    /// A single-use value Google must sign into its token, so a stolen token cannot be replayed.
    func googleNonce() async throws -> String

    /// Signs in with a Google ID token, creating the account (on `mainCurrency`) the first time.
    /// An account that already has that email fails with `googleLinkRequired` until its
    /// `password` is given once, to link Google to it.
    func signInWithGoogle(idToken: String, nonce: String, mainCurrency: String, password: String?) async throws

    /// Deletes the user and every piece of their data for good, and ends the session. It asks
    /// for the password again: an unlocked phone is not enough to delete an account.
    func deleteAccount(password: String) async throws
}

protocol AccountsRepository {
    /// Accounts that are not archived, each with its computed balance.
    func accounts() async throws -> [Account]
    func create(_ draft: AccountDraft, id: String) async throws

    /// The currency and the initial balance of `draft` are ignored: they do not change.
    func update(id: String, _ draft: AccountDraft) async throws
    func setIncludeInSavings(id: String, _ include: Bool) async throws
    func archive(id: String) async throws
}

protocol CategoriesRepository {
    /// Categories that are not archived.
    func categories() async throws -> [Category]
    func create(_ draft: CategoryDraft, id: String) async throws

    /// The kind of `draft` is ignored: it does not change.
    func update(id: String, _ draft: CategoryDraft) async throws
    func archive(id: String) async throws
}

protocol EntriesRepository {
    /// Movements and transfers of `period` mixed, newest first.
    func entries(in period: DatePeriod) async throws -> [Entry]

    /// The newest `limit` movements and transfers.
    func recentEntries(limit: Int) async throws -> [Entry]
    func createMovement(_ draft: MovementDraft, id: String) async throws
    func updateMovement(id: String, _ draft: MovementDraft) async throws

    /// Deleting the expense of a credit purchase payment undoes the payment: the purchase is
    /// pending again. The purchase itself is never deleted from here.
    func deleteMovement(id: String) async throws
    func createTransfer(_ draft: TransferDraft, id: String) async throws
    func updateTransfer(id: String, _ draft: TransferDraft) async throws
    func deleteTransfer(id: String) async throws
}

protocol ReportsRepository {
    /// One report per currency with movements in `period`; empty when there are none.
    func report(for period: DatePeriod) async throws -> [CurrencyReport]
}

protocol CreditRepository {
    /// Credit cards that are not archived.
    func cards() async throws -> [CreditCard]

    /// Purchases still to be paid.
    func pendingPurchases() async throws -> [CreditPurchase]
    func createCard(_ draft: CreditCardDraft, id: String) async throws
    func updateCard(id: String, _ draft: CreditCardDraft) async throws

    /// Fails with `cardHasPendingPurchases` while the card owes anything.
    func archiveCard(id: String) async throws
    func createPurchase(_ draft: CreditPurchaseDraft, id: String) async throws

    /// Only while it is pending. It changes no balance nor report, only the debt of its card.
    /// Moved to another card, the purchase takes that card's currency.
    func updatePurchase(id: String, _ draft: CreditPurchaseDraft) async throws

    /// Only while it is pending.
    func deletePurchase(id: String) async throws

    /// Creates the expense in the paying account and takes the purchase out of the pending ones.
    func pay(_ payment: CreditPayment) async throws
}

protocol SettingsRepository {
    func settings() async throws -> UserSettings
    func setFx(_ fx: FxPair) async throws
    func setDisplayCurrency(_ currency: String) async throws
}

protocol HomeRepository {
    /// Inicio, read again whenever something it shows changes.
    func home() async throws -> HomeSummary
}
