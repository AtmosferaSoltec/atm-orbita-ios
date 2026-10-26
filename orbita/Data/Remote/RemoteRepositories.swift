import Foundation

// The repositories against the API (atm-orbita-api). They keep nothing: REST does not tell when
// something changed, so the stores read again after every write.

extension ApiSession {
    /// An authorized request that must succeed.
    @discardableResult
    func call(_ request: ApiRequest) async throws -> ApiResponse {
        try await authorized(request).requireSuccess()
    }
}

private func required<T>(_ value: T?, _ error: DataError = .unknown) throws -> T {
    guard let value else { throw DataException(error) }
    return value
}

// MARK: - Auth

/// Signing in, up and out, recovering the password, deleting the account and signing in with Google.
final class RemoteAuthRepository: AuthRepository {
    private let api: ApiSession

    init(api: ApiSession) {
        self.api = api
        api.onChange = { [weak self] state in self?.onSessionChange?(state) }
    }

    var onSessionChange: ((SessionState) -> Void)?

    var initialSession: SessionState { api.initialState }

    func signIn(_ credentials: Credentials) async throws {
        let email = credentials.email.trimmingCharacters(in: .whitespacesAndNewlines)
        let response = try await api.client.send(
            try .send("POST", "auth/login", LoginRequest(email: email, password: credentials.password))
        )
        let auth = try response.requireSuccess().decode(AuthResponse.self)
        api.start(email: auth.user.email, received: auth.tokens)
    }

    func signUp(name: String, credentials: Credentials, mainCurrency: String) async throws {
        let request = RegisterRequest(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            email: credentials.email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: credentials.password,
            mainCurrency: mainCurrency,
            timezone: TimeZone.current.identifier
        )
        let response = try await api.client.send(try .send("POST", "auth/register", request))
        let auth = try response.requireSuccess().decode(AuthResponse.self)
        api.start(email: auth.user.email, received: auth.tokens)
    }

    /// Leaving must always work, even offline: the phone forgets the session first, then the
    /// API is told so the session can no longer be renewed anywhere.
    func signOut() async {
        let refreshToken = api.storedRefreshToken()
        api.end()
        if let refreshToken, let request = try? ApiRequest.send("POST", "auth/logout", RefreshRequest(refreshToken: refreshToken)) {
            _ = try? await api.client.send(request)
        }
    }

    // Recovering the password: public calls, no session involved.

    func requestPasswordReset(email: String) async throws {
        let body = ResetRequest(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
        try await api.client.send(try .send("POST", "auth/forgot-password", body)).requireSuccess()
    }

    func verifyResetCode(email: String, code: String) async throws {
        let body = ResetRequest(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            code: code.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        try await api.client.send(try .send("POST", "auth/verify-reset-code", body)).requireSuccess()
    }

    func resetPassword(email: String, code: String, newPassword: String) async throws {
        let body = ResetRequest(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            code: code.trimmingCharacters(in: .whitespacesAndNewlines),
            newPassword: newPassword
        )
        try await api.client.send(try .send("POST", "auth/reset-password", body)).requireSuccess()
    }

    // Signing in with Google, the native way: the nonce and the tokens travel in the body.
    // Google itself is asked by the screen.

    func googleClientId() async throws -> String? {
        let response = try await api.client.send(.get("auth/google/config"))
        let id = try response.requireSuccess().decode(GoogleConfigDto.self).clientId ?? ""
        return id.isEmpty ? nil : id
    }

    func googleNonce() async throws -> String {
        let response = try await api.client.send(try .send("POST", "auth/google/challenge", EmptyBody()))
        return try response.requireSuccess().decode(GoogleChallengeDto.self).nonce
    }

    func signInWithGoogle(idToken: String, nonce: String, mainCurrency: String, password: String?) async throws {
        let body = GoogleSignInRequest(
            nonce: nonce, credential: idToken, mainCurrency: mainCurrency,
            timezone: TimeZone.current.identifier, password: password
        )
        let response = try await api.client.send(try .send("POST", "auth/google", body))
        let auth = try response.requireSuccess().decode(AuthResponse.self)
        api.start(email: auth.user.email, received: auth.tokens)
    }

    /// Deletes the account and all its data for good. A wrong password keeps the session; once
    /// deleted, the phone forgets it and goes back to the login form.
    func deleteAccount(password: String) async throws {
        let response = try await api.authorized(try .send("DELETE", "me", DeleteAccountRequest(password: password)))
        // Here the API's "wrong email or password" can only be the password.
        if response.isWrongPassword { throw DataException(.wrongPassword) }
        try response.requireSuccess()
        api.end()
    }
}

// MARK: - Accounts

final class RemoteAccountsRepository: AccountsRepository {
    private let api: ApiSession

    init(api: ApiSession) { self.api = api }

    func accounts() async throws -> [Account] {
        try await api.call(.get("accounts")).decode(AccountListDto.self).accounts.map { $0.toAccount() }
    }

    func create(_ draft: AccountDraft, id: String) async throws {
        let request = CreateAccountRequest(
            id: id, name: draft.name, type: draft.type.apiValue, currency: draft.currency,
            initialBalance: ApiDecimal(draft.initialBalance, scale: 2),
            includeInSavings: draft.includeInSavings
        )
        try await api.call(try .send("POST", "accounts", request))
    }

    func update(id: String, _ draft: AccountDraft) async throws {
        try await patch(id, UpdateAccountRequest(name: draft.name, type: draft.type.apiValue, includeInSavings: draft.includeInSavings))
    }

    func setIncludeInSavings(id: String, _ include: Bool) async throws {
        try await patch(id, UpdateAccountRequest(includeInSavings: include))
    }

    func archive(id: String) async throws {
        try await api.call(.post("accounts/\(id)/archive"))
    }

    private func patch(_ id: String, _ request: UpdateAccountRequest) async throws {
        try await api.call(try .send("PATCH", "accounts/\(id)", request))
    }
}

// MARK: - Categories

final class RemoteCategoriesRepository: CategoriesRepository {
    private let api: ApiSession

    init(api: ApiSession) { self.api = api }

    func categories() async throws -> [Category] {
        try await api.call(.get("categories")).decode([CategoryDto].self).map { $0.toCategory() }
    }

    func create(_ draft: CategoryDraft, id: String) async throws {
        let request = CreateCategoryRequest(id: id, name: draft.name, kind: draft.kind.apiValue, color: draft.colorHex)
        try await api.call(try .send("POST", "categories", request))
    }

    func update(id: String, _ draft: CategoryDraft) async throws {
        try await api.call(try .send("PATCH", "categories/\(id)", UpdateCategoryRequest(name: draft.name, color: draft.colorHex)))
    }

    func archive(id: String) async throws {
        try await api.call(.post("categories/\(id)/archive"))
    }
}

// MARK: - Entries

/// Incomes, expenses and transfers. A list is read with all its pages.
final class RemoteEntriesRepository: EntriesRepository {
    private let api: ApiSession

    /// The most the API gives per page.
    private let pageSize = 100

    init(api: ApiSession) { self.api = api }

    func entries(in period: DatePeriod) async throws -> [Entry] {
        var out: [Entry] = []
        var page = 1
        while true {
            let result = try await readPage(from: period.from, to: period.to, page: page, pageSize: pageSize)
            out += try result.data.map { try $0.toEntry() }
            page += 1
            if out.count >= result.meta.total || result.data.isEmpty { break }
        }
        return out
    }

    /// The newest ones of the last 10 years (the longest period the API lists at once).
    func recentEntries(limit: Int) async throws -> [Entry] {
        // Tomorrow, so a movement saved today in a zone ahead of the phone's still shows.
        let to = LocalDay.today().adding(days: 1)
        let from = to.adding(months: -120).adding(days: 1)
        return try await readPage(from: from, to: to, page: 1, pageSize: limit).data.map { try $0.toEntry() }
    }

    func createMovement(_ draft: MovementDraft, id: String) async throws {
        try await api.call(try .send("POST", "transactions", try request(draft, id: id)))
    }

    func updateMovement(id: String, _ draft: MovementDraft) async throws {
        try await api.call(try .send("PATCH", "transactions/\(id)", try request(draft, id: nil)))
    }

    func deleteMovement(id: String) async throws {
        try await api.call(.delete("transactions/\(id)"))
    }

    func createTransfer(_ draft: TransferDraft, id: String) async throws {
        try await api.call(try .send("POST", "transfers", try request(draft, id: id)))
    }

    func updateTransfer(id: String, _ draft: TransferDraft) async throws {
        try await api.call(try .send("PATCH", "transfers/\(id)", try request(draft, id: nil)))
    }

    func deleteTransfer(id: String) async throws {
        try await api.call(.delete("transfers/\(id)"))
    }

    private func readPage(from: LocalDay, to: LocalDay, page: Int, pageSize: Int) async throws -> EntryPageDto {
        let query = [
            URLQueryItem(name: "from", value: from.isoString),
            URLQueryItem(name: "to", value: to.isoString),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "page_size", value: String(pageSize)),
        ]
        let response = try await api.call(.get("entries", query: query))
        do {
            return try ApiJson.decoder.decode(EntryPageDto.self, from: response.data)
        } catch {
            throw DataException(.unknown)
        }
    }

    private func request(_ draft: MovementDraft, id: String?) throws -> TransactionRequest {
        TransactionRequest(
            id: id,
            accountId: try required(draft.accountId, .notFound),
            categoryId: try required(draft.categoryId, .notFound),
            amount: ApiDecimal(try required(draft.amount), scale: 2),
            description: draft.description,
            occurredOn: draft.date?.isoString
        )
    }

    // The API keeps 2 decimals for amounts and 6 for the rate, which is informative: what moves
    // the balances are the two amounts the form already worked out.
    private func request(_ draft: TransferDraft, id: String?) throws -> TransferRequest {
        TransferRequest(
            id: id,
            fromAccountId: draft.fromAccountId,
            toAccountId: draft.toAccountId,
            fromAmount: ApiDecimal(try required(draft.fromAmount), scale: 2),
            toAmount: ApiDecimal(try required(draft.toAmount), scale: 2),
            exchangeRate: draft.exchangeRate.map { ApiDecimal($0, scale: 6) },
            occurredOn: draft.date.isoString,
            note: draft.note
        )
    }
}

// MARK: - Reports

final class RemoteReportsRepository: ReportsRepository {
    private let api: ApiSession

    init(api: ApiSession) { self.api = api }

    func report(for period: DatePeriod) async throws -> [CurrencyReport] {
        let query = [
            URLQueryItem(name: "from", value: period.from.isoString),
            URLQueryItem(name: "to", value: period.to.isoString),
        ]
        return try await api.call(.get("reports/summary", query: query))
            .decode(SummaryDto.self).currencies.map { $0.toReport() }
    }
}

// MARK: - Credit

/// Credit cards and their pending purchases. A pending purchase moves no balance; paying it
/// creates its expense in the same request.
final class RemoteCreditRepository: CreditRepository {
    private let api: ApiSession

    init(api: ApiSession) { self.api = api }

    func cards() async throws -> [CreditCard] {
        try await api.call(.get("credit-cards")).decode([CardDto].self).map { $0.toCard() }
    }

    func pendingPurchases() async throws -> [CreditPurchase] {
        let response = try await api.call(.get("credit-purchases", query: [URLQueryItem(name: "status", value: "pending")]))
        return try response.decode([PurchaseDto].self).map { try $0.toPurchase() }
    }

    func createCard(_ draft: CreditCardDraft, id: String) async throws {
        try await api.call(try .send("POST", "credit-cards", CardRequest(id: id, name: draft.name, currency: draft.currency)))
    }

    func updateCard(id: String, _ draft: CreditCardDraft) async throws {
        try await api.call(try .send("PATCH", "credit-cards/\(id)", CardRequest(name: draft.name, currency: draft.currency)))
    }

    func archiveCard(id: String) async throws {
        try await api.call(.post("credit-cards/\(id)/archive"))
    }

    func createPurchase(_ draft: CreditPurchaseDraft, id: String) async throws {
        try await api.call(try .send("POST", "credit-purchases", try request(draft, id: id)))
    }

    func updatePurchase(id: String, _ draft: CreditPurchaseDraft) async throws {
        try await api.call(try .send("PATCH", "credit-purchases/\(id)", try request(draft, id: nil)))
    }

    func deletePurchase(id: String) async throws {
        try await api.call(.delete("credit-purchases/\(id)"))
    }

    /// Creates the expense in the paying account and takes the purchase out of the pending ones,
    /// in one step on the API.
    func pay(_ payment: CreditPayment) async throws {
        let body = PayRequest(
            accountId: try required(payment.accountId, .notFound),
            paidAmount: ApiDecimal(try required(payment.paidAmount), scale: 2),
            paidOn: payment.paidOn.isoString
        )
        try await api.call(try .send("POST", "credit-purchases/\(payment.purchaseId)/pay", body))
    }

    private func request(_ draft: CreditPurchaseDraft, id: String?) throws -> PurchaseRequest {
        PurchaseRequest(
            id: id,
            cardId: try required(draft.cardId, .notFound),
            categoryId: try required(draft.categoryId, .notFound),
            amount: ApiDecimal(try required(draft.amount), scale: 2),
            description: draft.description,
            dueDate: draft.dueDate.isoString
        )
    }
}

// MARK: - Settings and Home

final class RemoteSettingsRepository: SettingsRepository {
    private let api: ApiSession

    init(api: ApiSession) { self.api = api }

    func settings() async throws -> UserSettings {
        try await api.call(.get("settings")).decode(SettingsDto.self).toUserSettings()
    }

    /// A pair is only saved together with a rate above zero; the API checks it again.
    func setFx(_ fx: FxPair) async throws {
        guard let rate = fx.rate, rate > 0 else { throw DataException(.fxNotConfigured) }
        // The API keeps 6 decimals, like the inverse the app computes when the pair is swapped.
        let body = SetFxRequest(mainCurrency: fx.main, secondaryCurrency: fx.secondary, rate: ApiDecimal(rate, scale: 6))
        try await api.call(try .send("PUT", "settings/fx", body))
    }

    func setDisplayCurrency(_ currency: String) async throws {
        try await api.call(try .send("PATCH", "settings", UpdateSettingsRequest(displayCurrency: currency)))
    }
}

/// Inicio in a single request.
final class RemoteHomeRepository: HomeRepository {
    private let api: ApiSession

    init(api: ApiSession) { self.api = api }

    func home() async throws -> HomeSummary {
        try await api.call(.get("home")).decode(HomeDto.self).toSummary()
    }
}
