import Foundation

// Rows of the in-memory demo "database". What is stored is the initial balance and the ids, and
// everything shown is computed from them.

struct AccountRecord {
    let id: String
    var name: String
    var type: AccountType
    var currency: String
    var initialBalance: Decimal = 0
    var includeInSavings = true
    var archived = false
}

struct CategoryRecord {
    var category: Category
    var archived = false
}

/// `order` breaks ties between entries of the same day: the one created last goes first.
struct MovementRecord {
    let id: String
    var description: String
    var categoryId: String
    var accountId: String
    var date: LocalDay
    var amount: Decimal
    var order: Int
}

struct TransferRecord {
    let id: String
    var note: String
    var fromId: String
    var toId: String
    var date: LocalDay
    var fromAmount: Decimal
    var toAmount: Decimal
    var exchangeRate: Decimal?
    var order: Int
}

struct CardRecord {
    var card: CreditCard
    var archived = false
}

struct PurchaseRecord {
    let id: String
    var cardId: String
    var description: String
    var categoryId: String
    var purchaseDate: LocalDay
    var dueDate: LocalDay
    var amount: Decimal
    var currency: String
    var paid = false
    /// The expense created when it was paid; deleting that expense undoes the payment.
    var paymentMovementId: String?
}

struct DemoState {
    var accounts: [AccountRecord]
    var categories: [CategoryRecord]
    var movements: [MovementRecord]
    var transfers: [TransferRecord]
    var cards: [CardRecord]
    var purchases: [PurchaseRecord]
    var settings: UserSettings
    var nextOrder: Int

    private func category(_ id: String) -> Category {
        categories.first { $0.category.id == id }!.category
    }

    /// Initial balance + incomes − expenses + transfers in − transfers out.
    private func balance(of record: AccountRecord) -> Decimal {
        let moved = movements.filter { $0.accountId == record.id }.reduce(Decimal(0)) { total, movement in
            category(movement.categoryId).kind == .income ? total + movement.amount : total - movement.amount
        }
        let received = transfers.filter { $0.toId == record.id }.reduce(Decimal(0)) { $0 + $1.toAmount }
        let sent = transfers.filter { $0.fromId == record.id }.reduce(Decimal(0)) { $0 + $1.fromAmount }
        return record.initialBalance + moved + received - sent
    }

    private func toAccount(_ record: AccountRecord) -> Account {
        Account(
            id: record.id, name: record.name, type: record.type, currency: record.currency,
            balance: balance(of: record), includeInSavings: record.includeInSavings
        )
    }

    /// Any account, archived ones too: old entries still point to them.
    func account(_ id: String) -> Account { toAccount(accounts.first { $0.id == id }!) }

    var activeAccounts: [Account] { accounts.filter { !$0.archived }.map(toAccount) }

    var activeCategories: [Category] { categories.filter { !$0.archived }.map(\.category) }

    var activeCards: [CreditCard] { cards.filter { !$0.archived }.map(\.card) }

    /// Movements and transfers mixed, newest first.
    var entries: [Entry] {
        var byId: [String: Account] = [:]
        for record in accounts { byId[record.id] = toAccount(record) }
        var purchaseByPayment: [String: String] = [:]
        for purchase in purchases {
            if let payment = purchase.paymentMovementId { purchaseByPayment[payment] = purchase.id }
        }
        var all: [(order: Int, entry: Entry)] = movements.map { record in
            (record.order, .movement(Movement(
                id: record.id, description: record.description, category: category(record.categoryId),
                account: byId[record.accountId]!, date: record.date, amount: record.amount,
                creditPurchaseId: purchaseByPayment[record.id]
            )))
        }
        all += transfers.map { record in
            (record.order, .transfer(Transfer(
                id: record.id, note: record.note, from: byId[record.fromId]!, to: byId[record.toId]!,
                date: record.date, fromAmount: record.fromAmount, toAmount: record.toAmount,
                exchangeRate: record.exchangeRate
            )))
        }
        return all.sorted { lhs, rhs in
            lhs.entry.date != rhs.entry.date ? lhs.entry.date > rhs.entry.date : lhs.order > rhs.order
        }.map(\.entry)
    }

    var pendingPurchases: [CreditPurchase] {
        purchases.filter { !$0.paid }.map { record in
            CreditPurchase(
                id: record.id, card: cards.first { $0.card.id == record.cardId }!.card,
                description: record.description, category: category(record.categoryId),
                purchaseDate: record.purchaseDate, dueDate: record.dueDate,
                amount: record.amount, currency: record.currency
            )
        }
    }

    /// The report of a period: movements only, by currency of their account, the main currency first.
    func report(for period: DatePeriod) -> [CurrencyReport] {
        var currencyOf: [String: String] = [:]
        for record in accounts { currencyOf[record.id] = record.currency }

        var currencies: [String] = []
        var rowsByCurrency: [String: [MovementRecord]] = [:]
        for movement in movements where period.contains(movement.date) {
            let currency = currencyOf[movement.accountId]!
            if rowsByCurrency[currency] == nil { currencies.append(currency) }
            rowsByCurrency[currency, default: []].append(movement)
        }

        func totals(_ rows: [MovementRecord], _ kind: MovementKind) -> [CategoryTotal] {
            var order: [String] = []
            var sums: [String: Decimal] = [:]
            for row in rows where category(row.categoryId).kind == kind {
                if sums[row.categoryId] == nil { order.append(row.categoryId) }
                sums[row.categoryId, default: 0] += row.amount
            }
            return order
                .map { CategoryTotal(category: category($0), total: sums[$0]!) }
                .sorted { $0.total > $1.total }
        }

        let main = settings.fx.main
        return currencies
            .map { CurrencyReport(currency: $0, incomes: totals(rowsByCurrency[$0]!, .income), expenses: totals(rowsByCurrency[$0]!, .expense)) }
            .sorted { lhs, rhs in
                let l = lhs.currency != main, r = rhs.currency != main
                return l != r ? !l : lhs.currency < rhs.currency
            }
    }
}
