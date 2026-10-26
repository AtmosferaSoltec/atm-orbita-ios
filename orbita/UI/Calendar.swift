import SwiftUI

// The app's own calendar (not the system DatePicker), so it looks and behaves the same as on
// Android: ORBITA_SPEC section 5, "Calendario".

private enum CalendarView { case days, months }

/// How the soft band of a range crosses a day cell.
private enum RangeBand { case none, start, middle, end }

private let dayCellHeight: CGFloat = 44
private let dayCircle: CGFloat = 40
private let weekdayRowHeight: CGFloat = 28

// Six weeks, so the dialog keeps its height from month to month.
private let calendarBodyHeight = weekdayRowHeight + dayCellHeight * 6

extension View {
    /// Calendar to pick a start and an end date together. "Aceptar" needs both. Days after
    /// `today` cannot be picked unless `allowFuture` (there is no data from the future).
    func dateRangeDialog(
        isPresented: Binding<Bool>, title: String, from: LocalDay, to: LocalDay, today: LocalDay,
        allowFuture: Bool = false, onConfirm: @escaping (LocalDay, LocalDay) -> Void
    ) -> some View {
        fullScreenCover(isPresented: isPresented) {
            RangeDialogContent(
                title: title, from: from, to: to, today: today, allowFuture: allowFuture,
                onConfirm: onConfirm, onDismiss: { isPresented.wrappedValue = false }
            )
            .presentationBackground(Color.black.opacity(0.4))
        }
    }

    /// Calendar to pick a single date. Days after `today` cannot be picked unless `allowFuture`.
    func dateDialog(
        isPresented: Binding<Bool>, title: String, date: LocalDay, today: LocalDay,
        allowFuture: Bool = false, onConfirm: @escaping (LocalDay) -> Void
    ) -> some View {
        fullScreenCover(isPresented: isPresented) {
            SingleDialogContent(
                title: title, date: date, today: today, allowFuture: allowFuture,
                onConfirm: onConfirm, onDismiss: { isPresented.wrappedValue = false }
            )
            .presentationBackground(Color.black.opacity(0.4))
        }
    }
}

private struct RangeDialogContent: View {
    let title: String
    let from: LocalDay
    let to: LocalDay
    let today: LocalDay
    let allowFuture: Bool
    let onConfirm: (LocalDay, LocalDay) -> Void
    let onDismiss: () -> Void

    @State private var start: LocalDay?
    @State private var end: LocalDay?

    init(
        title: String, from: LocalDay, to: LocalDay, today: LocalDay, allowFuture: Bool,
        onConfirm: @escaping (LocalDay, LocalDay) -> Void, onDismiss: @escaping () -> Void
    ) {
        self.title = title
        self.from = from
        self.to = to
        self.today = today
        self.allowFuture = allowFuture
        self.onConfirm = onConfirm
        self.onDismiss = onDismiss
        _start = State(initialValue: from)
        _end = State(initialValue: to)
    }

    private var headline: String {
        let startText: String
        if let start {
            startText = (end != nil && start.year == end!.year) ? formatDayMonth(start) : formatDate(start)
        } else {
            startText = "Desde"
        }
        return "\(startText) – \(end.map(formatDate) ?? "Hasta")"
    }

    var body: some View {
        CalendarDialog(
            title: title, headline: headline, initialMonth: to, today: today, allowFuture: allowFuture,
            start: start, end: end,
            onDayClick: { day in
                if let s = start, end == nil {
                    // The second tap closes the range; one before the start becomes the new start.
                    if day < s { start = day } else { end = day }
                } else {
                    // A complete range starts over.
                    start = day
                    end = nil
                }
            },
            canConfirm: start != nil && end != nil,
            onConfirm: {
                if let start, let end {
                    onConfirm(start, end)
                    onDismiss()
                }
            },
            onDismiss: onDismiss
        )
    }
}

private struct SingleDialogContent: View {
    let title: String
    let today: LocalDay
    let allowFuture: Bool
    let initialDate: LocalDay
    let onConfirm: (LocalDay) -> Void
    let onDismiss: () -> Void

    @State private var selected: LocalDay

    init(
        title: String, date: LocalDay, today: LocalDay, allowFuture: Bool,
        onConfirm: @escaping (LocalDay) -> Void, onDismiss: @escaping () -> Void
    ) {
        self.title = title
        self.today = today
        self.allowFuture = allowFuture
        initialDate = date
        self.onConfirm = onConfirm
        self.onDismiss = onDismiss
        _selected = State(initialValue: date)
    }

    var body: some View {
        CalendarDialog(
            title: title, headline: formatDate(selected), initialMonth: initialDate, today: today,
            allowFuture: allowFuture, start: selected, end: selected,
            onDayClick: { selected = $0 }, canConfirm: true,
            onConfirm: {
                onConfirm(selected)
                onDismiss()
            },
            onDismiss: onDismiss
        )
    }
}

private struct CalendarDialog: View {
    let title: String
    let headline: String
    let initialMonth: LocalDay
    let today: LocalDay
    let allowFuture: Bool
    let start: LocalDay?
    let end: LocalDay?
    let onDayClick: (LocalDay) -> Void
    let canConfirm: Bool
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(OFont.labelMedium).foregroundStyle(Palette.muted)
            Text(headline)
                .font(OFont.titleLarge)
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.top, 2)
            CalendarPanel(
                initialMonth: initialMonth, today: today, allowFuture: allowFuture,
                start: start, end: end, onDayClick: onDayClick
            )
            .padding(.top, 14)
            HStack(spacing: 12) {
                PillButton(title: "Cancelar", container: Palette.neutralSoft, content: Palette.neutral, fill: true, action: onDismiss)
                PillButton(
                    title: "Aceptar",
                    container: canConfirm ? Palette.primary : Palette.neutralSoft,
                    content: canConfirm ? .white : Palette.mutedLight,
                    fill: true,
                    action: { if canConfirm { onConfirm() } }
                )
            }
            .padding(.top, 16)
        }
        .padding(20)
        .frame(maxWidth: 400)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.heroCard, style: .continuous))
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Month grid with its navigation. The arrows step one month; tapping the month-year opens the
/// grid of months, where the arrows step one year.
private struct CalendarPanel: View {
    let initialMonth: LocalDay
    let today: LocalDay
    let allowFuture: Bool
    let start: LocalDay?
    let end: LocalDay?
    let onDayClick: (LocalDay) -> Void

    @State private var month: LocalDay
    @State private var view = CalendarView.days

    init(
        initialMonth: LocalDay, today: LocalDay, allowFuture: Bool, start: LocalDay?, end: LocalDay?,
        onDayClick: @escaping (LocalDay) -> Void
    ) {
        self.initialMonth = initialMonth
        self.today = today
        self.allowFuture = allowFuture
        self.start = start
        self.end = end
        self.onDayClick = onDayClick
        _month = State(initialValue: initialMonth.firstOfMonth)
    }

    private var lastMonth: LocalDay? { allowFuture ? nil : today.firstOfMonth }
    private var picksMonths: Bool { view == .months }

    private var canGoNext: Bool {
        guard let lastMonth else { return true }
        return picksMonths ? month.year < lastMonth.year : month < lastMonth
    }

    private func goTo(_ target: LocalDay) {
        if let lastMonth, target > lastMonth { month = lastMonth } else { month = target }
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                CircleIconButton(
                    systemName: "chevron.left", label: picksMonths ? "Año anterior" : "Mes anterior",
                    container: Palette.background,
                    action: { goTo(picksMonths ? month.adding(months: -12) : month.adding(months: -1)) }
                )
                Button {
                    view = picksMonths ? .days : .months
                } label: {
                    HStack(spacing: 6) {
                        Text(picksMonths ? String(month.year) : formatMonthYear(month))
                            .font(OFont.titleSmall)
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Palette.muted)
                            .rotationEffect(.degrees(picksMonths ? 180 : 0))
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Elegir mes y año")
                CircleIconButton(
                    systemName: "chevron.right", label: picksMonths ? "Año siguiente" : "Mes siguiente",
                    container: Palette.background,
                    enabled: canGoNext,
                    action: { goTo(picksMonths ? month.adding(months: 12) : month.adding(months: 1)) }
                )
            }
            if picksMonths {
                MonthGrid(month: month, lastMonth: lastMonth) { picked in
                    month = picked
                    view = .days
                }
            } else {
                DayGrid(
                    month: month, today: today, lastDay: allowFuture ? nil : today,
                    start: start, end: end, onDayClick: onDayClick
                )
                // Swiping sideways also changes the month.
                .gesture(
                    DragGesture(minimumDistance: 24).onEnded { value in
                        if value.translation.width > 48 {
                            goTo(month.adding(months: -1))
                        } else if value.translation.width < -48, canGoNext {
                            goTo(month.adding(months: 1))
                        }
                    }
                )
            }
        }
    }
}

private struct DayGrid: View {
    let month: LocalDay
    let today: LocalDay
    let lastDay: LocalDay?
    let start: LocalDay?
    let end: LocalDay?
    let onDayClick: (LocalDay) -> Void

    private var isRange: Bool { start != nil && end != nil && start != end }

    var body: some View {
        // Weeks start on Sunday.
        let leadingBlanks = month.weekdayIndex
        let days = month.lengthOfMonth
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array(weekdayInitials.enumerated()), id: \.offset) { _, initial in
                    Text(initial)
                        .font(OFont.labelSmall)
                        .foregroundStyle(Palette.mutedLight)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: weekdayRowHeight)
            ForEach(0..<6, id: \.self) { week in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { column in
                        let number = week * 7 + column - leadingBlanks + 1
                        if number < 1 || number > days {
                            Color.clear.frame(maxWidth: .infinity).frame(height: dayCellHeight)
                        } else {
                            let day = LocalDay(month.year, month.month, number)
                            DayCell(
                                number: number,
                                selected: day == start || day == end,
                                band: band(for: day),
                                roundLeft: column == 0 || number == 1,
                                roundRight: column == 6 || number == days,
                                isToday: day == today,
                                enabled: lastDay.map { day <= $0 } ?? true,
                                onClick: { onDayClick(day) }
                            )
                        }
                    }
                }
            }
        }
        .frame(height: calendarBodyHeight)
    }

    private func band(for day: LocalDay) -> RangeBand {
        guard isRange, let start, let end else { return .none }
        if day == start { return .start }
        if day == end { return .end }
        return day > start && day < end ? .middle : .none
    }
}

private struct DayCell: View {
    let number: Int
    let selected: Bool
    let band: RangeBand
    let roundLeft: Bool
    let roundRight: Bool
    let isToday: Bool
    let enabled: Bool
    let onClick: () -> Void

    var body: some View {
        ZStack {
            if band != .none {
                Canvas { context, size in
                    let bandHeight = dayCircle
                    // The ends only carry the half of the band that faces the range.
                    let left: CGFloat = band == .start ? size.width / 2 : 0
                    let right: CGFloat = band == .end ? size.width / 2 : size.width
                    let top = (size.height - bandHeight) / 2
                    // Where the band meets the edge of the week or of the month it ends rounded:
                    // a pill for the whole cell, squared again on the side that continues.
                    let half = size.width / 2
                    let squareLeft = roundLeft ? half : left
                    let squareRight = roundRight ? half : right
                    if roundLeft || roundRight {
                        let rect = CGRect(x: left, y: top, width: right - left, height: bandHeight)
                        context.fill(Path(roundedRect: rect, cornerRadius: bandHeight / 2), with: .color(Palette.primarySoft))
                    }
                    if squareRight > squareLeft {
                        let rect = CGRect(x: squareLeft, y: top, width: squareRight - squareLeft, height: bandHeight)
                        context.fill(Path(rect), with: .color(Palette.primarySoft))
                    }
                }
            }
            Button(action: onClick) {
                Text(String(number))
                    .font(selected || isToday ? OFont.labelLarge : OFont.bodyMedium)
                    .foregroundStyle(textColor)
                    .frame(width: dayCircle, height: dayCircle)
                    .background(selected ? Palette.primary : Color.clear, in: Circle())
                    .overlay(
                        Circle().strokeBorder(Palette.primary, lineWidth: isToday && !selected ? 1.5 : 0)
                    )
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!enabled)
        }
        .frame(maxWidth: .infinity)
        .frame(height: dayCellHeight)
    }

    private var textColor: Color {
        if selected { return .white }
        if !enabled { return Palette.mutedLight.opacity(0.45) }
        if isToday || band != .none { return Palette.primary }
        return Palette.ink
    }
}

/// The twelve months of the year of `month`; the ones after `lastMonth` cannot be picked.
private struct MonthGrid: View {
    let month: LocalDay
    let lastMonth: LocalDay?
    let onPick: (LocalDay) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { column in
                        let option = LocalDay(month.year, row * 3 + column + 1, 1)
                        let selected = option == month
                        let enabled = lastMonth.map { option <= $0 } ?? true
                        Button { onPick(option) } label: {
                            Text(monthShortName(option.month).prefix(1).uppercased() + monthShortName(option.month).dropFirst())
                                .font(OFont.labelLarge)
                                .foregroundStyle(selected ? Color.white : (enabled ? Palette.ink : Palette.mutedLight.opacity(0.45)))
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(selected ? Palette.primary : Palette.background, in: RoundedRectangle(cornerRadius: Radius.pill, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(!enabled)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .frame(height: calendarBodyHeight)
    }
}
