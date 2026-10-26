import Foundation

// Amount entry "from the right": the user only types digits and the decimal point places
// itself (4, 5, 5, 2 -> 0.04, 0.45, 4.55, 45.52). The amount is kept in minor units (cents).

/// 9,999,999.99
let maxAmountCents: Int64 = 999_999_999

/// Appends [digits] on the right; digits that would exceed the maximum are ignored.
func appendAmountDigits(_ cents: Int64, _ digits: String) -> Int64 {
    var result = cents
    for character in digits {
        guard let digit = character.wholeNumberValue else { continue }
        let next = result * 10 + Int64(digit)
        if next > maxAmountCents { return result }
        result = next
    }
    return result
}

/// Removes the last typed digit.
func removeAmountDigit(_ cents: Int64) -> Int64 { cents / 10 }

func centsToAmount(_ cents: Int64) -> Decimal { Decimal(cents) / 100 }

func amountToCents(_ amount: Decimal) -> Int64 {
    NSDecimalNumber(decimal: (amount * 100).rounded(scale: 0)).int64Value
}
