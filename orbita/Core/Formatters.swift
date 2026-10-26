import Foundation

// Formats and calculations from ORBITA_SPEC sections 4 and 9. Money is always `Decimal`.

let PEN = "PEN"
let USD = "USD"
let minusSign = "−"

private let monthsShort = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]
private let monthsLong = [
    "enero", "febrero", "marzo", "abril", "mayo", "junio",
    "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre",
]

func currencySymbol(_ currency: String) -> String {
    switch currency {
    case PEN: return "S/"
    case USD: return "US$"
    default: return currency
    }
}

extension Decimal {
    /// Rounds half up (away from zero on ties) to [scale] decimals.
    func rounded(scale: Int) -> Decimal {
        var value = self
        var result = Decimal()
        NSDecimalRound(&result, &value, scale, .plain)
        return result
    }

    var isPositive: Bool { self > 0 }
    var isNegative: Bool { self < 0 }
    var magnitude: Decimal { self < 0 ? -self : self }
}

private func formatDecimal(_ value: Decimal, minFraction: Int, maxFraction: Int, grouping: Bool) -> String {
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: "en_US")
    formatter.numberStyle = .decimal
    formatter.minimumFractionDigits = minFraction
    formatter.maximumFractionDigits = maxFraction
    formatter.usesGroupingSeparator = grouping
    formatter.roundingMode = .halfUp
    return formatter.string(from: value as NSDecimalNumber) ?? ""
}

/// `1245.8` -> `1,245.80`
func formatAmount(_ amount: Decimal) -> String {
    formatDecimal(amount.rounded(scale: 2), minFraction: 2, maxFraction: 2, grouping: true)
}

/// `1245.8`, `PEN` -> `S/ 1,245.80`
func formatMoney(_ amount: Decimal, _ currency: String) -> String {
    "\(currencySymbol(currency)) \(formatAmount(amount))"
}

/// Signed amount for incomes (`+`) and expenses (U+2212).
func formatSignedMoney(_ amount: Decimal, _ currency: String, positive: Bool) -> String {
    (positive ? "+" : minusSign) + formatMoney(amount.magnitude, currency)
}

/// Exchange rates are shown with 2 to 4 decimals.
func formatRate(_ rate: Decimal) -> String {
    formatDecimal(rate, minFraction: 2, maxFraction: 4, grouping: false)
}

/// Plain text for editable fields: `64` -> `64.00`.
func plainAmount(_ amount: Decimal) -> String {
    formatDecimal(amount.rounded(scale: 2), minFraction: 2, maxFraction: 2, grouping: false)
}

/// Percentage with one decimal: `37.2`.
func formatPercent(_ value: Decimal) -> String {
    formatDecimal(value, minFraction: 1, maxFraction: 1, grouping: false)
}

/// Accepts `.` or `,` as separator. Returns nil if it is not a number.
func parseDecimal(_ text: String) -> Decimal? {
    let normalized = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
    guard !normalized.isEmpty else { return nil }
    return Decimal(string: normalized, locale: Locale(identifier: "en_US"))
}

func parsePositiveDecimal(_ text: String) -> Decimal? {
    parseDecimal(text).flatMap { $0 > 0 ? $0 : nil }
}

// MARK: - Dates

enum Cal {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    static func day(_ date: Date) -> Int { calendar.component(.day, from: date) }
    static func month(_ date: Date) -> Int { calendar.component(.month, from: date) }
    static func year(_ date: Date) -> Int { calendar.component(.year, from: date) }

    static func firstOfMonth(_ date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
    }

    static func lastOfMonth(_ date: Date) -> Date {
        let first = firstOfMonth(date)
        let next = calendar.date(byAdding: .month, value: 1, to: first)!
        return calendar.date(byAdding: .day, value: -1, to: next)!
    }

    static func adding(months: Int, to date: Date) -> Date {
        calendar.date(byAdding: .month, value: months, to: date)!
    }

    static func adding(days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: date)!
    }

    static func days(from: Date, to: Date) -> Int {
        calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }
}

/// `2 oct 2026`
func formatDate(_ date: Date) -> String {
    "\(Cal.day(date)) \(monthsShort[Cal.month(date) - 1]) \(Cal.year(date))"
}

/// `2 oct`
func formatDayMonth(_ date: Date) -> String {
    "\(Cal.day(date)) \(monthsShort[Cal.month(date) - 1])"
}

/// `octubre`
func monthName(_ date: Date) -> String { monthsLong[Cal.month(date) - 1] }

/// `Septiembre 2026`
func formatMonthYear(_ date: Date) -> String {
    let name = monthName(date)
    return "\(name.prefix(1).uppercased())\(name.dropFirst()) \(Cal.year(date))"
}
