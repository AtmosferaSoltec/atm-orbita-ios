import SwiftUI
import UIKit

/// What the movement form and the movement list need, read together.
struct MovementsData {
    let accounts: [Account]
    let categories: [Category]
    let creditCards: [CreditCard]
    /// Movements and transfers of the months the list can show, newest first.
    let entries: [Entry]

    /// A new movement starts on the account of the latest movement, or else on the first one.
    var defaultAccount: Account? {
        let lastUsed = entries.compactMap { entry -> String? in
            if case .movement(let movement) = entry { return movement.account.id }
            return nil
        }.first
        return accounts.first { $0.id == lastUsed } ?? accounts.first
    }
}

/// The list shows the current month plus the four before it; older activity is in Reportes.
let movementMonthsShown = 5

extension AppModel {
    func loadMovementsData() async throws -> MovementsData {
        let today = today
        let period = DatePeriod(from: today.firstOfMonth.adding(months: -(movementMonthsShown - 1)), to: today)
        async let accounts = env.accounts.accounts()
        async let categories = env.categories.categories()
        async let cards = env.credit.cards()
        async let entries = env.entries.entries(in: period)
        return MovementsData(
            accounts: try await accounts, categories: try await categories,
            creditCards: try await cards, entries: try await entries
        )
    }
}

private enum FormTab: Hashable { case expense, income, transfer }

/// Due date suggested for a new purchase with a credit card.
private let defaultDaysToPay = 13

/// Loads what the form needs, then shows it.
struct MovementFormScreen: View {
    @Environment(AppModel.self) private var app
    let editing: Movement?
    let initialCredit: Bool
    let editingPurchase: CreditPurchase?

    @State private var loader = Loader<MovementsData>()

    private var route: Route { .movementForm(editing: editing, credit: initialCredit, purchase: editingPurchase) }

    var body: some View {
        Loaded(load: loader.state, onRetry: { loader.retry() }, onClose: { app.pop() }) { data in
            // A purchase with a credit card needs no account until it is paid.
            if data.accounts.isEmpty && editing == nil && editingPurchase == nil {
                NoticeScreen(
                    barTitle: "Nuevo movimiento",
                    title: "Aún no tienes cuentas",
                    message: "Crea una cuenta para poder registrar movimientos.",
                    onClose: { app.pop() }
                )
            } else {
                MovementForm(
                    data: data, editing: editing, initialCredit: initialCredit, editingPurchase: editingPurchase,
                    route: route, today: app.today
                )
            }
        }
        .task(id: [app.revision, loader.attempt]) { await loader.run { try await app.loadMovementsData() } }
    }
}

/// New movement, or edit/delete when `editing` is set. With "Compra con tarjeta de crédito" on,
/// it saves a pending purchase instead of a movement; with `editingPurchase` it edits or deletes
/// a purchase that is still pending.
private struct MovementForm: View {
    @Environment(AppModel.self) private var app
    let data: MovementsData
    let editing: Movement?
    let editingPurchase: CreditPurchase?
    let route: Route

    @State private var kind: MovementKind
    @State private var amountCents: Int64
    @State private var keypadOpen: Bool
    @State private var accountId: String?
    @State private var category: Category?
    @State private var description: String
    @State private var date: LocalDay?
    @State private var pickingDate = false
    @State private var credit: Bool
    @State private var chosenCard: CreditCard?
    @State private var dueDate: LocalDay
    @State private var pickingDueDate = false
    @State private var confirmDelete = false

    init(
        data: MovementsData, editing: Movement?, initialCredit: Bool, editingPurchase: CreditPurchase?,
        route: Route, today: LocalDay
    ) {
        self.data = data
        self.editing = editing
        self.editingPurchase = editingPurchase
        self.route = route
        let isNew = editing == nil && editingPurchase == nil
        let initialKind = editing?.kind ?? .expense
        _kind = State(initialValue: initialKind)
        _amountCents = State(initialValue: (editing?.amount ?? editingPurchase?.amount).map(amountToCents) ?? 0)
        // A new movement starts on the amount, with the in-app keypad open.
        _keypadOpen = State(initialValue: isNew)
        _accountId = State(initialValue: (editing?.account ?? data.defaultAccount ?? data.accounts.first)?.id)
        let firstOfKind = data.categories.first(where: { $0.kind == initialKind })
        _category = State(initialValue: editing?.category ?? editingPurchase?.category ?? firstOfKind)
        _description = State(initialValue: editing?.description ?? editingPurchase?.description ?? "")
        _date = State(initialValue: editing?.date)
        _credit = State(initialValue: initialCredit || editingPurchase != nil)
        _chosenCard = State(initialValue: editingPurchase?.card ?? data.creditCards.first)
        _dueDate = State(initialValue: editingPurchase?.dueDate ?? today.adding(days: defaultDaysToPay))
    }

    private var today: LocalDay { app.today }
    private var isNew: Bool { editing == nil && editingPurchase == nil }
    /// The expense of a credit purchase payment: only what the payment says (account, amount and
    /// date) can change. Its category and description are those of the purchase.
    private var isPayment: Bool { editing?.creditPurchaseId != nil }
    private var isExpense: Bool { kind == .expense }
    private var onCredit: Bool { credit && isExpense && editing == nil }

    private func categories(of kind: MovementKind) -> [Category] { data.categories.filter { $0.kind == kind } }

    /// The list holds the newest copy of the account (its balance changes with every movement);
    /// an edited movement may sit on an account that was archived since.
    private var account: Account? { data.accounts.first { $0.id == accountId } ?? editing?.account }

    /// The list can arrive (or change) after the form opens: a card that is no longer in it, like
    /// one just archived, falls back to the first one. The card of an edited purchase always stays.
    private var creditCard: CreditCard? {
        if let card = chosenCard,
           card.id == editingPurchase?.card.id || data.creditCards.contains(where: { $0.id == card.id }) {
            return card
        }
        return data.creditCards.first
    }

    /// A credit purchase is registered in the currency of its card. One being edited keeps the
    /// currency it was bought in unless it is moved to another card.
    private var purchaseCurrency: String? {
        if let editingPurchase, creditCard?.id == editingPurchase.card.id { return editingPurchase.currency }
        return creditCard?.currency
    }

    private var symbol: String { currencySymbol((onCredit ? purchaseCurrency : account?.currency) ?? PEN) }

    private var saveTitle: String {
        if !isNew { return "Guardar cambios" }
        if onCredit { return "Guardar compra pendiente" }
        return isExpense ? "Guardar egreso" : "Guardar ingreso"
    }

    var body: some View {
        ScreenScaffold(header: {
            ModalTopBar(
                title: editingPurchase != nil ? "Editar compra" : (editing != nil ? "Editar movimiento" : "Nuevo movimiento"),
                icon: .close,
                onNavigate: { app.pop() }
            ) {
                if !isNew {
                    CircleIconButton(
                        systemName: "trash", label: "Eliminar", container: Palette.expenseSoft, tint: Palette.expense
                    ) { confirmDelete = true }
                }
            }
        }, footer: {
            if keypadOpen {
                AmountKeypad(
                    onDigits: { amountCents = appendAmountDigits(amountCents, $0) },
                    onBackspace: { amountCents = removeAmountDigit(amountCents) },
                    onClear: { amountCents = 0 },
                    onDone: { keypadOpen = false }
                )
            } else {
                PrimaryButton(title: saveTitle, action: save)
            }
        }) {
            if isPayment {
                HintText(UiMessage.failed(.paymentLocked).text)
            }
            // A purchase with a credit card, and its payment, are always an expense: there is
            // nothing to switch to.
            if editingPurchase == nil && !isPayment {
                SegmentedControl(
                    options: tabs,
                    selected: isExpense ? FormTab.expense : FormTab.income,
                    onSelect: { tab in
                        switch tab {
                        case .transfer:
                            app.replaceTop(.transferForm())
                        default:
                            kind = tab == .expense ? .expense : .income
                            // Changing the type selects its first category.
                            category = categories(of: kind).first
                        }
                    }
                )
            }

            // Only when creating: the tabs alone do not tell the three forms apart.
            if isNew {
                FormIntro(
                    systemName: isExpense ? "arrow.down.left" : "arrow.up.right",
                    tint: isExpense ? Palette.expense : Palette.income,
                    container: isExpense ? Palette.expenseSoft : Palette.incomeSoft,
                    title: isExpense ? "Registrar egreso" : "Registrar ingreso",
                    subtitle: isExpense ? "¿En qué gastaste?" : "¿De dónde recibiste dinero?"
                )
                .padding(.top, 16)
            }

            amountCard.padding(.top, 14)

            if !onCredit {
                FieldLabel(isExpense ? "Sale de la cuenta" : "Ingresa a la cuenta")
                if let account {
                    DropdownField(
                        options: data.accounts,
                        selected: account,
                        onSelect: { accountId = $0.id },
                        label: { $0.name },
                        detail: { formatMoney($0.balance, $0.currency) },
                        leading: { option in
                            Image(systemName: option.icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Palette.primary)
                        }
                    )
                } else {
                    HintText("Crea una cuenta para poder registrar movimientos.")
                }
            }

            FieldLabel("Categoría")
            if let selectedCategory = category {
                if isPayment {
                    // Fixed: it is the category of the purchase that was paid.
                    ChipGroup { OrbitaChip(label: selectedCategory.name, selected: true) {} }
                } else {
                    DropdownField(
                        options: categories(of: kind),
                        selected: selectedCategory,
                        onSelect: { category = $0 },
                        label: { $0.name },
                        leading: { option in ColorDot(color: option.color) }
                    )
                }
            } else {
                HintText("No tienes categorías de este tipo. Créalas en Ajustes.")
            }

            FieldLabel("Descripción")
            if isPayment {
                // Fixed too: the description of the purchase, shown as plain text.
                Text(description.isEmpty ? "—" : description)
                    .font(OFont.bodyLarge)
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 4)
            } else {
                OrbitaTextArea(
                    text: $description, placeholder: "Ej. Almuerzo con equipo", maxLength: textMaxLength,
                    onFocus: { keypadOpen = false }
                )
            }

            // A new movement takes the date and time of the moment it is saved; the date can only
            // be changed later, when editing.
            if let editing {
                FieldLabel("Fecha")
                PickerField(value: formatDate(date ?? editing.date)) { pickingDate = true }
            } else if isNew {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "clock").font(.system(size: 14, weight: .medium)).foregroundStyle(Palette.muted)
                    HintText("Se guarda con la fecha y hora de este momento. Podrás cambiarla después, al editar el movimiento.")
                }
                .padding(.top, 14)
                .padding(.horizontal, 4)
            }

            // Only for new expenses (v1.1)
            if isExpense && editing == nil {
                OrbitaCard { creditCardSection }.padding(.top, 18)
            }
        }
        .dateDialog(
            isPresented: $pickingDate, title: "Elige la fecha",
            date: date ?? editing?.date ?? today, today: today
        ) { date = $0 }
        .dateDialog(
            isPresented: $pickingDueDate, title: "Fecha límite de pago",
            date: dueDate, today: today, allowFuture: true
        ) { dueDate = $0 }
        .confirmDialog(
            editingPurchase != nil ? "¿Eliminar esta compra?" : "¿Eliminar este movimiento?",
            isPresented: $confirmDelete,
            message: deleteText,
            confirmLabel: "Eliminar"
        ) { delete() }
    }

    private var tabs: [(FormTab, String)] {
        var list: [(FormTab, String)] = [(.expense, "Egreso"), (.income, "Ingreso")]
        // An existing movement cannot become a transfer.
        if editing == nil { list.append((.transfer, "Transferencia")) }
        return list
    }

    private var deleteText: String {
        if editingPurchase != nil { return "Dejará de contar en la deuda de la tarjeta." }
        // The expense of a payment: deleting it leaves the purchase pending again.
        if editing?.creditPurchaseId != nil {
            return "Este egreso es el pago de una compra con tarjeta. Al eliminarlo, la compra volverá a estar pendiente."
        }
        return "Dejará de contar en tus saldos y reportes."
    }

    private var amountCard: some View {
        OrbitaCard(onClick: {
            // The amount never uses the system keyboard.
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            keypadOpen = true
        }) {
            Text("Monto").font(OFont.labelMedium).foregroundStyle(Palette.muted)
            AmountDisplay(
                symbol: symbol, cents: amountCents,
                color: isExpense ? Palette.ink : Palette.income, active: keypadOpen
            )
            .padding(.top, 4)
        }
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(Palette.primary, lineWidth: keypadOpen ? 1.5 : 0)
        )
    }

    private var creditCardSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // A pending purchase stays one: it cannot be turned into a movement here.
            if editingPurchase == nil {
                SwitchRow(label: "Compra con tarjeta de crédito", isOn: $credit, labelFont: OFont.titleSmall)
            }
            HintText("No descuenta de tus cuentas. Queda pendiente hasta que la pagues.")
            if credit {
                FieldLabel("Tarjeta")
                if let selectedCard = creditCard {
                    DropdownField(
                        options: data.creditCards,
                        selected: selectedCard,
                        onSelect: { chosenCard = $0 },
                        label: { $0.name },
                        detail: { currencySymbol($0.currency) },
                        leading: { _ in
                            Image(systemName: "creditcard")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Palette.primary)
                        }
                    )
                } else {
                    HintText("Aún no tienes tarjetas de crédito")
                }
                FieldLabel("Fecha límite de pago")
                PickerField(value: formatDate(dueDate)) { pickingDueDate = true }
            }
        }
    }

    private func save() {
        let amount = centsToAmount(amountCents)
        let route = route
        if onCredit {
            let draft = CreditPurchaseDraft(
                cardId: creditCard?.id, amount: amount, categoryId: category?.id,
                description: description, dueDate: dueDate
            )
            savePurchase(draft, route)
        } else if let editingPurchase {
            let draft = CreditPurchaseDraft(
                cardId: creditCard?.id, amount: amount, categoryId: category?.id,
                description: description, dueDate: dueDate
            )
            app.perform(invalid: draft.validateEdit(purchaseDate: editingPurchase.purchaseDate), onDone: { app.close(route) }) {
                try await app.env.credit.updatePurchase(id: editingPurchase.id, draft)
            }
        } else {
            let draft = MovementDraft(
                kind: kind, amount: amount, accountId: account?.id, categoryId: category?.id,
                description: description, date: date
            )
            let editing = editing
            app.perform(invalid: draft.validate(today: today), onDone: { app.close(route) }) {
                if let editing {
                    try await app.env.entries.updateMovement(id: editing.id, draft)
                } else {
                    try await app.env.entries.createMovement(draft, id: UUID().uuidString)
                }
            }
        }
    }

    private func savePurchase(_ draft: CreditPurchaseDraft, _ route: Route) {
        app.perform(invalid: draft.validate(today: today), onDone: { app.close(route) }) {
            try await app.env.credit.createPurchase(draft, id: UUID().uuidString)
        }
    }

    private func delete() {
        let route = route
        if let editingPurchase {
            app.perform(onDone: { app.close(route) }) { try await app.env.credit.deletePurchase(id: editingPurchase.id) }
        } else if let editing {
            app.perform(onDone: { app.close(route) }) { try await app.env.entries.deleteMovement(id: editing.id) }
        }
    }
}
