import SwiftUI

/// Incomes and expenses of a month, a year or a range of dates. `app.reportFocus` is set when
/// coming from a month card of Inicio: the ranking of that kind goes first.
struct ReportsView: View {
    @Environment(AppModel.self) private var app
    @State private var loader = Loader<[CurrencyReport]>()
    @State private var pickingRange = false

    var body: some View {
        let selection = app.reportSelection
        ScreenScaffold(header: {
            ScreenHeader(title: "Reportes") {
                // Visible but inactive: PDF export comes later.
                StatusChip(text: "PDF · próximamente", container: Palette.neutralSoft, content: Palette.neutral, systemImage: "doc")
            }
        }) {
            SegmentedControl(
                options: [(ReportMode.month, "Mes"), (.year, "Año"), (.range, "Rango")],
                selected: selection.mode,
                onSelect: { app.reportSelection.mode = $0 }
            )
            Color.clear.frame(height: 12)

            switch selection.mode {
            case .month:
                MonthSelector(
                    month: selection.month,
                    onPrevious: { app.reportSelection.month = selection.month.adding(months: -1) },
                    onNext: {
                        if selection.canGoToNextMonth { app.reportSelection.month = selection.month.adding(months: 1) }
                    },
                    // There is no data from the future: the current month is the last one.
                    canGoNext: selection.canGoToNextMonth
                )
            case .year:
                YearSelector(
                    year: selection.year, today: selection.today,
                    onPrevious: { app.reportSelection.year = selection.year - 1 },
                    onNext: { if selection.canGoToNextYear { app.reportSelection.year = selection.year + 1 } },
                    canGoNext: selection.canGoToNextYear
                )
            case .range:
                RangeSelector(from: selection.rangeFrom, to: selection.rangeTo) { pickingRange = true }
            }
            Color.clear.frame(height: 12)

            switch loader.state {
            case .loading:
                ReportSkeleton()
            case .failed:
                StateMessage(
                    systemImage: "exclamationmark.circle",
                    title: "No se pudo cargar",
                    message: "Revisa tu conexión e inténtalo de nuevo.",
                    actionLabel: "Reintentar",
                    onAction: { loader.retry() }
                )
            case .ready(let reports):
                if reports.isEmpty {
                    StateMessage(systemImage: "chart.bar", title: "No hay movimientos en este periodo")
                } else {
                    // Currencies are never mixed: one block per currency, the main one first.
                    let severalCurrencies = reports.count > 1
                    ForEach(reports) { report in
                        if severalCurrencies { SectionTitle(text: currencyInfo(report.currency).label) }
                        CurrencyReportBlock(report: report, focus: app.reportFocus)
                    }
                    HintText("Las compras con tarjeta aparecen aquí solo cuando las marcas como pagadas. Las transferencias entre tus cuentas no cuentan como ingreso ni gasto.")
                        .padding(.top, 14)
                        .padding(.horizontal, 4)
                }
            }
        }
        .dateRangeDialog(
            isPresented: $pickingRange, title: "Elige el rango de fechas",
            from: selection.rangeFrom, to: selection.rangeTo, today: selection.today
        ) { from, to in
            app.reportSelection.rangeFrom = from
            app.reportSelection.rangeTo = min(to, selection.today)
        }
        // The same period is read again after any write, and when the choice changes.
        .task(id: TaskKey(revision: app.revision, period: selection.period, attempt: loader.attempt)) {
            let period = selection.period
            await loader.run { try await app.env.reports.report(for: period) }
        }
    }
}

private struct TaskKey: Hashable {
    let revision: Int
    let period: DatePeriod
    let attempt: Int
}

private struct CurrencyReportBlock: View {
    let report: CurrencyReport
    let focus: MovementKind?

    var body: some View {
        let balance = report.balance
        OrbitaCard {
            HStack(alignment: .top) {
                SummaryColumn(label: "Ingresos", amount: formatMoney(report.incomeTotal, report.currency), color: Palette.income)
                SummaryColumn(label: "Gastos", amount: formatMoney(report.expenseTotal, report.currency), color: Palette.expense)
            }
            CardDivider()
            LabelValueRow(
                label: "Balance del periodo",
                value: formatSignedMoney(balance, report.currency, positive: balance >= 0),
                valueColor: balance >= 0 ? Palette.income : Palette.expense,
                valueFont: OFont.titleMedium
            )
        }

        // A period can have only incomes or only expenses: the empty ranking is left out.
        if focus == .income {
            incomeRanking
            expenseRanking
        } else {
            expenseRanking
            incomeRanking
        }
    }

    @ViewBuilder
    private var expenseRanking: some View {
        if !report.expenses.isEmpty {
            SectionTitle(text: "Dónde gastas más")
            CategoryRanking(items: report.expenses, currency: report.currency)
        }
    }

    @ViewBuilder
    private var incomeRanking: some View {
        if !report.incomes.isEmpty {
            SectionTitle(text: "Tus fuentes de ingreso")
            CategoryRanking(items: report.incomes, currency: report.currency)
        }
    }
}

/// Year stepper, the twin of `MonthSelector`. The year in course ends today.
private struct YearSelector: View {
    let year: Int
    let today: LocalDay
    let onPrevious: () -> Void
    let onNext: () -> Void
    let canGoNext: Bool

    var body: some View {
        let firstDay = LocalDay(year, 1, 1)
        let lastDay = LocalDay(year, 12, 31)
        OrbitaCard(padding: .all(10)) {
            HStack(spacing: 0) {
                CircleIconButton(systemName: "chevron.left", label: "Año anterior", container: Palette.background, action: onPrevious)
                VStack(spacing: 0) {
                    Text(String(year)).font(OFont.titleSmall).foregroundStyle(Palette.ink).lineLimit(1)
                    Text(year == today.year
                        ? "\(formatDayMonth(firstDay)) – hoy"
                        : "\(formatDayMonth(firstDay)) – \(formatDayMonth(lastDay))")
                        .font(OFont.bodySmall)
                        .foregroundStyle(Palette.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 10)
                CircleIconButton(
                    systemName: "chevron.right", label: "Año siguiente", container: Palette.background,
                    enabled: canGoNext, action: onNext
                )
            }
        }
    }
}

private struct ReportSkeleton: View {
    var body: some View {
        VStack(spacing: 12) {
            SkeletonBlock(height: 120)
            SkeletonBlock(height: 260)
        }
    }
}

private struct RangeSelector: View {
    let from: LocalDay
    let to: LocalDay
    let onClick: () -> Void

    var body: some View {
        // Both fields open the same calendar, where the start and the end are picked together.
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                FieldLabel("Desde")
                PickerField(value: formatDate(from), action: onClick)
            }
            VStack(alignment: .leading, spacing: 0) {
                FieldLabel("Hasta")
                PickerField(value: formatDate(to), action: onClick)
            }
        }
    }
}

private struct SummaryColumn: View {
    let label: String
    let amount: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(OFont.labelMedium).foregroundStyle(Palette.muted)
            Text(amount).font(OFont.titleLarge).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Horizontal bars: width = share of the currency total, largest first, category color.
private struct CategoryRanking: View {
    let items: [CategoryTotal]
    let currency: String

    var body: some View {
        let total = items.total()
        OrbitaCard {
            VStack(spacing: 14) {
                ForEach(items.sorted { $0.total > $1.total }) { item in
                    let percent = percentOf(item.total, total)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            ColorDot(color: item.category.color, size: 10)
                            Text(item.category.name)
                                .font(OFont.titleSmall)
                                .foregroundStyle(Palette.ink)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(formatMoney(item.total, currency)) · \(formatPercent(percent))%")
                                .font(OFont.labelMedium)
                                .foregroundStyle(Palette.muted)
                        }
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Palette.neutralSoft)
                                Capsule()
                                    .fill(item.category.color)
                                    .frame(width: proxy.size.width * CGFloat(NSDecimalNumber(decimal: percent).doubleValue) / 100)
                            }
                        }
                        .frame(height: 8)
                    }
                }
            }
        }
    }
}
