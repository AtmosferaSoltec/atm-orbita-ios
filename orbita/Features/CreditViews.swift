import SwiftUI

/// Pending credit card purchases (v1.1). They are reminders, not movements.
struct CreditView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScreenScaffold {
            ScreenHeader(title: "Tarjeta de crédito", overline: "Compras pendientes de pago")
        } content: {
            ToPayCard(purchases: model.purchases)
            PrimaryButton(
                title: "Registrar compra con tarjeta",
                container: Palette.primarySoft, content: Palette.primary, systemImage: "plus"
            ) { model.flow = .newEntry(credit: true, startsAsTransfer: false) }
                .padding(.top, 12)

            if model.purchases.isEmpty {
                StateMessage(systemImage: "checkmark", title: "No tienes compras pendientes")
            } else {
                Text("Ordenadas por fecha límite")
                    .font(OFont.labelMedium)
                    .foregroundStyle(Palette.muted)
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                    .padding(.leading, 4)
                VStack(spacing: 12) {
                    ForEach(model.purchases.sorted { $0.dueDate < $1.dueDate }) { purchase in
                        PurchaseCard(purchase: purchase) { model.push(.payCredit(purchase)) }
                    }
                }
            }
        }
    }
}

/// Totals per currency of the pending purchases, never mixed.
private struct ToPayCard: View {
    let purchases: [MockCreditPurchase]

    private func total(_ currency: String) -> Decimal {
        purchases.filter { $0.currency == currency }.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        let usd = total(USD)
        HeroCard {
            HeroLabel("Por pagar")
            HeroAmount(formatMoney(total(PEN), PEN)).padding(.top, 6)
            if usd.isPositive {
                Text("+ \(formatMoney(usd, USD))").font(OFont.titleLarge).foregroundStyle(Palette.onHero)
            }
            Text("No cuenta en tus saldos ni en tus reportes hasta que la marques como pagada.")
                .font(OFont.bodySmall)
                .foregroundStyle(Palette.onHeroMuted)
                .padding(.top, 10)
        }
    }
}

func dueLabel(_ purchase: MockCreditPurchase) -> String {
    let days = purchase.daysUntilDue
    let date = formatDayMonth(purchase.dueDate)
    switch days {
    case ..<(-1): return "Vencida hace \(-days) días"
    case -1: return "Vencida hace 1 día"
    case 0: return "Vence hoy"
    case 1: return "Vence \(date) · mañana"
    default: return "Vence \(date) · en \(days) días"
    }
}

private struct PurchaseCard: View {
    let purchase: MockCreditPurchase
    let onPay: () -> Void

    var body: some View {
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
            Text("\(purchase.category.name) · compra \(formatDayMonth(purchase.purchaseDate))")
                .font(OFont.bodySmall)
                .foregroundStyle(Palette.muted)
            // Urgent: due in 3 days or less, or overdue.
            StatusChip(
                text: dueLabel(purchase),
                container: purchase.isUrgent ? Palette.expenseSoft : Palette.neutralSoft,
                content: purchase.isUrgent ? Palette.expense : Palette.neutral
            )
            .padding(.top, 12)
            PillButton(title: "Marcar como pagada", systemImage: "checkmark", action: onPay)
                .padding(.top, 10)
        }
    }
}

/// "Marcar como pagada": only now the expense is created in the chosen account.
struct PayCreditView: View {
    @Environment(AppModel.self) private var model
    let purchase: MockCreditPurchase

    @State private var account = SampleData.debitAccount
    @State private var amount: String

    init(purchase: MockCreditPurchase) {
        self.purchase = purchase
        _amount = State(initialValue: Self.suggestedAmount(for: SampleData.debitAccount, purchase: purchase))
    }

    // If the currencies match, the purchase amount is suggested; otherwise the user must type
    // what the bank really charged.
    private static func suggestedAmount(for account: MockAccount, purchase: MockCreditPurchase) -> String {
        account.currency == purchase.currency ? plainAmount(purchase.amount) : ""
    }

    var body: some View {
        let paid = parseDecimal(amount) ?? 0

        ScreenScaffold {
            ModalTopBar(title: "Marcar como pagada", icon: .back) { model.pop() }
        } footer: {
            PrimaryButton(title: "Confirmar pago") { model.markPaid(purchase) }
        } content: {
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
                ForEach(model.accounts) { option in
                    OrbitaChip(label: option.name, selected: option.id == account.id) {
                        account = option
                        amount = Self.suggestedAmount(for: option, purchase: purchase)
                    }
                }
            }

            FieldLabel("Monto realmente descontado")
            OrbitaTextField(
                text: $amount, placeholder: "0.00",
                prefix: currencySymbol(account.currency), keyboard: .decimalPad
            )
            HintText("Si la compra fue en dólares, escribe aquí los soles que te cobró el banco.")
                .padding(.top, 8)

            FieldLabel("Fecha de pago · hoy, editable")
            PickerField(value: formatDate(SampleData.today))

            OrbitaCard {
                Text("Se creará este egreso").font(OFont.labelMedium).foregroundStyle(Palette.muted)
                LabelValueRow(
                    label: "\(purchase.category.name) · \(account.name)",
                    value: formatSignedMoney(paid, account.currency, positive: false),
                    labelColor: Palette.ink,
                    valueColor: Palette.expense
                )
                .padding(.top, 10)
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
}

#Preview("Crédito") { CreditView().environment(AppModel()) }

#Preview("Marcar como pagada") {
    PayCreditView(purchase: SampleData.creditPurchases[0]).environment(AppModel())
}
