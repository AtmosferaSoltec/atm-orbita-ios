import SwiftUI
import UIKit

private struct TransferData {
    let accounts: [Account]
    let fx: FxPair
}

private enum TransferTab: Hashable { case expense, income, transfer }

/// The two amounts of a transfer; the in-app keypad types into one of them at a time.
private enum AmountField { case outgoing, incoming }

/// Manual rate: units of `to`'s currency per 1 unit of `from`'s. Outside the user's pair of
/// currencies there is no rate: it is left empty for the user to type, never made up.
private func referenceRate(_ from: Account, _ to: Account, _ fx: FxPair) -> Decimal? {
    fx.rateBetween(from: from.currency, to: to.currency)
}

private func rateText(_ rate: Decimal?) -> String { rate.map(formatRate) ?? "" }

/// Loads the accounts and the rate, then shows the form.
struct TransferFormScreen: View {
    @Environment(AppModel.self) private var app
    let editing: Transfer?

    @State private var loader = Loader<TransferData>()

    var body: some View {
        Loaded(load: loader.state, onRetry: { loader.retry() }, onClose: { app.pop() }) { data in
            // A new transfer starts on the first two accounts; both can be changed. An edited one
            // starts on its own, taken from the list: the transfer's copy has no balance, and the
            // preview of the balances needs it.
            let from = editing.flatMap { current($0.from, data) } ?? data.accounts.first
            let to = editing.flatMap { current($0.to, data) } ?? (data.accounts.count > 1 ? data.accounts[1] : nil)
            if let from, let to {
                TransferForm(data: data, initialFrom: from, initialTo: to, editing: editing, today: app.today)
            } else {
                NoticeScreen(
                    barTitle: "Transferir",
                    title: "Necesitas dos cuentas",
                    message: "Una transferencia mueve dinero entre dos cuentas tuyas.",
                    onClose: { app.pop() }
                )
            }
        }
        .task(id: [app.revision, loader.attempt]) {
            await loader.run {
                async let accounts = app.env.accounts.accounts()
                async let settings = app.env.settings.settings()
                return TransferData(accounts: try await accounts, fx: try await settings.fx)
            }
        }
    }

    private func current(_ account: Account, _ data: TransferData) -> Account {
        data.accounts.first { $0.id == account.id } ?? account
    }
}

/// Transfer between two own accounts, both chosen by the user. With different currencies the
/// amount out, the (manual) rate and the amount in are linked; with the same currency there is
/// no exchange.
private struct TransferForm: View {
    @Environment(AppModel.self) private var app
    let data: TransferData
    let editing: Transfer?
    let today: LocalDay

    @State private var from: Account
    @State private var to: Account
    // A new transfer starts empty; an edited one, with what was saved. Both amounts are typed
    // with the in-app keypad, so they are kept in cents like the amount of a movement.
    @State private var outCents: Int64
    @State private var rate: String
    @State private var inCents: Int64
    // The amount the keypad is typing into; nil while it is closed.
    @State private var keypadField: AmountField?
    @State private var date: LocalDay
    @State private var pickingDate = false
    @State private var note: String
    @State private var confirmDelete = false
    @FocusState private var rateFocused: Bool

    init(data: TransferData, initialFrom: Account, initialTo: Account, editing: Transfer?, today: LocalDay) {
        self.data = data
        self.editing = editing
        self.today = today
        _from = State(initialValue: initialFrom)
        _to = State(initialValue: initialTo)
        _outCents = State(initialValue: editing.map { amountToCents($0.fromAmount) } ?? 0)
        _rate = State(initialValue: rateText(editing?.exchangeRate ?? referenceRate(initialFrom, initialTo, data.fx)))
        _inCents = State(initialValue: editing.map { amountToCents($0.toAmount) } ?? 0)
        _date = State(initialValue: editing?.date ?? today)
        _note = State(initialValue: editing?.note ?? "")
    }

    private var fx: FxPair { data.fx }
    private var sameCurrency: Bool { from.currency == to.currency }
    private var reference: Decimal? { referenceRate(from, to, fx) }
    private var route: Route { .transferForm(editing: editing) }

    // The rate field shows up to 4 decimals. While it shows the manual rate of the pair, the
    // exact one behind it is used: 1 ÷ 3.75 reads 0.2667, yet S/ 375 is US$ 100.00, not 100.01.
    private func rateValue(_ text: String) -> Decimal? {
        if let exact = reference, rateText(exact) == text { return exact }
        return parsePositiveDecimal(text)
    }

    // in = round(out × rate, 2), or the exact conversion of the pair when its rate is untouched.
    private func recalculateIncoming(_ newOutCents: Int64, _ newRate: String) {
        let out = centsToAmount(newOutCents)
        let converted: Decimal
        if let exact = reference, rateText(exact) == newRate {
            guard let value = fx.convert(out, from: from.currency, to: to.currency) else { return }
            converted = value
        } else {
            guard let parsed = parsePositiveDecimal(newRate) else { return }
            converted = (out * parsed).rounded(scale: 2)
        }
        inCents = min(amountToCents(converted), maxAmountCents)
    }

    // Changing an account resets the rate to the manual one of the new pair of currencies.
    private func setAccounts(_ newFrom: Account, _ newTo: Account) {
        from = newFrom
        to = newTo
        rate = rateText(referenceRate(newFrom, newTo, fx))
        // Without a rate for the new pair, what comes in is unknown until the user types it.
        if rate.isEmpty && newFrom.currency != newTo.currency { inCents = 0 }
        recalculateIncoming(outCents, rate)
    }

    // What the keypad types goes to the active amount; the other values follow.
    private func typeAmount(_ change: (Int64) -> Int64) {
        switch keypadField {
        case .outgoing:
            outCents = change(outCents)
            recalculateIncoming(outCents, rate)
        case .incoming:
            inCents = change(inCents)
            // rate = in ÷ out
            if inCents > 0 && outCents > 0 {
                rate = formatRate((centsToAmount(inCents) / centsToAmount(outCents)).rounded(scale: 6))
            }
        case nil:
            break
        }
    }

    // The amounts never use the system keyboard.
    private func openKeypad(_ field: AmountField) {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        keypadField = field
    }

    private var outAmount: Decimal { centsToAmount(outCents) }
    private var inAmount: Decimal { sameCurrency ? outAmount : centsToAmount(inCents) }

    // When editing, the balances already count this transfer: it is taken back first.
    private func withoutEdited(_ account: Account) -> Decimal {
        var balance = account.balance
        if let editing, editing.from.id == account.id { balance += editing.fromAmount }
        if let editing, editing.to.id == account.id { balance -= editing.toAmount }
        return balance
    }

    var body: some View {
        let fromAfter = withoutEdited(from) - outAmount
        let toAfter = withoutEdited(to) + inAmount
        ScreenScaffold(header: {
            ModalTopBar(title: editing != nil ? "Editar transferencia" : "Transferir", icon: .close, onNavigate: { app.pop() }) {
                if editing != nil {
                    CircleIconButton(
                        systemName: "trash", label: "Eliminar", container: Palette.expenseSoft, tint: Palette.expense
                    ) { confirmDelete = true }
                }
            }
        }, footer: {
            if keypadField != nil {
                AmountKeypad(
                    onDigits: { digits in typeAmount { appendAmountDigits($0, digits) } },
                    onBackspace: { typeAmount(removeAmountDigit) },
                    onClear: { typeAmount { _ in 0 } },
                    onDone: { keypadField = nil }
                )
            } else {
                PrimaryButton(title: editing != nil ? "Guardar cambios" : "Guardar transferencia", action: save)
            }
        }) {
            if editing == nil {
                SegmentedControl(
                    options: [(TransferTab.expense, "Egreso"), (.income, "Ingreso"), (.transfer, "Transferencia")],
                    selected: .transfer,
                    onSelect: { if $0 != .transfer { app.replaceTop(.movementForm()) } }
                )
                FormIntro(
                    systemName: "arrow.left.arrow.right", tint: Palette.transfer, container: Palette.transferSoft,
                    title: "Registrar transferencia", subtitle: "¿Entre qué cuentas moviste dinero?"
                )
                .padding(.top, 16)
            }

            // The same account cannot be on both sides: picking the other side's account swaps them.
            FieldLabel("Desde")
            AccountDropdown(accounts: data.accounts, selected: from) { picked in
                if picked.id == to.id { setAccounts(to, from) } else { setAccounts(picked, to) }
            }
            Button { setAccounts(to, from) } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Palette.primary)
                    .frame(width: 48, height: 48)
                    .background(Palette.surface, in: Circle())
                    .overlay(Circle().strokeBorder(Palette.outline, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Invertir cuentas")
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
            FieldLabel("Hacia")
            AccountDropdown(accounts: data.accounts, selected: to) { picked in
                if picked.id == from.id { setAccounts(to, from) } else { setAccounts(from, picked) }
            }

            amountsCard.padding(.top, 12)
            if !sameCurrency {
                HintText("Si el banco aplicó otro cambio, edita el tipo de cambio o el monto que entra y el otro valor se recalcula.")
                    .padding(.top, 10)
                    .padding(.horizontal, 4)
            }

            SectionTitle(text: "Saldos después de transferir")
            OrbitaCard {
                LabelValueRow(
                    label: from.name, value: formatMoney(fromAfter, from.currency),
                    valueColor: fromAfter < 0 ? Palette.expense : Palette.ink
                )
                Color.clear.frame(height: 10)
                LabelValueRow(label: to.name, value: formatMoney(toAfter, to.currency))
            }
            // Warn, but do not block.
            if fromAfter < 0 {
                HintText("El saldo de \(from.name) quedaría en negativo.", color: Palette.expense)
                    .padding(.top, 8)
                    .padding(.leading, 4)
            }

            FieldLabel("Fecha")
            PickerField(value: formatDate(date)) { pickingDate = true }

            FieldLabel("Nota (opcional)")
            OrbitaTextField(text: $note, placeholder: "Ej. Cambio de dólares")
                .simultaneousGesture(TapGesture().onEnded { keypadField = nil })
        }
        .dateDialog(isPresented: $pickingDate, title: "Elige la fecha", date: date, today: today) { date = $0 }
        .confirmDialog(
            "¿Eliminar esta transferencia?", isPresented: $confirmDelete,
            message: "Dejará de contar en tus saldos y reportes.", confirmLabel: "Eliminar"
        ) { delete() }
    }

    private var amountsCard: some View {
        OrbitaCard {
            cardLabel("Monto que sale")
            AmountDisplay(
                symbol: currencySymbol(from.currency), cents: outCents, active: keypadField == .outgoing
            )
            .contentShape(Rectangle())
            .onTapGesture { openKeypad(.outgoing) }
            .accessibilityAddTraits(.isButton)
            // Same currency: no exchange rate, in = out.
            if !sameCurrency {
                CardDivider()
                HStack {
                    cardLabel("Tipo de cambio · editable").frame(maxWidth: .infinity, alignment: .leading)
                    cardLabel("Referencia")
                }
                HStack(spacing: 8) {
                    Text("1 \(currencySymbol(from.currency)) = \(currencySymbol(to.currency))")
                        .font(OFont.titleMedium)
                        .foregroundStyle(Palette.ink)
                    // The rate has up to 4 decimals: it keeps the decimal keyboard of the system.
                    TextField("", text: $rate)
                        .font(OFont.titleMedium)
                        .foregroundStyle(Palette.ink)
                        .keyboardType(.decimalPad)
                        .focused($rateFocused)
                        .frame(width: 88)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Palette.neutralSoft, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                        .onChange(of: rate) { _, value in
                            let cleaned = sanitizeDecimalInput(value, maxDecimals: 6)
                            if cleaned != value { rate = cleaned }
                            recalculateIncoming(outCents, cleaned)
                        }
                        .onChange(of: rateFocused) { _, focused in
                            if focused { keypadField = nil }
                        }
                    Spacer(minLength: 0)
                    // Only when there is a manual rate for this pair of currencies.
                    if let reference {
                        Text("manual \(formatRate(reference))").font(OFont.bodySmall).foregroundStyle(Palette.muted)
                    }
                }
                .padding(.top, 6)
                CardDivider()
                cardLabel("Monto que entra · editable")
                AmountDisplay(
                    symbol: currencySymbol(to.currency), cents: inCents, active: keypadField == .incoming,
                    font: OFont.headlineMedium, cursorHeight: 26
                )
                .contentShape(Rectangle())
                .onTapGesture { openKeypad(.incoming) }
                .accessibilityAddTraits(.isButton)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(Palette.primary, lineWidth: keypadField != nil ? 1.5 : 0)
        )
    }

    private func cardLabel(_ text: String) -> some View {
        Text(text).font(OFont.labelMedium).foregroundStyle(Palette.muted)
    }

    private func save() {
        let draft = TransferDraft(
            fromAccountId: from.id, toAccountId: to.id, fromAmount: outAmount,
            // Same currency: no exchange, what goes out is what comes in.
            toAmount: inAmount, exchangeRate: sameCurrency ? nil : rateValue(rate),
            date: date, note: note
        )
        let route = route
        let editing = editing
        let sameCurrency = sameCurrency
        app.perform(invalid: draft.validate(today: today, sameCurrency: sameCurrency), onDone: { app.close(route) }) {
            if let editing {
                try await app.env.entries.updateTransfer(id: editing.id, draft)
            } else {
                try await app.env.entries.createTransfer(draft, id: UUID().uuidString)
            }
        }
    }

    private func delete() {
        guard let editing else { return }
        let route = route
        app.perform(onDone: { app.close(route) }) { try await app.env.entries.deleteTransfer(id: editing.id) }
    }
}

/// "Desde" / "Hacia" selector: every account with its icon and balance.
private struct AccountDropdown: View {
    let accounts: [Account]
    let selected: Account
    let onSelect: (Account) -> Void

    var body: some View {
        DropdownField(
            options: accounts,
            // The list may hold a newer copy of the account (e.g. savings switch changed).
            selected: accounts.first { $0.id == selected.id } ?? selected,
            onSelect: onSelect,
            label: { $0.name },
            detail: { formatMoney($0.balance, $0.currency) },
            leading: { option in
                Image(systemName: option.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.primary)
            }
        )
    }
}
