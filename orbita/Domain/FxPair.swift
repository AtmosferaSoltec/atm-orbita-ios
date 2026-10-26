import Foundation

/// The user's two currencies (Ajustes) and the manual rate between them:
/// `rate` = units of `main` per 1 unit of `secondary` (1 US$ = S/ 3.20).
///
/// `rate` is nil until the user sets it: a new user has none, and no value is ever made up.
/// Without it there is no conversion and nothing can be in a currency other than `main`.
struct FxPair: Hashable {
    var main: String
    var secondary: String
    var rate: Decimal?

    var isConfigured: Bool { rate != nil }

    /// The other currency of the pair.
    func other(_ currency: String) -> String { currency == main ? secondary : main }

    /// Same pair the other way round, with the inverse rate.
    private func swapped() -> FxPair {
        FxPair(main: secondary, secondary: main, rate: rate.map { (1 / $0).rounded(scale: 6) })
    }

    /// New main currency. The two currencies are never the same: picking the secondary one swaps
    /// them. Any other change leaves no known rate, so it is left empty for the user to type.
    func withMain(_ code: String) -> FxPair {
        if code == main { return self }
        if code == secondary { return swapped() }
        return FxPair(main: code, secondary: secondary, rate: nil)
    }

    /// New secondary currency; same rules as `withMain`.
    func withSecondary(_ code: String) -> FxPair {
        if code == secondary { return self }
        if code == main { return swapped() }
        return FxPair(main: main, secondary: code, rate: nil)
    }

    /// Unrounded; nil when there is no rate for it: `from` or `to` is outside the pair, or the
    /// rate is not set yet.
    private func raw(_ amount: Decimal, from: String, to: String) -> Decimal? {
        if from == to { return amount }
        guard let rate else { return nil }
        if from == secondary, to == main { return amount * rate }
        if from == main, to == secondary { return (amount / rate).rounded(scale: 10) }
        return nil
    }

    /// Rounds once, at the end.
    func convert(_ amount: Decimal, from: String, to: String) -> Decimal? {
        raw(amount, from: from, to: to)?.rounded(scale: 2)
    }

    /// Units of `to` per 1 unit of `from`, or nil when there is no rate for it.
    func rateBetween(from: String, to: String) -> Decimal? {
        raw(1, from: from, to: to)?.rounded(scale: 6)
    }

    /// Savings total of the included accounts, shown in `currency`. Accounts that cannot be
    /// converted (a currency outside the pair, or no rate yet) are left out.
    func savingsTotal(of accounts: [Account], in currency: String) -> Decimal {
        accounts.filter(\.includeInSavings)
            .reduce(Decimal(0)) { total, account in
                total + (raw(account.balance, from: account.currency, to: currency) ?? 0)
            }
            .rounded(scale: 2)
    }
}
