import SwiftUI

struct AccountsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScreenScaffold {
            ScreenHeader(title: "Cuentas") {
                PillButton(title: "Transferir", systemImage: "arrow.left.arrow.right") {
                    model.flow = .newEntry(credit: false, startsAsTransfer: true)
                }
            }
        } content: {
            SavingsSummaryCard()
            VStack(spacing: 12) {
                ForEach(model.accounts) { account in
                    AccountCard(account: account)
                }
                DashedButton(title: "Nueva cuenta", systemImage: "plus") { model.flow = .newAccount }
            }
            .padding(.top, 12)
            HintText("Cada cuenta tiene su propia moneda y un nombre que puedes cambiar. Apaga el interruptor en las cuentas que no quieras sumar a tus ahorros.")
                .padding(.top, 14)
                .padding(.horizontal, 4)
        }
    }
}

private struct SavingsSummaryCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let displayCurrency = model.displayCurrency
        let other = displayCurrency == PEN ? USD : PEN
        HeroCard {
            HeroLabel("Total en ahorros · \(model.accounts.filter(\.includeInSavings).count) de \(model.accounts.count) cuentas")
            HeroAmount(formatMoney(model.accounts.savingsTotal(displayCurrency), displayCurrency))
                .padding(.top, 6)
            Text("≈ \(formatMoney(model.accounts.savingsTotal(other), other)) · cambio \(formatRate(SampleData.usdToPen))")
                .font(OFont.bodySmall)
                .foregroundStyle(Palette.onHeroMuted)
                .padding(.top, 4)
        }
    }
}

private struct AccountCard: View {
    @Environment(AppModel.self) private var model
    let account: MockAccount

    var body: some View {
        OrbitaCard {
            Button { model.push(.accountEdit(account)) } label: {
                HStack(spacing: 12) {
                    IconBadge(systemName: account.icon, tint: Palette.primary, container: Palette.primarySoft)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(account.name).font(OFont.titleSmall).foregroundStyle(Palette.ink).lineLimit(1)
                        Text("\(account.type.label) · \(account.currency == USD ? "dólares" : "soles")")
                            .font(OFont.bodySmall)
                            .foregroundStyle(Palette.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(formatMoney(account.balance, account.currency))
                            .font(OFont.titleMedium)
                            .foregroundStyle(Palette.ink)
                        if account.currency != PEN {
                            Text("≈ \(formatMoney(convert(account.balance, from: account.currency, to: PEN), PEN))")
                                .font(OFont.bodySmall)
                                .foregroundStyle(Palette.muted)
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            CardDivider().padding(.top, 2)
            SwitchRow(
                label: "Contar en el total de ahorros",
                isOn: Binding(
                    get: { account.includeInSavings },
                    set: { model.setIncludeInSavings($0, for: account) }
                ),
                labelColor: Palette.muted
            )
        }
    }
}

/// New account (`account` = nil) or edit account. Not in the original mockups (docs/05, section 9).
struct AccountFormView: View {
    let account: MockAccount?
    let onClose: () -> Void
    let onSave: () -> Void

    @State private var name: String
    @State private var type: AccountType
    @State private var currency: String
    @State private var initialBalance = ""
    @State private var includeInSavings: Bool
    @State private var confirmArchive = false

    init(account: MockAccount?, onClose: @escaping () -> Void, onSave: @escaping () -> Void) {
        self.account = account
        self.onClose = onClose
        self.onSave = onSave
        _name = State(initialValue: account?.name ?? "")
        _type = State(initialValue: account?.type ?? .debit)
        _currency = State(initialValue: account?.currency ?? PEN)
        _includeInSavings = State(initialValue: account?.includeInSavings ?? true)
    }

    private var editing: Bool { account != nil }

    var body: some View {
        ScreenScaffold {
            ModalTopBar(
                title: editing ? "Editar cuenta" : "Nueva cuenta",
                icon: editing ? .back : .close,
                onNavigate: onClose
            )
        } footer: {
            PrimaryButton(title: editing ? "Guardar cambios" : "Guardar cuenta", action: onSave)
        } content: {
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
                ChipGroup {
                    OrbitaChip(
                        label: currency == USD ? "Dólares (US$)" : "Soles (S/)",
                        selected: true
                    ) {}
                }
                HintText("La moneda no se puede cambiar porque la cuenta ya tiene movimientos.")
                    .padding(.top, 8)
            } else {
                ChipGroup {
                    OrbitaChip(label: "Soles (S/)", selected: currency == PEN) { currency = PEN }
                    OrbitaChip(label: "Dólares (US$)", selected: currency == USD) { currency = USD }
                }
                FieldLabel("Saldo inicial (opcional)")
                OrbitaTextField(
                    text: $initialBalance, placeholder: "0.00",
                    prefix: currencySymbol(currency), keyboard: .decimalPad
                )
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
                HintText("La cuenta deja de aparecer en las listas, pero conserva sus movimientos.")
                    .padding(.top, 8)
            }
        }
        .confirmDialog(
            "¿Archivar esta cuenta?",
            isPresented: $confirmArchive,
            message: "La cuenta deja de aparecer en las listas, pero conserva sus movimientos.",
            confirmLabel: "Archivar",
            onConfirm: onSave
        )
    }
}

#Preview("Cuentas") { AccountsView().environment(AppModel()) }
#Preview("Nueva cuenta") { AccountFormView(account: nil, onClose: {}, onSave: {}) }
#Preview("Editar cuenta") { AccountFormView(account: SampleData.dollarAccount, onClose: {}, onSave: {}) }
