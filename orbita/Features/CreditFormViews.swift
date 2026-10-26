import SwiftUI

/// "Marcar como pagada": only now the expense is created in the chosen account.
struct PayCreditScreen: View {
    @Environment(AppModel.self) private var app
    let purchase: CreditPurchase

    @State private var loader = Loader<CreditData>()

    var body: some View {
        Loaded(load: loader.state, onRetry: { loader.retry() }, onClose: { app.pop() }) { data in
            PayCreditForm(purchase: purchase, accounts: data.accounts, today: app.today)
        }
        .task(id: [app.revision, loader.attempt]) { await loader.run { try await app.loadCreditData() } }
    }
}

private struct PayCreditForm: View {
    @Environment(AppModel.self) private var app
    let purchase: CreditPurchase
    let accounts: [Account]
    let today: LocalDay

    @State private var selectedId: String?
    @State private var amount: String
    @State private var paidOn: LocalDay
    @State private var pickingDate = false

    init(purchase: CreditPurchase, accounts: [Account], today: LocalDay) {
        self.purchase = purchase
        self.accounts = accounts
        self.today = today
        // Starts on an account in the currency of the purchase, where no conversion is needed.
        let initial = accounts.first { $0.currency == purchase.currency } ?? accounts.first
        _selectedId = State(initialValue: initial?.id)
        _amount = State(initialValue: initial.map { Self.suggestedAmount(purchase, $0) } ?? "")
        _paidOn = State(initialValue: today)
    }

    /// If the currencies match, the purchase amount is suggested; otherwise the user must type
    /// what the bank really charged.
    private static func suggestedAmount(_ purchase: CreditPurchase, _ account: Account) -> String {
        account.currency == purchase.currency ? plainAmount(purchase.amount) : ""
    }

    private var route: Route { .payCredit(purchase) }

    var body: some View {
        // The list may hold a newer copy of the account (its balance changes with every movement).
        let account = accounts.first { $0.id == selectedId }
        let paid = parseDecimal(amount) ?? 0
        ScreenScaffold(header: {
            ModalTopBar(title: "Marcar como pagada", icon: .back, onNavigate: { app.pop() })
        }, footer: {
            PrimaryButton(title: "Confirmar pago") { confirm(account) }
        }) {
            OrbitaCard {
                HStack(spacing: 8) {
                    Text(purchase.description)
                        .font(OFont.titleSmall)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(formatMoney(purchase.amount, purchase.currency))
                        .font(OFont.titleMedium)
                        .foregroundStyle(Palette.ink)
                }
                Text("\(purchase.category.name) · compra \(formatDayMonth(purchase.purchaseDate)) · vence \(formatDayMonth(purchase.dueDate))")
                    .font(OFont.bodySmall)
                    .foregroundStyle(Palette.muted)
            }

            FieldLabel("Pagar desde")
            ChipGroup {
                ForEach(accounts) { option in
                    OrbitaChip(label: option.name, selected: option.id == selectedId) {
                        selectedId = option.id
                        amount = Self.suggestedAmount(purchase, option)
                    }
                }
            }

            FieldLabel("Monto realmente descontado")
            OrbitaTextField(
                text: $amount, placeholder: "0.00",
                prefix: currencySymbol(account?.currency ?? purchase.currency), keyboard: .decimalPad
            )
            .onChange(of: amount) { _, value in
                let cleaned = sanitizeDecimalInput(value, maxDecimals: 2)
                if cleaned != value { amount = cleaned }
            }
            HintText("Si la compra fue en dólares, escribe aquí los soles que te cobró el banco.").padding(.top, 8)

            FieldLabel("Fecha de pago · hoy, editable")
            PickerField(value: formatDate(paidOn)) { pickingDate = true }

            if let account {
                OrbitaCard {
                    Text("Se creará este egreso").font(OFont.labelMedium).foregroundStyle(Palette.muted)
                    Color.clear.frame(height: 10)
                    LabelValueRow(
                        label: "\(purchase.category.name) · \(account.name)",
                        value: formatSignedMoney(paid, account.currency, positive: false),
                        labelColor: Palette.ink, valueColor: Palette.expense
                    )
                    CardDivider()
                    LabelValueRow(
                        label: "Saldo de \(account.name)",
                        value: "\(formatMoney(account.balance, account.currency)) → \(formatMoney(account.balance - paid, account.currency))",
                        valueFont: OFont.labelMedium
                    )
                }
                .padding(.top, 20)
            }
        }
        // The payment becomes an expense, and an expense cannot be dated in the future.
        .dateDialog(isPresented: $pickingDate, title: "Elige la fecha", date: paidOn, today: today) { paidOn = $0 }
    }

    private func confirm(_ account: Account?) {
        let payment = CreditPayment(
            purchaseId: purchase.id, accountId: account?.id, paidAmount: parseDecimal(amount), paidOn: paidOn
        )
        let route = route
        app.perform(invalid: payment.validate(today: today), onDone: { app.close(route) }) {
            try await app.env.credit.pay(payment)
        }
    }
}

/// New credit card (`card` = nil) or edit credit card (v1.1).
struct CreditCardFormScreen: View {
    @Environment(AppModel.self) private var app
    let card: CreditCard?

    @State private var loader = Loader<CreditData>()

    var body: some View {
        Loaded(load: loader.state, onRetry: { loader.retry() }, onClose: { app.pop() }) { data in
            CreditCardForm(
                card: card,
                defaultCurrency: data.mainCurrency,
                fxConfigured: data.fxConfigured,
                // A card that still owes something cannot be archived.
                hasPendingPurchases: data.pendingPurchases.contains { $0.card.id == card?.id }
            )
        }
        .task(id: [app.revision, loader.attempt]) { await loader.run { try await app.loadCreditData() } }
    }
}

private struct CreditCardForm: View {
    @Environment(AppModel.self) private var app
    let card: CreditCard?
    let defaultCurrency: String
    let fxConfigured: Bool
    let hasPendingPurchases: Bool

    @State private var name: String
    @State private var currency: String
    @State private var confirmArchive = false
    @State private var archiveBlocked = false

    init(card: CreditCard?, defaultCurrency: String, fxConfigured: Bool, hasPendingPurchases: Bool) {
        self.card = card
        self.defaultCurrency = defaultCurrency
        self.fxConfigured = fxConfigured
        self.hasPendingPurchases = hasPendingPurchases
        _name = State(initialValue: card?.name ?? "")
        // A new card starts on the user's main currency (Ajustes).
        _currency = State(initialValue: card?.currency ?? defaultCurrency)
    }

    private var editing: Bool { card != nil }
    private var route: Route { .creditCardForm(card) }

    var body: some View {
        ScreenScaffold(header: {
            ModalTopBar(
                title: editing ? "Editar tarjeta" : "Nueva tarjeta",
                icon: editing ? .back : .close,
                onNavigate: { app.pop() }
            )
        }, footer: {
            PrimaryButton(title: editing ? "Guardar cambios" : "Guardar tarjeta", action: save)
        }) {
            FieldLabel("Nombre")
            OrbitaTextField(text: $name, placeholder: "Ej. Visa Clásica")

            FieldLabel("Moneda")
            if fxConfigured {
                DropdownField(
                    options: supportedCurrencies,
                    selected: currencyInfo(currency),
                    onSelect: { currency = $0.code },
                    label: { $0.label },
                    detail: { $0.code },
                    leading: { _ in EmptyView() }
                )
                HintText("Las compras que registres con esta tarjeta usarán esta moneda.").padding(.top, 8)
            } else {
                ChipGroup { OrbitaChip(label: currencyInfo(currency).label, selected: true) {} }
                HintText("Configura tu tipo de cambio en Ajustes para usar otras monedas.").padding(.top, 8)
            }

            if editing {
                PillButton(
                    title: "Archivar tarjeta", systemImage: "archivebox",
                    container: Palette.expenseSoft, content: Palette.expense
                ) {
                    // With pending payments there is nothing to confirm: it cannot be archived.
                    if hasPendingPurchases { archiveBlocked = true } else { confirmArchive = true }
                }
                .padding(.top, 24)
                if archiveBlocked && hasPendingPurchases {
                    HintText(UiMessage.failed(.cardHasPendingPurchases).text, color: Palette.expense).padding(.top, 8)
                } else {
                    HintText("La tarjeta deja de aparecer en las listas, pero conserva sus compras.").padding(.top, 8)
                }
            }
        }
        .confirmDialog(
            "¿Archivar esta tarjeta?", isPresented: $confirmArchive,
            message: "La tarjeta deja de aparecer en las listas, pero conserva sus compras.",
            confirmLabel: "Archivar"
        ) {
            guard let card else { return }
            let route = route
            app.perform(onDone: { app.close(route) }) { try await app.env.credit.archiveCard(id: card.id) }
        }
    }

    private func save() {
        let draft = CreditCardDraft(name: name, currency: currency)
        let card = card
        let route = route
        app.perform(invalid: draft.validate(), onDone: { app.close(route) }) {
            if let card {
                try await app.env.credit.updateCard(id: card.id, draft)
            } else {
                try await app.env.credit.createCard(draft, id: UUID().uuidString)
            }
        }
    }
}
