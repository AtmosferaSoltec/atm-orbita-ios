import SwiftUI

enum HomeState { case content, loading, empty, error }

struct HomeView: View {
    @Environment(AppModel.self) private var model
    var state: HomeState = .content

    var body: some View {
        ScreenScaffold {
            ScreenHeader(title: "Inicio", overline: "Resumen") {
                CircleIconButton(systemName: "gearshape", label: "Ajustes") { model.push(.settings) }
            }
        } content: {
            switch state {
            case .loading:
                HomeSkeleton()
            case .error:
                StateMessage(
                    systemImage: "exclamationmark.circle",
                    title: "No se pudo cargar",
                    message: "Revisa tu conexión e inténtalo de nuevo.",
                    actionLabel: "Reintentar"
                )
            case .content, .empty:
                let isEmpty = state == .empty
                SavingsHeroCard()
                MonthCards(
                    income: isEmpty ? 0 : SampleData.monthIncome,
                    expense: isEmpty ? 0 : SampleData.monthExpense
                )
                .padding(.top, 12)
                HintText("Las transferencias y las compras de tarjeta pendientes no entran aquí.")
                    .padding(.top, 10)
                    .padding(.horizontal, 4)
                if !isEmpty {
                    CreditReminderCard { model.tab = .credit }.padding(.top, 14)
                }
                SectionTitle(
                    text: "Últimos movimientos",
                    actionLabel: isEmpty ? nil : "Ver todos",
                    onAction: { model.push(.movements) }
                )
                if isEmpty {
                    OrbitaCard {
                        StateMessage(
                            systemImage: "plus",
                            title: "Registra tu primer movimiento",
                            message: "Toca el botón + para anotar un ingreso o un egreso."
                        )
                    }
                } else {
                    EntryList(entries: SampleData.recentEntries) { model.open($0) }
                }
            }
        }
    }
}

private struct SavingsHeroCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let displayCurrency = model.displayCurrency
        let other = displayCurrency == PEN ? USD : PEN
        HeroCard {
            HStack {
                HeroLabel("Ahorro total")
                Spacer()
                SegmentedControl(
                    options: [(PEN, "S/"), (USD, "US$")],
                    selected: displayCurrency,
                    onSelect: { model.displayCurrency = $0 },
                    fill: false,
                    onHero: true
                )
            }
            HeroAmount(formatMoney(model.accounts.savingsTotal(displayCurrency), displayCurrency))
                .padding(.top, 6)
            Text("≈ \(formatMoney(model.accounts.savingsTotal(other), other)) · cambio \(formatRate(SampleData.usdToPen)) (manual)")
                .font(OFont.bodySmall)
                .foregroundStyle(Palette.onHeroMuted)
                .padding(.top, 4)
            CardDivider(color: Palette.heroDivider)
            Button { model.tab = .accounts } label: {
                HStack(spacing: 0) {
                    Text("\(model.accounts.filter(\.includeInSavings).count) de \(model.accounts.count) cuentas incluidas")
                        .font(OFont.bodyMedium)
                        .foregroundStyle(Palette.onHeroMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Elegir").font(OFont.labelLarge).foregroundStyle(Palette.onHero)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.onHero)
                        .padding(.leading, 4)
                }
                .frame(minHeight: 40)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

private struct MonthCards: View {
    let income: Decimal
    let expense: Decimal

    var body: some View {
        let month = monthName(SampleData.today)
        HStack(spacing: 12) {
            card("Ingresos · \(month)", formatSignedMoney(income, PEN, positive: true), Palette.income)
            card("Gastos · \(month)", formatSignedMoney(expense, PEN, positive: false), Palette.expense)
        }
    }

    private func card(_ label: String, _ amount: String, _ color: Color) -> some View {
        OrbitaCard {
            Text(label).font(OFont.labelSmall).foregroundStyle(Palette.muted).lineLimit(1)
            Text(amount)
                .font(OFont.titleMedium)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.top, 6)
        }
    }
}

/// Only in v1.1 and when there are pending purchases.
private struct CreditReminderCard: View {
    let onClick: () -> Void

    var body: some View {
        let purchases = SampleData.creditPurchases
        let nextDue = purchases.map(\.dueDate).min() ?? SampleData.today
        OrbitaCard(onClick: onClick) {
            HStack(spacing: 12) {
                IconBadge(systemName: "creditcard", tint: Palette.expense, container: Palette.expenseSoft)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Tarjeta de crédito").font(OFont.titleSmall).foregroundStyle(Palette.ink)
                    Text("\(purchases.count) compras pendientes · vence \(formatDayMonth(nextDue))")
                        .font(OFont.bodySmall)
                        .foregroundStyle(Palette.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.muted)
            }
        }
    }
}

private struct HomeSkeleton: View {
    var body: some View {
        VStack(spacing: 12) {
            SkeletonBlock(height: 190)
            HStack(spacing: 12) {
                SkeletonBlock(height: 78)
                SkeletonBlock(height: 78)
            }
            SkeletonBlock(height: 260)
        }
    }
}

#Preview("Inicio") { HomeView().environment(AppModel()) }
#Preview("Inicio · sin movimientos") { HomeView(state: .empty).environment(AppModel()) }
#Preview("Inicio · cargando") { HomeView(state: .loading).environment(AppModel()) }
#Preview("Inicio · error") { HomeView(state: .error).environment(AppModel()) }
