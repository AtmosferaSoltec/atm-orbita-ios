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

/// Initials of the days of the week, Sunday first.
let weekdayInitials = ["D", "L", "M", "M", "J", "V", "S"]

/// A currency the user can pick: ISO 4217 code, symbol shown next to amounts, Spanish name.
struct CurrencyInfo: Hashable, Identifiable {
    let code: String
    let symbol: String
    let name: String

    var id: String { code }

    /// `Soles (S/)`
    var label: String { "\(name) (\(symbol))" }
}

let supportedCurrencies = [
    CurrencyInfo(code: PEN, symbol: "S/", name: "Soles"),
    CurrencyInfo(code: USD, symbol: "US$", name: "Dólares"),
    CurrencyInfo(code: "EUR", symbol: "€", name: "Euros"),
    CurrencyInfo(code: "MXN", symbol: "MX$", name: "Pesos mexicanos"),
    CurrencyInfo(code: "COP", symbol: "COL$", name: "Pesos colombianos"),
    CurrencyInfo(code: "CLP", symbol: "CLP$", name: "Pesos chilenos"),
    CurrencyInfo(code: "ARS", symbol: "AR$", name: "Pesos argentinos"),
    CurrencyInfo(code: "BOB", symbol: "Bs", name: "Bolivianos"),
    CurrencyInfo(code: "BRL", symbol: "R$", name: "Reales"),
]

func currencyInfo(_ code: String) -> CurrencyInfo {
    supportedCurrencies.first { $0.code == code } ?? CurrencyInfo(code: code, symbol: code, name: code)
}

func currencySymbol(_ currency: String) -> String { currencyInfo(currency).symbol }

/// The currency offered on sign-up: the one of the phone's region when the app supports it,
/// soles otherwise.
func defaultCurrencyFor(_ locale: Locale = .current) -> String {
    let regional = locale.currency?.identifier
    return supportedCurrencies.first { $0.code == regional }?.code ?? PEN
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

/// Exact decimal from text; never build money from floating-point literals.
func D(_ text: String) -> Decimal { Decimal(string: text, locale: Locale(identifier: "en_US"))! }

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

/// Rate as typed in a field: up to 6 decimals, no trailing zeros beyond 2.
func plainRate(_ rate: Decimal) -> String {
    formatDecimal(rate, minFraction: 2, maxFraction: 6, grouping: false)
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

/// Keeps what can be part of an amount typed with the system keyboard: digits and one separator,
/// with at most [maxDecimals] after it.
func sanitizeDecimalInput(_ text: String, maxDecimals: Int) -> String {
    var result = ""
    var decimals: Int?
    for character in text {
        if character.isASCII, character.isNumber {
            if let count = decimals {
                if count >= maxDecimals { continue }
                decimals = count + 1
            }
            result.append(character)
        } else if (character == "." || character == ","), decimals == nil {
            decimals = 0
            result.append(character)
        }
    }
    return result
}

/// Share of [part] over [whole] as a percentage with one decimal (half up).
func percentOf(_ part: Decimal, _ whole: Decimal) -> Decimal {
    whole == 0 ? 0 : (part * 100 / whole).rounded(scale: 1)
}

// MARK: - Dates

/// `2 oct 2026`
func formatDate(_ day: LocalDay) -> String {
    "\(day.day) \(monthsShort[day.month - 1]) \(day.year)"
}

/// `2 oct`
func formatDayMonth(_ day: LocalDay) -> String {
    "\(day.day) \(monthsShort[day.month - 1])"
}

/// `oct`, for [month] 1–12.
func monthShortName(_ month: Int) -> String { monthsShort[month - 1] }

/// `octubre`
func monthName(_ day: LocalDay) -> String { monthsLong[day.month - 1] }

/// `Septiembre 2026`
func formatMonthYear(_ day: LocalDay) -> String {
    let name = monthName(day)
    return "\(name.prefix(1).uppercased())\(name.dropFirst()) \(day.year)"
}
