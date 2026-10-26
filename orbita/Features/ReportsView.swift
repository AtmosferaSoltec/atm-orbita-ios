import SwiftUI

private enum ReportMode { case month, range }

struct ReportsView: View {
    @State private var mode = ReportMode.month
    @State private var month = SampleData.reportMonth

    var body: some View {
        // The sample data only covers September 2026.
        let hasData = mode == .range || month == SampleData.reportMonth

        ScreenScaffold {
            ScreenHeader(title: "Reportes") {
                // Visible but inactive: PDF export comes later.
                StatusChip(
                    text: "PDF · próximamente", container: Palette.neutralSoft,
                    content: Palette.neutral, systemImage: "doc"
                )
            }
        } content: {
            SegmentedControl(
                options: [(ReportMode.month, "Por mes"), (ReportMode.range, "Rango de fechas")],
                selected: mode,
                onSelect: { mode = $0 }
            )

            Group {
                if mode == .month {
                    MonthSelector(
                        month: month,
                        onPrevious: { month = Cal.adding(months: -1, to: month) },
                        onNext: { month = Cal.adding(months: 1, to: month) }
                    )
                } else {
                    RangeSelector(from: SampleData.reportMonth, to: Cal.date(2026, 9, 30))
                }
            }
            .padding(.top, 12)

            if !hasData {
                StateMessage(systemImage: "chart.bar", title: "No hay movimientos en este periodo")
            } else {
                let income = SampleData.reportIncomes.total()
                let expense = SampleData.reportExpenses.total()
                let balance = income - expense
                OrbitaCard {
                    HStack(alignment: .top) {
                        SummaryColumn(label: "Ingresos", amount: formatMoney(income, PEN), color: Palette.income)
                        SummaryColumn(label: "Gastos", amount: formatMoney(expense, PEN), color: Palette.expense)
                    }
                    CardDivider()
                    LabelValueRow(
                        label: "Balance del periodo",
                        value: formatSignedMoney(balance, PEN, positive: !balance.isNegative),
                        valueColor: balance.isNegative ? Palette.expense : Palette.income,
                        valueFont: OFont.titleMedium
                    )
                }
                .padding(.top, 12)

                SectionTitle(text: "Dónde gastas más")
                CategoryRanking(items: SampleData.reportExpenses)

                SectionTitle(text: "Tus fuentes de ingreso")
                CategoryRanking(items: SampleData.reportIncomes)

                HintText("Las compras con tarjeta aparecen aquí solo cuando las marcas como pagadas. Las transferencias entre tus cuentas no cuentan como ingreso ni gasto.")
                    .padding(.top, 14)
                    .padding(.horizontal, 4)
            }
        }
    }
}

private struct MonthSelector: View {
    let month: Date
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        OrbitaCard(padding: .all(10)) {
            HStack(spacing: 10) {
                CircleIconButton(
                    systemName: "chevron.left", label: "Mes anterior",
                    container: Palette.background, action: onPrevious
                )
                IconBadge(systemName: "calendar", tint: Palette.primary, container: Palette.primarySoft, size: 40)
                VStack(alignment: .leading, spacing: 0) {
                    Text(formatMonthYear(month)).font(OFont.titleSmall).foregroundStyle(Palette.ink).lineLimit(1)
                    Text("1 – \(formatDayMonth(Cal.lastOfMonth(month)))")
                        .font(OFont.bodySmall)
                        .foregroundStyle(Palette.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                CircleIconButton(
                    systemName: "chevron.right", label: "Mes siguiente",
                    container: Palette.background, action: onNext
                )
            }
        }
    }
}

private struct RangeSelector: View {
    let from: Date
    let to: Date

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                FieldLabel("Desde")
                PickerField(value: formatDate(from))
            }
            VStack(alignment: .leading, spacing: 0) {
                FieldLabel("Hasta")
                PickerField(value: formatDate(to))
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
            Text(amount).font(OFont.titleLarge).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Horizontal bars: width = share of the currency total, largest first, category color.
private struct CategoryRanking: View {
    let items: [MockCategoryTotal]

    var body: some View {
        let total = items.total()
        OrbitaCard {
            VStack(spacing: 14) {
                ForEach(items.sorted { $0.total > $1.total }) { item in
                    let percent = percentOf(item.total, total)
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            ColorDot(color: item.category.color, size: 10)
                            Text(item.category.name)
                                .font(OFont.titleSmall)
                                .foregroundStyle(Palette.ink)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(formatMoney(item.total, PEN)) · \(formatPercent(percent))%")
                                .font(OFont.labelMedium)
                                .foregroundStyle(Palette.muted)
                        }
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Palette.neutralSoft)
                                Capsule()
                                    .fill(item.category.color)
                                    .frame(width: proxy.size.width * CGFloat(truncating: (percent / 100) as NSDecimalNumber))
                            }
                        }
                        .frame(height: 8)
                    }
                }
            }
        }
    }
}

#Preview("Reportes") { ReportsView() }
