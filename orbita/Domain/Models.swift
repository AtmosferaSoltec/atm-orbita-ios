import Foundation

enum AccountType: CaseIterable, Hashable {
    case cash, debit, savings, other

    var label: String {
        switch self {
        case .cash: "Efectivo"
        case .debit: "Débito"
        case .savings: "Ahorro"
        case .other: "Otra"
        }
    }
}

enum MovementKind: Hashable { case expense, income }

/// A place where there is money. `balance` is never stored: the data source computes it
/// (initial balance + incomes − expenses + transfers in − transfers out).
struct Account: Identifiable, Hashable {
    let id: String
    var name: String
    var type: AccountType
    var currency: String
    var balance: Decimal
    var includeInSavings = true

    var icon: String {
        if currency == USD { return "dollarsign" }
        switch type {
        case .cash: return "banknote"
        case .other: return "wallet.bifold"
        default: return "building.columns"
        }
    }
}

/// `colorHex` is `#RRGGBB`.
struct Category: Identifiable, Hashable {
    let id: String
    var name: String
    var kind: MovementKind
    var colorHex: String
}

/// An income or an expense. It takes the currency of its `account`.
struct Movement: Identifiable, Hashable {
    let id: String
    var description: String
    var category: Category
    var account: Account
    var date: LocalDay
    var amount: Decimal
    /// Set when this expense is the payment of a purchase with a credit card. Deleting it undoes
    /// the payment: the purchase is pending again.
    var creditPurchaseId: String?

    var kind: MovementKind { category.kind }
}

/// Money moved between two own accounts; neither income nor expense. `exchangeRate` is the units
/// of the currency of `to` per 1 unit of the currency of `from`, nil when both are the same.
struct Transfer: Identifiable, Hashable {
    let id: String
    var note: String
    var from: Account
    var to: Account
    var date: LocalDay
    var fromAmount: Decimal
    var toAmount: Decimal
    var exchangeRate: Decimal?
}

/// A row of the movement lists: an income, an expense or a transfer.
enum Entry: Identifiable, Hashable {
    case movement(Movement)
    case transfer(Transfer)

    var id: String {
        switch self {
        case .movement(let movement): movement.id
        case .transfer(let transfer): transfer.id
        }
    }

    var date: LocalDay {
        switch self {
        case .movement(let movement): movement.date
        case .transfer(let transfer): transfer.date
        }
    }
}

/// A credit card: a debt account that groups pending purchases. New purchases use `currency`.
struct CreditCard: Identifiable, Hashable {
    let id: String
    var name: String
    var currency: String
}

/// A purchase still to be paid. It is a reminder, not a movement, until it is paid.
struct CreditPurchase: Identifiable, Hashable {
    let id: String
    var card: CreditCard
    var description: String
    var category: Category
    var purchaseDate: LocalDay
    var dueDate: LocalDay
    var amount: Decimal
    var currency: String

    /// Negative once overdue.
    func daysUntilDue(today: LocalDay) -> Int { today.days(until: dueDate) }

    /// Due in 3 days or less, or overdue.
    func isUrgent(today: LocalDay) -> Bool { daysUntilDue(today: today) <= 3 }
}

struct CategoryTotal: Identifiable, Hashable {
    let category: Category
    let total: Decimal

    var id: String { category.id }
}

/// Incomes and expenses of a period in one `currency`, by category and largest first. Transfers
/// and pending credit purchases never count. Currencies are never mixed: a period with
/// movements in several currencies gives one report per currency.
struct CurrencyReport: Identifiable, Hashable {
    let currency: String
    let incomes: [CategoryTotal]
    let expenses: [CategoryTotal]

    var id: String { currency }
    var incomeTotal: Decimal { incomes.total() }
    var expenseTotal: Decimal { expenses.total() }
    var balance: Decimal { incomeTotal - expenseTotal }
}

extension Array where Element == CategoryTotal {
    func total() -> Decimal { reduce(0) { $0 + $1.total } }
}

/// Preferences of the user (Ajustes).
struct UserSettings: Hashable {
    var fx: FxPair
    /// Currency the savings total is shown in: one of the two of `fx`.
    var displayCurrency: String
}

enum SessionState: Equatable {
    /// The stored session is still being restored.
    case loading
    case signedOut
    case signedIn(email: String)
}

extension Array where Element == CreditPurchase {
    /// Currencies owed, `main` first.
    func debtCurrencies(main: String) -> [String] {
        var seen: [String] = []
        for purchase in self where !seen.contains(purchase.currency) { seen.append(purchase.currency) }
        return seen.sorted { ($0 != main ? 1 : 0) < ($1 != main ? 1 : 0) }
    }

    /// Debt in `currency`; currencies are never mixed.
    func debt(in currency: String) -> Decimal {
        filter { $0.currency == currency }.reduce(0) { $0 + $1.amount }
    }
}

/// The reminder of Inicio about credit card purchases still to be paid.
struct CreditReminder: Hashable {
    let pendingCount: Int
    let nextDueDate: LocalDay
    /// Some purchase is due in 3 days or less, or already overdue.
    let hasUrgent: Bool
}

/// Everything Inicio shows, worked out by the data source (one request to the API).
struct HomeSummary: Hashable {
    let fx: FxPair
    let displayCurrency: String
    /// Savings total per currency: the main one, and the secondary once there is a rate.
    let savings: [String: Decimal]
    let includedAccounts: Int
    let activeAccounts: Int
    /// Totals of the current calendar month in the main currency; transfers do not count.
    let monthIncome: Decimal
    let monthExpense: Decimal
    let recentEntries: [Entry]
    /// Nil when there is nothing pending.
    let credit: CreditReminder?
}
