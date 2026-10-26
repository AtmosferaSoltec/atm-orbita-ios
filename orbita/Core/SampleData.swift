import SwiftUI

// Mockup-only models and sample data (ORBITA_SPEC section 11). They are replaced by the
// domain models and repositories when each phase is implemented.

/// Exact decimal from text; never build money from floating-point literals.
func D(_ text: String) -> Decimal { Decimal(string: text, locale: Locale(identifier: "en_US"))! }

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

struct MockAccount: Identifiable, Hashable {
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

struct MockCategory: Identifiable, Hashable {
    let name: String
    let kind: MovementKind
    let color: Color
    var id: String { "\(kind)-\(name)" }
}

struct MockMovement: Identifiable, Hashable {
    let id: String
    let description: String
    let category: MockCategory
    let account: MockAccount
    let date: Date
    let amount: Decimal
    var kind: MovementKind { category.kind }
}

struct MockTransfer: Identifiable, Hashable {
    let id: String
    let note: String
    let from: MockAccount
    let to: MockAccount
    let date: Date
    let fromAmount: Decimal
    let toAmount: Decimal
}

enum MockEntry: Identifiable, Hashable {
    case movement(MockMovement)
    case transfer(MockTransfer)

    var id: String {
        switch self {
        case .movement(let movement): movement.id
        case .transfer(let transfer): transfer.id
        }
    }

    var date: Date {
        switch self {
        case .movement(let movement): movement.date
        case .transfer(let transfer): transfer.date
        }
    }
}

struct MockCreditPurchase: Identifiable, Hashable {
    let id: String
    let description: String
    let category: MockCategory
    let purchaseDate: Date
    let dueDate: Date
    let amount: Decimal
    let currency: String

    var daysUntilDue: Int { Cal.days(from: SampleData.today, to: dueDate) }
    var isUrgent: Bool { daysUntilDue <= 3 }
}

struct MockCategoryTotal: Identifiable {
    let category: MockCategory
    let total: Decimal
    var id: String { category.id }
}

enum SampleData {
    static let today = Cal.date(2026, 10, 2)

    /// Manual rate: 1 US$ = S/ 3.20
    static let usdToPen = D("3.20")

    static let userEmail = "ana.torres@correo.com"

    private static let cash = MockAccount(id: "cash", name: "Efectivo", type: .cash, currency: PEN, balance: D("320.50"))
    private static let debit = MockAccount(id: "debit", name: "Débito principal", type: .debit, currency: PEN, balance: D("1245.80"))
    private static let savings = MockAccount(id: "savings", name: "Ahorros", type: .savings, currency: PEN, balance: D("4800"))
    private static let dollars = MockAccount(id: "usd", name: "Cuenta Dólares", type: .savings, currency: USD, balance: D("250"))
    private static let wallet = MockAccount(
        id: "wallet", name: "Billetera digital", type: .other, currency: PEN, balance: D("85"), includeInSavings: false
    )

    static let accounts = [dollars, cash, debit, savings, wallet]
    static let debitAccount = debit
    static let dollarAccount = dollars

    private static let food = MockCategory(name: "Alimentación", kind: .expense, color: Palette.categoryFood)
    private static let transport = MockCategory(name: "Transporte", kind: .expense, color: Palette.categoryTransport)
    private static let housing = MockCategory(name: "Vivienda", kind: .expense, color: Palette.categoryHousing)
    private static let health = MockCategory(name: "Salud", kind: .expense, color: Palette.categoryHealth)
    private static let leisure = MockCategory(name: "Ocio", kind: .expense, color: Palette.categoryLeisure)
    private static let other = MockCategory(name: "Otros", kind: .expense, color: Palette.categoryOther)
    private static let salary = MockCategory(name: "Sueldo", kind: .income, color: Palette.categorySalary)
    private static let freelance = MockCategory(name: "Freelance", kind: .income, color: Palette.categoryFreelance)
    private static let otherIncome = MockCategory(name: "Otros ingresos", kind: .income, color: Palette.categoryOther)

    static let expenseCategories = [food, transport, housing, health, leisure, other]
    static let incomeCategories = [salary, freelance, otherIncome]

    static func categories(of kind: MovementKind) -> [MockCategory] {
        kind == .expense ? expenseCategories : incomeCategories
    }

    private static func oct(_ day: Int) -> Date { Cal.date(2026, 10, day) }
    private static func sep(_ day: Int) -> Date { Cal.date(2026, 9, day) }

    /// Movements and transfers mixed, newest first.
    static let entries: [MockEntry] = [
        .movement(MockMovement(id: "m1", description: "Almuerzo", category: food, account: cash, date: oct(2), amount: D("18.50"))),
        .movement(MockMovement(id: "m2", description: "Taxi al trabajo", category: transport, account: debit, date: oct(2), amount: D("12"))),
        .movement(MockMovement(id: "m3", description: "Sueldo", category: salary, account: debit, date: oct(1), amount: D("3500"))),
        .transfer(MockTransfer(
            id: "t1", note: "Cambio de dólares", from: dollars, to: debit, date: oct(1), fromAmount: D("20"), toAmount: D("64")
        )),
        .movement(MockMovement(id: "m4", description: "Alquiler", category: housing, account: debit, date: sep(30), amount: D("800"))),
        .movement(MockMovement(id: "m5", description: "Supermercado", category: food, account: debit, date: sep(28), amount: D("152.40"))),
        .movement(MockMovement(id: "m6", description: "Diseño de logo", category: freelance, account: debit, date: sep(27), amount: D("600"))),
        .movement(MockMovement(id: "m7", description: "Cine", category: leisure, account: cash, date: sep(26), amount: D("45"))),
        .movement(MockMovement(id: "m8", description: "Farmacia", category: health, account: cash, date: sep(24), amount: D("38"))),
        .transfer(MockTransfer(
            id: "t2", note: "Ahorro del mes", from: debit, to: savings, date: sep(22), fromAmount: D("500"), toAmount: D("500")
        )),
    ]

    static var recentEntries: [MockEntry] { Array(entries.prefix(4)) }

    // October 2026 (current month)
    static let monthIncome: Decimal = D("3500")
    static let monthExpense: Decimal = D("30.50")

    // September 2026 report
    static let reportMonth = Cal.date(2026, 9, 1)
    static let reportExpenses = [
        MockCategoryTotal(category: housing, total: D("800")),
        MockCategoryTotal(category: food, total: D("612.40")),
        MockCategoryTotal(category: transport, total: D("215.20")),
        MockCategoryTotal(category: leisure, total: D("190")),
        MockCategoryTotal(category: other, total: D("183")),
        MockCategoryTotal(category: health, total: D("148")),
    ]
    static let reportIncomes = [
        MockCategoryTotal(category: salary, total: D("3500")),
        MockCategoryTotal(category: freelance, total: D("600")),
        MockCategoryTotal(category: otherIncome, total: D("100")),
    ]

    static let creditPurchases = [
        MockCreditPurchase(
            id: "p1", description: "Pasajes", category: transport,
            purchaseDate: sep(10), dueDate: oct(5), amount: D("240"), currency: PEN
        ),
        MockCreditPurchase(
            id: "p2", description: "Cena en restaurante", category: food,
            purchaseDate: sep(18), dueDate: oct(15), amount: D("96"), currency: PEN
        ),
        MockCreditPurchase(
            id: "p3", description: "Audífonos", category: leisure,
            purchaseDate: sep(20), dueDate: oct(15), amount: D("189.90"), currency: PEN
        ),
        MockCreditPurchase(
            id: "p4", description: "Suscripción de software", category: other,
            purchaseDate: sep(25), dueDate: oct(15), amount: D("12"), currency: USD
        ),
    ]
}

extension Array where Element == MockCategoryTotal {
    func total() -> Decimal { reduce(0) { $0 + $1.total } }
}

/// Share of [part] over [whole] as a percentage with one decimal (half up).
func percentOf(_ part: Decimal, _ whole: Decimal) -> Decimal {
    whole == 0 ? 0 : (part * 100 / whole).rounded(scale: 1)
}

/// Converts between PEN and USD with the manual sample rate. Rounds once, at the end.
func convert(_ amount: Decimal, from: String, to: String) -> Decimal {
    if from == to { return amount.rounded(scale: 2) }
    if from == USD { return (amount * SampleData.usdToPen).rounded(scale: 2) }
    return (amount / SampleData.usdToPen).rounded(scale: 2)
}

extension Array where Element == MockAccount {
    /// Savings total of the included accounts, shown in [currency].
    func savingsTotal(_ currency: String) -> Decimal {
        let totalPen = filter(\.includeInSavings).reduce(Decimal(0)) { total, account in
            total + (account.currency == USD ? account.balance * SampleData.usdToPen : account.balance)
        }
        return convert(totalPen, from: PEN, to: currency)
    }
}
