import SwiftUI

/// Inicio: everything it shows comes in one piece from `HomeRepository`.
struct HomeView: View {
    @Environment(AppModel.self) private var app
    @State private var loader = Loader<HomeSummary>()

    var body: some View {
        ScreenScaffold(header: {
            ScreenHeader(title: "Bienvenido", subtitle: "Revisa cómo van tus finanzas") {
                CircleIconButton(systemName: "gearshape", label: "Ajustes") { app.push(.settings) }
            }
        }) {
            switch loader.state {
            case .loading:
                HomeSkeleton()
            case .failed:
                StateMessage(
                    systemImage: "exclamationmark.circle",
                    title: "No se pudo cargar",
                    message: "Revisa tu conexión e inténtalo de nuevo.",
                    actionLabel: "Reintentar",
                    onAction: { loader.retry() }
                )
            case .ready(let home):
                content(home)
            }
        }
        .task(id: [app.revision, loader.attempt]) { await load() }
    }

    private func load() async {
        await loader.run { try await app.env.home.home() }
    }

    @ViewBuilder
    private func content(_ home: HomeSummary) -> some View {
        let empty = home.recentEntries.isEmpty
        SavingsHeroCard(
            home: home,
            onDisplayCurrencyChange: { currency in
                app.perform { try await app.env.settings.setDisplayCurrency(currency) }
            },
            onOpenAccounts: { app.tab = .accounts },
            onConfigureFx: { app.push(.settings) }
        )
        MonthCards(income: home.monthIncome, expense: home.monthExpense, currency: home.fx.main) { kind in
            app.showReports(focus: kind)
        }
        .padding(.top, 12)
        HintText("Las transferencias y las compras de tarjeta pendientes no entran aquí.")
            .padding(.top, 10)
            .padding(.horizontal, 4)
        // Only in v1.1 and when there are pending purchases.
        if let credit = home.credit {
            CreditReminderCard(credit: credit) { app.tab = .credit }.padding(.top, 14)
        }
        SectionTitle(
            text: "Últimos movimientos",
            actionLabel: empty ? nil : "Ver todos",
            onAction: { app.push(.movements) }
        )
        if empty {
            OrbitaCard {
                StateMessage(
                    systemImage: "plus",
                    title: "Registra tu primer movimiento",
                    message: "Toca el botón + para anotar un ingreso o un egreso."
                )
            }
        } else {
            EntryList(entries: home.recentEntries) { app.open($0) }
        }
    }
}

private struct SavingsHeroCard: View {
    let home: HomeSummary
    let onDisplayCurrencyChange: (String) -> Void
    let onOpenAccounts: () -> Void
    let onConfigureFx: () -> Void

    var body: some View {
        let fx = home.fx
        let displayCurrency = home.displayCurrency
        let otherCurrency = fx.other(displayCurrency)
        let total = home.savings[displayCurrency] ?? 0
        HeroCard(scrim: true) {
            HStack {
                HeroLabel("Ahorro total").frame(maxWidth: .infinity, alignment: .leading)
                SegmentedControl(
                    options: [fx.main, fx.secondary].map { ($0, currencySymbol($0)) },
                    selected: displayCurrency,
                    // Without an exchange rate the total can only be seen in the main currency.
                    onSelect: { if fx.rate != nil { onDisplayCurrencyChange($0) } },
                    fill: false,
                    onHero: true
                )
            }
            Text(formatMoney(total, displayCurrency))
                .font(OFont.custom(42))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.top, 16)
            Group {
                if let rate = fx.rate {
                    // Plain supporting line: the same total in the other currency.
                    Text("o \(formatMoney(home.savings[otherCurrency] ?? 0, otherCurrency)) · cambio \(formatRate(rate)) (manual)")
                        .font(OFont.bodyMedium)
                        .foregroundStyle(Color.white.opacity(0.85))
                        .lineLimit(1)
                } else {
                    // A new user has no exchange rate yet: the line leads to where it is set.
                    Button(action: onConfigureFx) {
                        Text("Configura tu tipo de cambio ›")
                            .font(OFont.bodyMedium)
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 4)
            Button(action: onOpenAccounts) {
                HStack(spacing: 10) {
                    Image(systemName: "wallet.bifold").font(.system(size: 16, weight: .medium))
                    Text("\(home.includedAccounts) de \(home.activeAccounts) cuentas incluidas")
                        .font(OFont.bodyMedium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Elegir").font(OFont.labelLarge)
                    Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(heroGlass, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 18)
        }
    }
}

private struct MonthCards: View {
    @Environment(AppModel.self) private var app
    let income: Decimal
    let expense: Decimal
    let currency: String
    let onOpenReport: (MovementKind) -> Void

    var body: some View {
        let name = monthName(app.today)
        let month = name.prefix(1).uppercased() + name.dropFirst()
        VStack(spacing: 10) {
            MonthCard(
                systemName: "chart.line.uptrend.xyaxis", label: "Ingresos", month: month,
                amount: formatSignedMoney(income, currency, positive: true),
                color: Palette.income, container: Palette.incomeSoft
            ) { onOpenReport(.income) }
            MonthCard(
                systemName: "chart.line.downtrend.xyaxis", label: "Gastos", month: month,
                amount: formatSignedMoney(expense, currency, positive: false),
                color: Palette.expense, container: Palette.expenseSoft
            ) { onOpenReport(.expense) }
        }
    }
}

/// Opens the report of the current month; the month reads lighter than the label.
private struct MonthCard: View {
    let systemName: String
    let label: String
    let month: String
    let amount: String
    let color: Color
    let container: Color
    let onClick: () -> Void

    var body: some View {
        OrbitaCard(onClick: onClick) {
            HStack(spacing: 14) {
                IconBadge(systemName: systemName, tint: color, container: container)
                VStack(alignment: .leading, spacing: 2) {
                    (Text(label).foregroundStyle(Palette.muted) + Text(" · \(month)").foregroundStyle(Palette.mutedLight))
                        .font(OFont.labelLarge)
                        .lineLimit(1)
                    Text(amount).font(OFont.titleLarge).foregroundStyle(color).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.mutedLight)
            }
        }
    }
}

private struct CreditReminderCard: View {
    let credit: CreditReminder
    let onClick: () -> Void

    var body: some View {
        OrbitaCard(onClick: onClick) {
            HStack(spacing: 12) {
                IconBadge(systemName: "creditcard", tint: Palette.orange, container: Palette.orangeSoft)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Tarjetas de Crédito").font(OFont.titleSmall).foregroundStyle(Palette.ink)
                    Text(pendingPaymentsLabel(credit.pendingCount, due: credit.nextDueDate))
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
