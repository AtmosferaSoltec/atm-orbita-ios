import Foundation

// Bodies of the API (atm-orbita-api). The JSON coders convert camelCase ⇄ snake_case.

// MARK: - Auth

struct RegisterRequest: Encodable {
    let name: String
    let email: String
    let password: String
    let mainCurrency: String
    /// IANA zone of the phone: the API computes "today" with it.
    let timezone: String
}

struct LoginRequest: Encodable {
    let email: String
    let password: String
}

struct RefreshRequest: Encodable {
    let refreshToken: String
}

struct UserDto: Decodable {
    let id: String
    let email: String
}

struct TokensDto: Decodable {
    let accessToken: String
    let accessTokenExpiresIn: Int
    let refreshToken: String
}

struct AuthResponse: Decodable {
    let user: UserDto
    let tokens: TokensDto
}

struct RefreshResponse: Decodable {
    let tokens: TokensDto
}

/// Body of the three steps of recovering the password; each sends what it has so far.
struct ResetRequest: Encodable {
    let email: String
    var code: String?
    var newPassword: String?
}

/// Deleting the account asks for the password again.
struct DeleteAccountRequest: Encodable {
    let password: String
}

/// Sign in with Google: an empty client ID means it is off.
struct GoogleConfigDto: Decodable {
    var clientId: String?
}

struct GoogleChallengeDto: Decodable {
    let nonce: String
}

struct EmptyBody: Encodable {}

struct GoogleSignInRequest: Encodable {
    let nonce: String
    let credential: String
    let mainCurrency: String
    let timezone: String
    /// Only to link Google to an account that already has this email.
    var password: String?
}

// MARK: - Accounts

struct AccountListDto: Decodable {
    let accounts: [AccountDto]
}

func accountType(fromApi value: String) -> AccountType {
    switch value {
    case "cash": .cash
    case "debit": .debit
    case "savings": .savings
    default: .other
    }
}

extension AccountType {
    var apiValue: String {
        switch self {
        case .cash: "cash"
        case .debit: "debit"
        case .savings: "savings"
        case .other: "other"
        }
    }
}

struct AccountDto: Decodable {
    let id: String
    let name: String
    let type: String
    let currency: String
    let balance: ApiDecimal
    let includeInSavings: Bool

    func toAccount() -> Account {
        Account(
            id: id, name: name, type: accountType(fromApi: type), currency: currency,
            balance: balance.value, includeInSavings: includeInSavings
        )
    }
}

struct CreateAccountRequest: Encodable {
    /// Chosen by the app: retrying with the same id never creates the account twice.
    let id: String
    let name: String
    let type: String
    let currency: String
    let initialBalance: ApiDecimal
    let includeInSavings: Bool
}

/// Currency and initial balance are never sent: they do not change.
struct UpdateAccountRequest: Encodable {
    var name: String?
    var type: String?
    var includeInSavings: Bool?
}

// MARK: - Categories

extension MovementKind {
    var apiValue: String { self == .income ? "income" : "expense" }
}

func movementKind(fromApi value: String) -> MovementKind { value == "income" ? .income : .expense }

struct CategoryDto: Decodable {
    let id: String
    let name: String
    let kind: String
    let color: String

    func toCategory() -> Category {
        Category(id: id, name: name, kind: movementKind(fromApi: kind), colorHex: color)
    }
}

struct CreateCategoryRequest: Encodable {
    /// Chosen by the app: retrying with the same id never creates the category twice.
    let id: String
    let name: String
    let kind: String
    let color: String
}

/// The kind is not sent: it does not change.
struct UpdateCategoryRequest: Encodable {
    let name: String
    let color: String
}

// MARK: - Entries

struct PageMetaDto: Decodable {
    let page: Int
    let pageSize: Int
    let total: Int
}

struct EntryPageDto: Decodable {
    let data: [EntryDto]
    let meta: PageMetaDto
}

/// The account as a row shows it: its balance is not sent, the accounts list has it.
struct EntryAccountDto: Decodable {
    let id: String
    let name: String
    let type: String
    let currency: String

    func toAccount() -> Account {
        Account(id: id, name: name, type: accountType(fromApi: type), currency: currency, balance: 0)
    }
}

/// A row of the list: a movement (`entry_type` "transaction") or a transfer ("transfer"). Each
/// kind fills its own fields.
struct EntryDto: Decodable {
    let entryType: String
    let id: String
    let occurredOn: String
    // A movement.
    var amount: ApiDecimal?
    var description: String?
    var account: EntryAccountDto?
    var category: CategoryDto?
    var creditPurchaseId: String?
    // A transfer.
    var note: String?
    var fromAccount: EntryAccountDto?
    var toAccount: EntryAccountDto?
    var fromAmount: ApiDecimal?
    var toAmount: ApiDecimal?
    var exchangeRate: ApiDecimal?

    func toEntry() throws -> Entry {
        guard let date = LocalDay(iso: String(occurredOn.prefix(10))) else { throw DataException(.unknown) }
        if entryType == "transfer" {
            guard let fromAccount, let toAccount, let fromAmount, let toAmount else {
                throw DataException(.unknown)
            }
            return .transfer(Transfer(
                id: id, note: note ?? "", from: fromAccount.toAccount(), to: toAccount.toAccount(),
                date: date, fromAmount: fromAmount.value, toAmount: toAmount.value,
                exchangeRate: exchangeRate?.value
            ))
        }
        guard let category, let account, let amount else { throw DataException(.unknown) }
        return .movement(Movement(
            id: id, description: description ?? "", category: category.toCategory(),
            account: account.toAccount(), date: date, amount: amount.value,
            creditPurchaseId: creditPurchaseId
        ))
    }
}

struct TransactionRequest: Encodable {
    /// Chosen by the app on create, so a retry never saves the movement twice.
    var id: String?
    let accountId: String
    let categoryId: String
    let amount: ApiDecimal
    let description: String
    /// Left out on a new movement: the API takes today in the user's time zone.
    var occurredOn: String?
}

struct TransferRequest: Encodable {
    /// Chosen by the app on create, so a retry never saves the transfer twice.
    var id: String?
    let fromAccountId: String
    let toAccountId: String
    let fromAmount: ApiDecimal
    let toAmount: ApiDecimal
    /// Always sent, also as JSON null: an edit between accounts of the same currency has to clear
    /// the rate, and a left-out field would keep the old one.
    let exchangeRate: ApiDecimal?
    let occurredOn: String
    let note: String

    private enum CodingKeys: String, CodingKey {
        case id, fromAccountId, toAccountId, fromAmount, toAmount, exchangeRate, occurredOn, note
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(fromAccountId, forKey: .fromAccountId)
        try container.encode(toAccountId, forKey: .toAccountId)
        try container.encode(fromAmount, forKey: .fromAmount)
        try container.encode(toAmount, forKey: .toAmount)
        try container.encode(exchangeRate, forKey: .exchangeRate)
        try container.encode(occurredOn, forKey: .occurredOn)
        try container.encode(note, forKey: .note)
    }
}

// MARK: - Settings

struct SettingsDto: Decodable {
    let mainCurrency: String
    let secondaryCurrency: String
    let displayCurrency: String
    var timezone: String?
    var fxMode: String?
    var fxConfigured: Bool?
    /// Units of the main currency per 1 of the secondary; nil until the user sets it.
    var rate: ApiDecimal?

    func toUserSettings() -> UserSettings {
        UserSettings(
            fx: FxPair(main: mainCurrency, secondary: secondaryCurrency, rate: rate?.value),
            displayCurrency: displayCurrency
        )
    }
}

struct SetFxRequest: Encodable {
    let mainCurrency: String
    let secondaryCurrency: String
    let rate: ApiDecimal
}

struct UpdateSettingsRequest: Encodable {
    var displayCurrency: String?
    var timezone: String?
}

// MARK: - Credit

struct CardDto: Decodable {
    let id: String
    let name: String
    let currency: String

    func toCard() -> CreditCard { CreditCard(id: id, name: name, currency: currency) }
}

struct PurchaseDto: Decodable {
    let id: String
    let card: CardDto
    var description: String?
    let amount: ApiDecimal
    let currency: String
    let purchaseDate: String
    let dueDate: String
    let category: CategoryDto

    func toPurchase() throws -> CreditPurchase {
        guard let purchase = LocalDay(iso: String(purchaseDate.prefix(10))),
              let due = LocalDay(iso: String(dueDate.prefix(10)))
        else { throw DataException(.unknown) }
        return CreditPurchase(
            id: id, card: card.toCard(), description: description ?? "", category: category.toCategory(),
            purchaseDate: purchase, dueDate: due, amount: amount.value, currency: currency
        )
    }
}

struct CardRequest: Encodable {
    /// Chosen by the app on create, so a retry never saves the card twice.
    var id: String?
    let name: String
    let currency: String
}

struct PurchaseRequest: Encodable {
    var id: String?
    let cardId: String
    let categoryId: String
    let amount: ApiDecimal
    let description: String
    let dueDate: String
}

struct PayRequest: Encodable {
    let accountId: String
    let paidAmount: ApiDecimal
    let paidOn: String
}

// MARK: - Reports

struct SummaryDto: Decodable {
    let currencies: [CurrencyReportDto]
}

struct ReportLineDto: Decodable {
    let category: CategoryDto
    let total: ApiDecimal

    func toTotal() -> CategoryTotal { CategoryTotal(category: category.toCategory(), total: total.value) }
}

struct CurrencyReportDto: Decodable {
    let currency: String
    let incomes: [ReportLineDto]
    let expenses: [ReportLineDto]

    func toReport() -> CurrencyReport {
        CurrencyReport(currency: currency, incomes: incomes.map { $0.toTotal() }, expenses: expenses.map { $0.toTotal() })
    }
}

// MARK: - Home

struct HomeSettingsDto: Decodable {
    let mainCurrency: String
    let secondaryCurrency: String
    let displayCurrency: String
    var rate: ApiDecimal?
}

struct CurrencyAmountDto: Decodable {
    let currency: String
    let amount: ApiDecimal
}

struct SavingsDto: Decodable {
    let includedCount: Int
    let activeCount: Int
    let totals: [CurrencyAmountDto]
}

struct MonthDto: Decodable {
    let incomeTotal: ApiDecimal
    let expenseTotal: ApiDecimal
}

struct HomeCreditDto: Decodable {
    let pendingCount: Int
    let nextDueDate: String
    let hasUrgent: Bool
}

struct HomeDto: Decodable {
    let settings: HomeSettingsDto
    let savings: SavingsDto
    let month: MonthDto
    let recentEntries: [EntryDto]
    var credit: HomeCreditDto?

    func toSummary() throws -> HomeSummary {
        var totals: [String: Decimal] = [:]
        for item in savings.totals { totals[item.currency] = item.amount.value }
        let reminder: CreditReminder?
        if let credit {
            guard let next = LocalDay(iso: String(credit.nextDueDate.prefix(10))) else { throw DataException(.unknown) }
            reminder = CreditReminder(pendingCount: credit.pendingCount, nextDueDate: next, hasUrgent: credit.hasUrgent)
        } else {
            reminder = nil
        }
        return HomeSummary(
            fx: FxPair(main: settings.mainCurrency, secondary: settings.secondaryCurrency, rate: settings.rate?.value),
            displayCurrency: settings.displayCurrency,
            savings: totals,
            includedAccounts: savings.includedCount,
            activeAccounts: savings.activeCount,
            monthIncome: month.incomeTotal.value,
            monthExpense: month.expenseTotal.value,
            recentEntries: try recentEntries.map { try $0.toEntry() },
            credit: reminder
        )
    }
}
