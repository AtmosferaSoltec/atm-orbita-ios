import Foundation

enum BottomTab: Hashable { case home, accounts, reports, credit }

/// A screen pushed over the tabs. Like on Android, navigation is a back stack of these.
/// Screens that create something close with an X; the others go back with ‹.
enum Route: Hashable {
    case settings
    case movements
    /// `purchase`: a pending purchase with a credit card being edited, instead of a movement.
    case movementForm(editing: Movement? = nil, credit: Bool = false, purchase: CreditPurchase? = nil)
    case transferForm(editing: Transfer? = nil)
    case payCredit(CreditPurchase)
    case creditCardForm(CreditCard?)
    case accountForm(Account?)
    case categories
    case categoryForm(category: Category?, kind: MovementKind)
}

/// The steps of the screens without a session. Recovering the password goes
/// `forgot` → `code` → `newPassword`.
enum AuthStep: Hashable { case login, register, forgot, code, newPassword }

enum ReportMode: Hashable { case month, year, range }

/// What the user picked in Reportes. Only the choice of the active `mode` applies; the others are
/// kept so that switching tabs back and forth does not lose them. There is no data from the
/// future: nothing here goes past `today`.
struct ReportSelection: Equatable {
    var mode: ReportMode
    /// First day of the month of "Mes".
    var month: LocalDay
    var year: Int
    var rangeFrom: LocalDay
    var rangeTo: LocalDay
    var today: LocalDay

    init(today: LocalDay) {
        mode = .month
        month = today.firstOfMonth
        year = today.year
        rangeFrom = today.firstOfMonth
        rangeTo = today
        self.today = today
    }

    var canGoToNextMonth: Bool { month < today.firstOfMonth }
    var canGoToNextYear: Bool { year < today.year }

    /// The dates the report covers; the month and the year in course end today.
    var period: DatePeriod {
        switch mode {
        case .month: untilToday(.ofMonth(month))
        case .year: untilToday(.ofYear(year))
        case .range: DatePeriod(from: rangeFrom, to: rangeTo)
        }
    }

    private func untilToday(_ period: DatePeriod) -> DatePeriod {
        period.to > today ? DatePeriod(from: period.from, to: today) : period
    }
}
