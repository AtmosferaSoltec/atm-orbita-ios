import Foundation

/// Sample data (ORBITA_SPEC section 11). It seeds the in-memory demo repositories and feeds the
/// previews. Everything shown is computed from the rows below, so the totals of the spec come
/// out of them: balances, savings total and the September and October reports.
enum SampleData {
    static let today = LocalDay(2026, 10, 2)
    static let currentMonth = today.firstOfMonth
    static let reportMonth = LocalDay(2026, 9, 1)

    static let userEmail = "ana.torres@correo.com"

    /// Manual rate: 1 US$ = S/ 3.20
    static let fx = FxPair(main: PEN, secondary: USD, rate: D("3.20"))

    private static func oct(_ day: Int) -> LocalDay { LocalDay(2026, 10, day) }
    private static func sep(_ day: Int) -> LocalDay { LocalDay(2026, 9, day) }

    private static func category(_ id: String, _ name: String, _ kind: MovementKind, _ colorHex: String) -> CategoryRecord {
        CategoryRecord(category: Category(id: id, name: name, kind: kind, colorHex: colorHex))
    }

    private static let categoryRecords = [
        category("food", "Alimentación", .expense, "#0E7490"),
        category("transport", "Transporte", .expense, "#B45309"),
        category("housing", "Vivienda", .expense, "#1D4ED8"),
        category("health", "Salud", .expense, "#7C3AED"),
        category("leisure", "Ocio", .expense, "#BE185D"),
        category("other", "Otros", .expense, "#64748B"),
        category("salary", "Sueldo", .income, "#0B7A5A"),
        category("freelance", "Freelance", .income, "#0E7490"),
        category("other-income", "Otros ingresos", .income, "#64748B"),
    ]

    /// The balance each account must end with; its initial balance is worked out from it.
    private static let accountBalances: [(record: AccountRecord, balance: String)] = [
        (AccountRecord(id: "usd", name: "Cuenta Dólares", type: .savings, currency: USD), "250.00"),
        (AccountRecord(id: "cash", name: "Efectivo", type: .cash, currency: PEN), "320.50"),
        (AccountRecord(id: "debit", name: "Débito principal", type: .debit, currency: PEN), "1245.80"),
        (AccountRecord(id: "savings", name: "Ahorros", type: .savings, currency: PEN), "4800.00"),
        (AccountRecord(id: "wallet", name: "Billetera digital", type: .other, currency: PEN, includeInSavings: false), "85.00"),
    ]

    private struct EntrySeed {
        let id: String
        let text: String
        let date: LocalDay
        let amount: String
        var categoryId: String?
        var accountId: String?
        var fromId: String?
        var toId: String?
        var toAmount: String?
        var rate: String?
    }

    private static func movement(
        _ id: String, _ text: String, _ categoryId: String, _ accountId: String, _ date: LocalDay, _ amount: String
    ) -> EntrySeed {
        EntrySeed(id: id, text: text, date: date, amount: amount, categoryId: categoryId, accountId: accountId)
    }

    // Newest first, as the lists show them. September adds up to the report of the spec:
    // incomes 4,200.00 and expenses 2,148.60.
    private static let entrySeeds: [EntrySeed] = [
        movement("m-lunch", "Almuerzo", "food", "cash", oct(2), "18.50"),
        movement("m-taxi", "Taxi al trabajo", "transport", "debit", oct(2), "12.00"),
        movement("m-salary-oct", "Sueldo", "salary", "debit", oct(1), "3500.00"),
        EntrySeed(
            id: "t-dollars", text: "Cambio de dólares", date: oct(1), amount: "20.00",
            fromId: "usd", toId: "debit", toAmount: "64.00", rate: "3.20"
        ),
        movement("m-rent", "Alquiler", "housing", "debit", sep(30), "800.00"),
        movement("m-market-3", "Supermercado", "food", "debit", sep(28), "152.40"),
        movement("m-logo", "Diseño de logo", "freelance", "debit", sep(27), "600.00"),
        movement("m-cinema", "Cine", "leisure", "cash", sep(26), "45.00"),
        movement("m-pharmacy", "Farmacia", "health", "cash", sep(24), "38.00"),
        EntrySeed(
            id: "t-savings", text: "Ahorro del mes", date: sep(22), amount: "500.00",
            fromId: "debit", toId: "savings", toAmount: "500.00"
        ),
        movement("m-supplies", "Útiles", "other", "cash", sep(20), "60.00"),
        movement("m-restaurant", "Restaurante", "food", "cash", sep(19), "70.00"),
        movement("m-fuel", "Gasolina", "transport", "debit", sep(17), "120.00"),
        movement("m-gift", "Regalo de cumpleaños", "other", "debit", sep(15), "123.00"),
        movement("m-market-2", "Supermercado", "food", "debit", sep(14), "180.00"),
        movement("m-concert", "Concierto", "leisure", "debit", sep(12), "145.00"),
        movement("m-books", "Venta de libros", "other-income", "cash", sep(12), "100.00"),
        movement("m-doctor", "Consulta médica", "health", "debit", sep(9), "110.00"),
        movement("m-bus", "Pasajes de bus", "transport", "cash", sep(8), "95.20"),
        movement("m-market-1", "Mercado", "food", "debit", sep(6), "210.00"),
        movement("m-salary-sep", "Sueldo", "salary", "debit", sep(1), "3500.00"),
    ]

    private static let cardRecords = [
        CardRecord(card: CreditCard(id: "visa", name: "Visa Clásica", currency: PEN)),
        CardRecord(card: CreditCard(id: "mastercard", name: "Mastercard Oro", currency: PEN)),
    ]

    private static let purchaseRecords = [
        PurchaseRecord(id: "p1", cardId: "visa", description: "Pasajes", categoryId: "transport", purchaseDate: sep(10), dueDate: oct(5), amount: D("240.00"), currency: PEN),
        PurchaseRecord(id: "p2", cardId: "visa", description: "Cena en restaurante", categoryId: "food", purchaseDate: sep(18), dueDate: oct(15), amount: D("96.00"), currency: PEN),
        PurchaseRecord(id: "p3", cardId: "mastercard", description: "Audífonos", categoryId: "leisure", purchaseDate: sep(20), dueDate: oct(15), amount: D("189.90"), currency: PEN),
        PurchaseRecord(id: "p4", cardId: "mastercard", description: "Suscripción de software", categoryId: "other", purchaseDate: sep(25), dueDate: oct(15), amount: D("12.00"), currency: USD),
    ]

    static var seed: DemoState = {
        let size = entrySeeds.count
        var movements: [MovementRecord] = []
        var transfers: [TransferRecord] = []
        for (index, seed) in entrySeeds.enumerated() {
            if let categoryId = seed.categoryId, let accountId = seed.accountId {
                movements.append(MovementRecord(
                    id: seed.id, description: seed.text, categoryId: categoryId, accountId: accountId,
                    date: seed.date, amount: D(seed.amount), order: size - index
                ))
            } else if let fromId = seed.fromId, let toId = seed.toId, let toAmount = seed.toAmount {
                transfers.append(TransferRecord(
                    id: seed.id, note: seed.text, fromId: fromId, toId: toId, date: seed.date,
                    fromAmount: D(seed.amount), toAmount: D(toAmount), exchangeRate: seed.rate.map(D),
                    order: size - index
                ))
            }
        }
        var state = DemoState(
            accounts: accountBalances.map(\.record),
            categories: categoryRecords,
            movements: movements,
            transfers: transfers,
            cards: cardRecords,
            purchases: purchaseRecords,
            settings: UserSettings(fx: fx, displayCurrency: PEN),
            nextOrder: size + 1
        )
        // initial balance = balance it must end with − what its entries add up to
        let withoutInitial = state
        state.accounts = accountBalances.map { item in
            var record = item.record
            record.initialBalance = D(item.balance) - withoutInitial.account(record.id).balance
            return record
        }
        return state
    }()

    static var accounts: [Account] { seed.activeAccounts }
    static var debitAccount: Account { seed.account("debit") }
    static var dollarAccount: Account { seed.account("usd") }

    static var categories: [Category] { seed.activeCategories }

    static func categories(of kind: MovementKind) -> [Category] { categories.filter { $0.kind == kind } }

    static var entries: [Entry] { seed.entries }
    static var recentEntries: [Entry] { Array(entries.prefix(4)) }

    static var creditCards: [CreditCard] { seed.activeCards }
    static var creditPurchases: [CreditPurchase] { seed.pendingPurchases }
}
