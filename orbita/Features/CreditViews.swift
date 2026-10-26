import SwiftUI

/// What the credit screens need, read together.
struct CreditData {
    let cards: [CreditCard]
    let pendingPurchases: [CreditPurchase]
    /// To pay a purchase from.
    let accounts: [Account]
    let mainCurrency: String
    /// Without an exchange rate, a card can only be in the main currency.
    let fxConfigured: Bool
}

extension AppModel {
    func loadCreditData() async throws -> CreditData {
        async let cards = env.credit.cards()
        async let purchases = env.credit.pendingPurchases()
        async let accounts = env.accounts.accounts()
        async let settings = env.settings.settings()
        let fx = try await settings.fx
        return CreditData(
            cards: try await cards, pendingPurchases: try await purchases, accounts: try await accounts,
            mainCurrency: fx.main, fxConfigured: fx.isConfigured
        )
    }
}

func pluralized(_ count: Int, one: String, other: String) -> String {
    "\(count) \(count == 1 ? one : other)"
}

/// "4 pagos pendientes · vence 5 oct", from the count and the nearest due date.
func pendingPaymentsLabel(_ count: Int, due nextDueDate: LocalDay) -> String {
    "\(pluralized(count, one: "pago pendiente", other: "pagos pendientes")) · vence \(formatDayMonth(nextDueDate))"
}

func dueLabel(_ purchase: CreditPurchase, today: LocalDay) -> String {
    let days = purchase.daysUntilDue(today: today)
    let date = formatDayMonth(purchase.dueDate)
    switch days {
    case ..<(-1): return "Vencida hace \(-days) días"
    case -1: return "Vencida hace 1 día"
    case 0: return "Vence hoy"
    case 1: return "Vence \(date) · mañana"
    default: return "Vence \(date) · en \(days) días"
    }
}

/// Credit card debt (v1.1): the total, then one card per credit card with its pending purchases.
/// Purchases are reminders, not movements.
struct CreditView: View {
    @Environment(AppModel.self) private var app
    @State private var loader = Loader<CreditData>()

    var body: some View {
        Loaded(load: loader.state, onRetry: { loader.retry() }) { data in
            CreditContent(data: data)
        }
        .task(id: [app.revision, loader.attempt]) { await loader.run { try await app.loadCreditData() } }
    }
}

private struct CreditContent: View {
    @Environment(AppModel.self) private var app
    let data: CreditData

    var body: some View {
        let byCard = Dictionary(grouping: data.pendingPurchases, by: { $0.card.id })
        // The card with the closest due date goes first; cards without debt go last.
        let sorted = data.cards.sorted { lhs, rhs in
            let l = byCard[lhs.id]?.map(\.dueDate).min()
            let r = byCard[rhs.id]?.map(\.dueDate).min()
            switch (l, r) {
            case let (l?, r?): return l < r
            case (.some, nil): return true
            default: return false
            }
        }
        ScreenScaffold(header: {
            ScreenHeader(title: "Tarjetas de Crédito", overline: "Deudas pendientes de pago")
        }) {
            TotalDebtCard(cardCount: data.cards.count, purchases: data.pendingPurchases, mainCurrency: data.mainCurrency)
            PrimaryButton(
                title: "Registrar compra con tarjeta", container: Palette.primarySoft, content: Palette.primary,
                systemImage: "plus"
            ) { app.push(.movementForm(credit: true)) }
            .padding(.vertical, 12)

            if data.cards.isEmpty {
                StateMessage(systemImage: "creditcard", title: "Aún no tienes tarjetas de crédito")
            }
            VStack(spacing: 12) {
                ForEach(sorted) { card in
                    CreditCardBlock(
                        card: card,
                        purchases: (byCard[card.id] ?? []).sorted { $0.dueDate < $1.dueDate },
                        today: app.today,
                        onEdit: { app.push(.creditCardForm(card)) },
                        onPay: { app.push(.payCredit($0)) },
                        onPurchaseClick: { app.push(.movementForm(purchase: $0)) }
                    )
                }
                DashedButton(title: "Nueva tarjeta de crédito", systemImage: "plus") { app.push(.creditCardForm(nil)) }
            }
            HintText("Cada compra pertenece a una tarjeta. La deuda total suma todas tus tarjetas, sin mezclar monedas.")
                .padding(.top, 14)
                .padding(.horizontal, 4)
        }
    }
}

/// Debt of every card, per currency and never mixed.
private struct TotalDebtCard: View {
    let cardCount: Int
    let purchases: [CreditPurchase]
    let mainCurrency: String

    var body: some View {
        // The main currency leads (even at zero); every other currency owed gets its own line.
        let extras = purchases.debtCurrencies(main: mainCurrency).filter { $0 != mainCurrency }
        // Yellow tones tell credit (money owed) apart from the blue savings cards. The dark scrim
        // on top of the yellow is what lets the text be white here.
        HeroCard(tone: .credit, scrim: true) {
            HeroLabel("Deuda total · \(pluralized(cardCount, one: "tarjeta", other: "tarjetas"))")
            HeroAmount(formatMoney(purchases.debt(in: mainCurrency), mainCurrency)).padding(.top, 6)
            ForEach(extras, id: \.self) { currency in
                Text("+ \(formatMoney(purchases.debt(in: currency), currency))")
                    .font(OFont.titleLarge)
                    .foregroundStyle(Palette.onHero)
            }
            Text("No cuenta en tus saldos ni en tus reportes hasta que la marques como pagada.")
                .font(OFont.bodySmall)
                .foregroundStyle(Color.white.opacity(0.9))
                .padding(.top, 10)
        }
    }
}

/// One credit card. Collapsed it shows only the card and its debt; expanded it also lists the
/// purchases still to be paid and the link to edit the card.
private struct CreditCardBlock: View {
    let card: CreditCard
    let purchases: [CreditPurchase]
    let today: LocalDay
    let onEdit: () -> Void
    let onPay: (CreditPurchase) -> Void
    let onPurchaseClick: (CreditPurchase) -> Void

    @State private var expanded: Bool

    init(
        card: CreditCard, purchases: [CreditPurchase], today: LocalDay,
        onEdit: @escaping () -> Void, onPay: @escaping (CreditPurchase) -> Void,
        onPurchaseClick: @escaping (CreditPurchase) -> Void
    ) {
        self.card = card
        self.purchases = purchases
        self.today = today
        self.onEdit = onEdit
        self.onPay = onPay
        self.onPurchaseClick = onPurchaseClick
        // Cards with pending payments start open.
        _expanded = State(initialValue: !purchases.isEmpty)
    }

    var body: some View {
        // The card's own currency leads; a card that only owes another one shows that one instead.
        let owed = purchases.debtCurrencies(main: card.currency)
        let currencies = owed.isEmpty ? [card.currency] : owed
        let urgent = purchases.contains { $0.isUrgent(today: today) }
        OrbitaCard {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    // Red when a payment is due in 3 days or less, or overdue; blue otherwise.
                    IconBadge(
                        systemName: "creditcard",
                        tint: urgent ? Palette.expense : Palette.primary,
                        container: urgent ? Palette.expenseSoft : Palette.primarySoft
                    )
                    VStack(alignment: .leading, spacing: 0) {
                        Text(card.name).font(OFont.titleSmall).foregroundStyle(Palette.ink).lineLimit(1)
                        Text(purchases.isEmpty
                            ? "Sin pagos pendientes"
                            : pluralized(purchases.count, one: "pago pendiente", other: "pagos pendientes"))
                            .font(OFont.bodySmall)
                            .foregroundStyle(Palette.muted)
                        if let next = purchases.map(\.dueDate).min() {
                            Text("Vence \(formatDayMonth(next))")
                                .font(OFont.bodySmall)
                                .foregroundStyle(urgent ? Palette.expense : Palette.muted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(formatMoney(purchases.debt(in: currencies[0]), currencies[0]))
                            .font(OFont.titleMedium)
                            .foregroundStyle(Palette.ink)
                        ForEach(Array(currencies.dropFirst()), id: \.self) { currency in
                            Text("+ \(formatMoney(purchases.debt(in: currency), currency))")
                                .font(OFont.bodySmall)
                                .foregroundStyle(Palette.muted)
                        }
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.muted)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(expanded ? "Ocultar pagos pendientes" : "Mostrar pagos pendientes")

            if expanded {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(purchases) { purchase in
                        CardDivider()
                        PurchaseItem(
                            purchase: purchase, today: today,
                            onPay: { onPay(purchase) }, onClick: { onPurchaseClick(purchase) }
                        )
                    }
                    CardDivider()
                    Button(action: onEdit) {
                        HStack(spacing: 8) {
                            Image(systemName: "pencil").font(.system(size: 15, weight: .semibold))
                            Text("Editar tarjeta").font(OFont.labelLarge)
                        }
                        .foregroundStyle(Palette.primary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .transition(.opacity)
            }
        }
    }
}

private struct PurchaseItem: View {
    let purchase: CreditPurchase
    let today: LocalDay
    let onPay: () -> Void
    let onClick: () -> Void

    var body: some View {
        // Tapping what describes the purchase opens it to edit or delete it.
        Button(action: onClick) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Text(purchase.description)
                        .font(OFont.titleSmall)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(formatMoney(purchase.amount, purchase.currency))
                        .font(OFont.titleSmall)
                        .foregroundStyle(Palette.ink)
                }
                Text("\(purchase.category.name) · compra \(formatDayMonth(purchase.purchaseDate))")
                    .font(OFont.bodySmall)
                    .foregroundStyle(Palette.muted)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Editar compra")

        // Urgent: due in 3 days or less, or overdue.
        let urgent = purchase.isUrgent(today: today)
        HStack {
            StatusChip(
                text: dueLabel(purchase, today: today),
                container: urgent ? Palette.expenseSoft : Palette.neutralSoft,
                content: urgent ? Palette.expense : Palette.neutral
            )
            Spacer()
        }
        .padding(.top, 10)
        PillButton(title: "Marcar como pagada", systemImage: "checkmark", fill: true, action: onPay)
            .padding(.top, 10)
    }
}
