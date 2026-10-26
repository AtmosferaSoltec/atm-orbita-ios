import Foundation

// In-memory implementations of the repositories, seeded with SampleData. They behave like the
// real backend is specified to so every screen works end to end before the API is connected;
// nothing survives closing the app.

/// The whole demo "database", shared by every demo repository.
final class DemoStore {
    private(set) var state = SampleData.seed

    /// Applies `change` to a copy and keeps it only if it did not throw, so a rejected write
    /// leaves the data as it was.
    func write(_ change: (inout DemoState) throws -> Void) throws {
        var copy = state
        try change(&copy)
        state = copy
    }

    /// Back to the sample data, as when the app starts.
    func reset() { state = SampleData.seed }
}

private func notFound() -> DataException { DataException(.notFound) }

private func money(_ value: Decimal?) throws -> Decimal {
    guard let value else { throw notFound() }
    return value.rounded(scale: 2)
}

extension DemoState {
    /// Without an exchange rate, nothing can be in a currency other than the main one.
    func requireUsable(_ currency: String) throws {
        if !settings.fx.isConfigured && currency != settings.fx.main { throw DataException(.fxNotConfigured) }
    }

    /// A category name is unique per kind among the ones not archived, ignoring case and accents.
    /// `exceptId` is the category being renamed, which never clashes with itself.
    func requireFreeName(_ name: String, kind: MovementKind, exceptId: String? = nil) throws {
        let key = normalizeName(name)
        let taken = categories.contains {
            !$0.archived && $0.category.kind == kind && $0.category.id != exceptId
                && normalizeName($0.category.name) == key
        }
        if taken { throw DataException(.nameTaken) }
    }
}

/// The demo data pins "today" to the day its sample was written for.
struct DemoDateProvider: DateProvider {
    func today() -> LocalDay { SampleData.today }
}

/// Accepts any credentials: there is no server to check them against. Recovering the password
/// and deleting the account go through the same steps as with the API, but nothing is sent and
/// no password is checked.
final class DemoAuthRepository: AuthRepository {
    private let store: DemoStore

    init(store: DemoStore) { self.store = store }

    var onSessionChange: ((SessionState) -> Void)?

    let initialSession = SessionState.signedOut

    func signIn(_ credentials: Credentials) async throws {
        let email = credentials.email.trimmingCharacters(in: .whitespacesAndNewlines)
        onSessionChange?(.signedIn(email: email.isEmpty ? SampleData.userEmail : email))
    }

    // The sample data is the same for everyone, so the name and the currency picked on sign-up
    // change nothing here; with the API the user starts with them.
    func signUp(name: String, credentials: Credentials, mainCurrency: String) async throws {
        try await signIn(credentials)
    }

    func signOut() async { onSessionChange?(.signedOut) }

    // No email is sent: the app itself offers the way to the next screen.
    func requestPasswordReset(email: String) async throws {}

    // There is no email in the demo: any 6-digit code works.
    func verifyResetCode(email: String, code: String) async throws {}

    func resetPassword(email: String, code: String, newPassword: String) async throws {}

    // There is no Google in the demo: the button is not shown.
    func googleClientId() async throws -> String? { nil }

    func googleNonce() async throws -> String { throw DataException(.googleUnavailable) }

    func signInWithGoogle(idToken: String, nonce: String, mainCurrency: String, password: String?) async throws {
        throw DataException(.googleUnavailable)
    }

    /// The account "is gone": the data goes back to the sample and the session ends.
    func deleteAccount(password: String) async throws {
        store.reset()
        onSessionChange?(.signedOut)
    }
}

final class DemoAccountsRepository: AccountsRepository {
    private let store: DemoStore

    init(store: DemoStore) { self.store = store }

    func accounts() async throws -> [Account] { store.state.activeAccounts }

    func create(_ draft: AccountDraft, id: String) async throws {
        try store.write { state in
            try state.requireUsable(draft.currency)
            state.accounts.append(AccountRecord(
                id: id, name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
                type: draft.type, currency: draft.currency,
                initialBalance: draft.initialBalance.rounded(scale: 2),
                includeInSavings: draft.includeInSavings
            ))
        }
    }

    func update(id: String, _ draft: AccountDraft) async throws {
        try change(id) {
            $0.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            $0.type = draft.type
            $0.includeInSavings = draft.includeInSavings
        }
    }

    func setIncludeInSavings(id: String, _ include: Bool) async throws {
        try change(id) { $0.includeInSavings = include }
    }

    func archive(id: String) async throws { try change(id) { $0.archived = true } }

    private func change(_ id: String, _ change: (inout AccountRecord) -> Void) throws {
        try store.write { state in
            guard let index = state.accounts.firstIndex(where: { $0.id == id }) else { throw notFound() }
            change(&state.accounts[index])
        }
    }
}

final class DemoCategoriesRepository: CategoriesRepository {
    private let store: DemoStore

    init(store: DemoStore) { self.store = store }

    func categories() async throws -> [Category] { store.state.activeCategories }

    func create(_ draft: CategoryDraft, id: String) async throws {
        try store.write { state in
            try state.requireFreeName(draft.name, kind: draft.kind)
            state.categories.append(CategoryRecord(
                category: Category(id: id, name: cleanName(draft.name), kind: draft.kind, colorHex: draft.colorHex)
            ))
        }
    }

    // The name is kept as typed; only its comparison ignores case and accents.
    func update(id: String, _ draft: CategoryDraft) async throws {
        try store.write { state in
            guard let index = state.categories.firstIndex(where: { $0.category.id == id }) else { throw notFound() }
            try state.requireFreeName(draft.name, kind: state.categories[index].category.kind, exceptId: id)
            state.categories[index].category.name = cleanName(draft.name)
            state.categories[index].category.colorHex = draft.colorHex
        }
    }

    func archive(id: String) async throws {
        try store.write { state in
            guard let index = state.categories.firstIndex(where: { $0.category.id == id }) else { throw notFound() }
            state.categories[index].archived = true
        }
    }
}

final class DemoEntriesRepository: EntriesRepository {
    private let store: DemoStore
    private let dates: DateProvider

    init(store: DemoStore, dates: DateProvider) {
        self.store = store
        self.dates = dates
    }

    func entries(in period: DatePeriod) async throws -> [Entry] {
        store.state.entries.filter { period.contains($0.date) }
    }

    func recentEntries(limit: Int) async throws -> [Entry] {
        Array(store.state.entries.prefix(limit))
    }

    func createMovement(_ draft: MovementDraft, id: String) async throws {
        let today = dates.today()
        try store.write { state in
            guard let categoryId = draft.categoryId, let accountId = draft.accountId else { throw notFound() }
            state.movements.append(MovementRecord(
                id: id, description: draft.description.trimmingCharacters(in: .whitespacesAndNewlines),
                categoryId: categoryId, accountId: accountId, date: draft.date ?? today,
                amount: try money(draft.amount), order: state.nextOrder
            ))
            state.nextOrder += 1
        }
    }

    func updateMovement(id: String, _ draft: MovementDraft) async throws {
        try store.write { state in
            guard let index = state.movements.firstIndex(where: { $0.id == id }) else { throw notFound() }
            let current = state.movements[index]
            let description = draft.description.trimmingCharacters(in: .whitespacesAndNewlines)
            // The expense of a payment keeps the category and the description of its purchase:
            // only the account, the amount and the date of the payment can change.
            let isPayment = state.purchases.contains { $0.paymentMovementId == id }
            if isPayment && (draft.categoryId != current.categoryId || description != current.description) {
                throw DataException(.paymentLocked)
            }
            guard let categoryId = draft.categoryId, let accountId = draft.accountId else { throw notFound() }
            state.movements[index].description = description
            state.movements[index].categoryId = categoryId
            state.movements[index].accountId = accountId
            state.movements[index].date = draft.date ?? current.date
            state.movements[index].amount = try money(draft.amount)
        }
    }

    func deleteMovement(id: String) async throws {
        try store.write { state in
            // Deleting the expense of a payment undoes the payment: the purchase is pending again.
            // Its card comes back if it was archived meanwhile, so no debt is ever out of sight.
            let unpaid = state.purchases.first { $0.paymentMovementId == id }
            state.movements.removeAll { $0.id == id }
            if let unpaid {
                if let index = state.purchases.firstIndex(where: { $0.id == unpaid.id }) {
                    state.purchases[index].paid = false
                    state.purchases[index].paymentMovementId = nil
                }
                if let index = state.cards.firstIndex(where: { $0.card.id == unpaid.cardId }) {
                    state.cards[index].archived = false
                }
            }
        }
    }

    func createTransfer(_ draft: TransferDraft, id: String) async throws {
        try store.write { state in
            state.transfers.append(TransferRecord(
                id: id, note: draft.note.trimmingCharacters(in: .whitespacesAndNewlines),
                fromId: draft.fromAccountId, toId: draft.toAccountId, date: draft.date,
                fromAmount: try money(draft.fromAmount), toAmount: try money(draft.toAmount),
                exchangeRate: draft.exchangeRate, order: state.nextOrder
            ))
            state.nextOrder += 1
        }
    }

    func updateTransfer(id: String, _ draft: TransferDraft) async throws {
        try store.write { state in
            guard let index = state.transfers.firstIndex(where: { $0.id == id }) else { throw notFound() }
            state.transfers[index].note = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
            state.transfers[index].fromId = draft.fromAccountId
            state.transfers[index].toId = draft.toAccountId
            state.transfers[index].date = draft.date
            state.transfers[index].fromAmount = try money(draft.fromAmount)
            state.transfers[index].toAmount = try money(draft.toAmount)
            state.transfers[index].exchangeRate = draft.exchangeRate
        }
    }

    func deleteTransfer(id: String) async throws {
        try store.write { $0.transfers.removeAll { $0.id == id } }
    }
}

final class DemoReportsRepository: ReportsRepository {
    private let store: DemoStore

    init(store: DemoStore) { self.store = store }

    func report(for period: DatePeriod) async throws -> [CurrencyReport] { store.state.report(for: period) }
}

final class DemoCreditRepository: CreditRepository {
    private let store: DemoStore
    private let dates: DateProvider

    init(store: DemoStore, dates: DateProvider) {
        self.store = store
        self.dates = dates
    }

    func cards() async throws -> [CreditCard] { store.state.activeCards }

    func pendingPurchases() async throws -> [CreditPurchase] { store.state.pendingPurchases }

    func createCard(_ draft: CreditCardDraft, id: String) async throws {
        try store.write { state in
            try state.requireUsable(draft.currency)
            state.cards.append(CardRecord(
                card: CreditCard(id: id, name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines), currency: draft.currency)
            ))
        }
    }

    func updateCard(id: String, _ draft: CreditCardDraft) async throws {
        try store.write { state in
            try state.requireUsable(draft.currency)
            guard let index = state.cards.firstIndex(where: { $0.card.id == id }) else { throw notFound() }
            state.cards[index].card.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            state.cards[index].card.currency = draft.currency
        }
    }

    func archiveCard(id: String) async throws {
        try store.write { state in
            // A card that still owes something stays in sight: pay or delete its purchases first.
            if state.purchases.contains(where: { $0.cardId == id && !$0.paid }) {
                throw DataException(.cardHasPendingPurchases)
            }
            guard let index = state.cards.firstIndex(where: { $0.card.id == id }) else { throw notFound() }
            state.cards[index].archived = true
        }
    }

    func createPurchase(_ draft: CreditPurchaseDraft, id: String) async throws {
        let today = dates.today()
        try store.write { state in
            guard let card = state.cards.first(where: { $0.card.id == draft.cardId && !$0.archived })?.card,
                  let categoryId = draft.categoryId
            else { throw notFound() }
            state.purchases.append(PurchaseRecord(
                id: id, cardId: card.id, description: draft.description.trimmingCharacters(in: .whitespacesAndNewlines),
                categoryId: categoryId, purchaseDate: today, dueDate: draft.dueDate,
                amount: try money(draft.amount), currency: card.currency
            ))
        }
    }

    func updatePurchase(id: String, _ draft: CreditPurchaseDraft) async throws {
        try store.write { state in
            guard let index = state.purchases.firstIndex(where: { $0.id == id }) else { throw notFound() }
            if state.purchases[index].paid { throw DataException(.purchaseAlreadyPaid) }
            guard let card = state.cards.first(where: { $0.card.id == draft.cardId && !$0.archived })?.card,
                  let categoryId = draft.categoryId
            else { throw notFound() }
            let record = state.purchases[index]
            state.purchases[index].description = draft.description.trimmingCharacters(in: .whitespacesAndNewlines)
            state.purchases[index].categoryId = categoryId
            state.purchases[index].dueDate = draft.dueDate
            state.purchases[index].amount = try money(draft.amount)
            // Moved to another card, it takes that card's currency; otherwise it keeps the one it
            // was bought in, even if its card changed currency since.
            state.purchases[index].currency = card.id == record.cardId ? record.currency : card.currency
            state.purchases[index].cardId = card.id
        }
    }

    func deletePurchase(id: String) async throws {
        try store.write { state in
            // Already gone: deleting twice is not an error.
            guard let current = state.purchases.first(where: { $0.id == id }) else { return }
            if current.paid { throw DataException(.purchaseAlreadyPaid) }
            state.purchases.removeAll { $0.id == id }
        }
    }

    /// The expense and the paid mark go together.
    func pay(_ payment: CreditPayment) async throws {
        try store.write { state in
            guard let index = state.purchases.firstIndex(where: { $0.id == payment.purchaseId }) else { throw notFound() }
            let purchase = state.purchases[index]
            if purchase.paid { throw DataException(.purchaseAlreadyPaid) }
            guard let accountId = payment.accountId else { throw notFound() }
            let movementId = UUID().uuidString
            state.purchases[index].paid = true
            state.purchases[index].paymentMovementId = movementId
            state.movements.append(MovementRecord(
                id: movementId, description: purchase.description, categoryId: purchase.categoryId,
                accountId: accountId, date: payment.paidOn, amount: try money(payment.paidAmount),
                order: state.nextOrder
            ))
            state.nextOrder += 1
        }
    }
}

final class DemoSettingsRepository: SettingsRepository {
    private let store: DemoStore

    init(store: DemoStore) { self.store = store }

    func settings() async throws -> UserSettings { store.state.settings }

    func setFx(_ fx: FxPair) async throws {
        try store.write { state in
            // A pair of currencies is only saved together with its rate, and never with a made-up one.
            guard let rate = fx.rate, rate > 0 else { throw DataException(.fxNotConfigured) }
            _ = rate
            // The total is always shown in one of the two currencies of the pair.
            let current = state.settings.displayCurrency
            let display = (current == fx.main || current == fx.secondary) ? current : fx.main
            state.settings = UserSettings(fx: fx, displayCurrency: display)
        }
    }

    func setDisplayCurrency(_ currency: String) async throws {
        try store.write { state in
            try state.requireUsable(currency)
            state.settings.displayCurrency = currency
        }
    }
}

/// Inicio from the demo data: the same pieces the API puts together in `GET /home`, worked out
/// the same way.
final class DemoHomeRepository: HomeRepository {
    /// How many entries Inicio lists under "Últimos movimientos".
    static let recentEntries = 4

    private let accounts: AccountsRepository
    private let settings: SettingsRepository
    private let entries: EntriesRepository
    private let reports: ReportsRepository
    private let credit: CreditRepository
    private let dates: DateProvider

    init(
        accounts: AccountsRepository, settings: SettingsRepository, entries: EntriesRepository,
        reports: ReportsRepository, credit: CreditRepository, dates: DateProvider
    ) {
        self.accounts = accounts
        self.settings = settings
        self.entries = entries
        self.reports = reports
        self.credit = credit
        self.dates = dates
    }

    func home() async throws -> HomeSummary {
        let today = dates.today()
        return Self.homeOf(
            accounts: try await accounts.accounts(),
            settings: try await settings.settings(),
            recent: try await entries.recentEntries(limit: Self.recentEntries),
            monthReports: try await reports.report(for: .ofMonth(today)),
            purchases: try await credit.pendingPurchases(),
            today: today
        )
    }

    /// Inicio from its pieces, as `GET /home` composes it.
    static func homeOf(
        accounts: [Account], settings: UserSettings, recent: [Entry], monthReports: [CurrencyReport],
        purchases: [CreditPurchase], today: LocalDay
    ) -> HomeSummary {
        let fx = settings.fx
        let currencies = fx.isConfigured ? [fx.main, fx.secondary] : [fx.main]
        let month = monthReports.first { $0.currency == fx.main }
        var savings: [String: Decimal] = [:]
        for currency in currencies { savings[currency] = fx.savingsTotal(of: accounts, in: currency) }
        let reminder: CreditReminder? = purchases.isEmpty ? nil : CreditReminder(
            pendingCount: purchases.count,
            nextDueDate: purchases.map(\.dueDate).min()!,
            hasUrgent: purchases.contains { $0.isUrgent(today: today) }
        )
        return HomeSummary(
            fx: fx, displayCurrency: settings.displayCurrency, savings: savings,
            includedAccounts: accounts.filter(\.includeInSavings).count, activeAccounts: accounts.count,
            monthIncome: month?.incomeTotal ?? 0, monthExpense: month?.expenseTotal ?? 0,
            recentEntries: recent, credit: reminder
        )
    }
}
