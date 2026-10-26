import SwiftUI

private struct AccountsData {
    let accounts: [Account]
    let fx: FxPair
    let displayCurrency: String
}

/// Cuentas: the savings total and one card per account.
struct AccountsView: View {
    @Environment(AppModel.self) private var app
    @State private var loader = Loader<AccountsData>()

    var body: some View {
        Loaded(load: loader.state, onRetry: { loader.retry() }) { data in
            ScreenScaffold(header: {
                ScreenHeader(title: "Cuentas") {
                    PillButton(title: "Transferir", systemImage: "arrow.left.arrow.right") {
                        app.push(.transferForm())
                    }
                }
            }) {
                SavingsSummaryCard(accounts: data.accounts, fx: data.fx, displayCurrency: data.displayCurrency) {
                    app.push(.settings)
                }
                VStack(spacing: 12) {
                    ForEach(data.accounts) { account in
                        AccountCard(
                            account: account, fx: data.fx,
                            onClick: { app.push(.accountForm(account)) },
                            onToggleSavings: { include in
                                app.perform { try await app.env.accounts.setIncludeInSavings(id: account.id, include) }
                            }
                        )
                    }
                    DashedButton(title: "Nueva cuenta", systemImage: "plus") { app.push(.accountForm(nil)) }
                }
                .padding(.top, 12)
                HintText("Cada cuenta tiene su propia moneda y un nombre que puedes cambiar. Apaga el interruptor en las cuentas que no quieras sumar a tus ahorros.")
                    .padding(.top, 14)
                    .padding(.horizontal, 4)
            }
        }
        .task(id: [app.revision, loader.attempt]) {
            await loader.run {
                async let accounts = app.env.accounts.accounts()
                async let settings = app.env.settings.settings()
                let userSettings = try await settings
                return AccountsData(
                    accounts: try await accounts, fx: userSettings.fx, displayCurrency: userSettings.displayCurrency
                )
            }
        }
    }
}

private struct SavingsSummaryCard: View {
    let accounts: [Account]
    let fx: FxPair
    let displayCurrency: String
    let onConfigureFx: () -> Void

    var body: some View {
        let otherCurrency = fx.other(displayCurrency)
        HeroCard(scrim: true) {
            HeroLabel("Total en ahorros · \(accounts.filter(\.includeInSavings).count) de \(accounts.count) cuentas")
            HeroAmount(formatMoney(fx.savingsTotal(of: accounts, in: displayCurrency), displayCurrency))
                .padding(.top, 6)
            Group {
                if let rate = fx.rate {
                    // Plain supporting line: the same total in the other currency.
                    Text("o \(formatMoney(fx.savingsTotal(of: accounts, in: otherCurrency), otherCurrency)) · cambio \(formatRate(rate))")
                        .font(OFont.bodyMedium)
                        .foregroundStyle(Color.white.opacity(0.85))
                        .lineLimit(1)
                } else {
                    // A new user has no exchange rate yet: the line leads to where it is set.
                    Button(action: onConfigureFx) {
                        Text("Configura tu tipo de cambio ›").font(OFont.bodyMedium).foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 4)
        }
    }
}

private struct AccountCard: View {
    let account: Account
    let fx: FxPair
    let onClick: () -> Void
    let onToggleSavings: (Bool) -> Void

    var body: some View {
        let currencyName = currencyInfo(account.currency).name.lowercased()
        // Equivalent in the main currency, when the account is in another one with a known rate.
        let inMain = account.currency == fx.main ? nil : fx.convert(account.balance, from: account.currency, to: fx.main)
        OrbitaCard {
            Button(action: onClick) {
                HStack(spacing: 12) {
                    IconBadge(systemName: account.icon, tint: Palette.primary, container: Palette.primarySoft)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(account.name).font(OFont.titleSmall).foregroundStyle(Palette.ink).lineLimit(1)
                        Text("\(account.type.label) · \(currencyName)").font(OFont.bodySmall).foregroundStyle(Palette.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(formatMoney(account.balance, account.currency)).font(OFont.titleMedium).foregroundStyle(Palette.ink)
                        if let inMain {
                            Text("≈ \(formatMoney(inMain, fx.main))").font(OFont.bodySmall).foregroundStyle(Palette.muted)
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            CardDivider().padding(.top, -10)
            SwitchRow(
                label: "Contar en el total de ahorros",
                isOn: Binding(get: { account.includeInSavings }, set: onToggleSavings),
                labelColor: Palette.muted
            )
        }
    }
}

/// New account (`account` = nil) or edit account.
struct AccountFormView: View {
    @Environment(AppModel.self) private var app
    let account: Account?

    @State private var settings = Loader<FxPair>()
    @State private var name: String
    @State private var type: AccountType
    @State private var currency: String
    @State private var initialBalance = ""
    @State private var includeInSavings: Bool
    @State private var confirmArchive = false
    @State private var currencyTouched = false

    init(account: Account?) {
        self.account = account
        _name = State(initialValue: account?.name ?? "")
        _type = State(initialValue: account?.type ?? .debit)
        _currency = State(initialValue: account?.currency ?? PEN)
        _includeInSavings = State(initialValue: account?.includeInSavings ?? true)
    }

    private var editing: Bool { account != nil }
    private var route: Route { .accountForm(account) }

    var body: some View {
        Loaded(load: settings.state, onRetry: { settings.retry() }, onClose: { app.pop() }) { fx in
            form(fx)
        }
        .task(id: [app.revision, settings.attempt]) {
            await settings.run { try await app.env.settings.settings().fx }
        }
    }

    private func form(_ fx: FxPair) -> some View {
        // Starts on the user's default currency (Ajustes).
        let shownCurrency = (editing || currencyTouched) ? currency : fx.main
        return ScreenScaffold(header: {
            ModalTopBar(
                title: editing ? "Editar cuenta" : "Nueva cuenta",
                icon: editing ? .back : .close,
                onNavigate: { app.pop() }
            )
        }, footer: {
            PrimaryButton(title: editing ? "Guardar cambios" : "Guardar cuenta") {
                save(currency: shownCurrency)
            }
        }) {
            FieldLabel("Nombre")
            OrbitaTextField(text: $name, placeholder: "Ej. Débito principal")

            FieldLabel("Tipo")
            ChipGroup {
                ForEach(AccountType.allCases, id: \.self) { option in
                    OrbitaChip(label: option.label, selected: type == option) { type = option }
                }
            }

            FieldLabel("Moneda")
            if editing {
                // The currency cannot change once the account has movements.
                ChipGroup { OrbitaChip(label: currencyInfo(currency).label, selected: true) {} }
                HintText("La moneda de una cuenta no se puede cambiar.").padding(.top, 8)
            } else {
                if fx.isConfigured {
                    DropdownField(
                        options: supportedCurrencies,
                        selected: currencyInfo(shownCurrency),
                        onSelect: {
                            currency = $0.code
                            currencyTouched = true
                        },
                        label: { $0.label },
                        detail: { $0.code },
                        leading: { _ in EmptyView() }
                    )
                } else {
                    ChipGroup { OrbitaChip(label: currencyInfo(fx.main).label, selected: true) {} }
                    HintText("Configura tu tipo de cambio en Ajustes para usar otras monedas.").padding(.top, 8)
                }
                FieldLabel("Saldo inicial (opcional)")
                OrbitaTextField(
                    text: $initialBalance, placeholder: "0.00",
                    prefix: currencySymbol(shownCurrency), keyboard: .decimalPad
                )
                .onChange(of: initialBalance) { _, value in
                    let cleaned = sanitizeDecimalInput(value, maxDecimals: 2)
                    if cleaned != value { initialBalance = cleaned }
                }
            }

            OrbitaCard {
                SwitchRow(label: "Contar en el total de ahorros", isOn: $includeInSavings)
            }
            .padding(.top, 18)

            if editing {
                PillButton(
                    title: "Archivar cuenta", systemImage: "archivebox",
                    container: Palette.expenseSoft, content: Palette.expense
                ) { confirmArchive = true }
                .padding(.top, 24)
                HintText("La cuenta deja de aparecer en las listas, pero conserva sus movimientos.").padding(.top, 8)
            }
        }
        .confirmDialog(
            "¿Archivar esta cuenta?", isPresented: $confirmArchive,
            message: "La cuenta deja de aparecer en las listas, pero conserva sus movimientos.",
            confirmLabel: "Archivar"
        ) {
            guard let account else { return }
            app.perform(onDone: { app.close(route) }) { try await app.env.accounts.archive(id: account.id) }
        }
    }

    private func save(currency shownCurrency: String) {
        let draft = AccountDraft(
            name: name, type: type, currency: shownCurrency,
            // An empty field is a balance of zero.
            initialBalance: parseDecimal(initialBalance) ?? 0,
            includeInSavings: includeInSavings
        )
        let account = account
        app.perform(invalid: draft.validate(), onDone: { app.close(route) }) {
            if let account {
                try await app.env.accounts.update(id: account.id, draft)
            } else {
                try await app.env.accounts.create(draft, id: UUID().uuidString)
            }
        }
    }
}
