import Foundation

// What the forms send to be saved. Every draft knows how to check itself: validate() returns
// the first problem found, or nil when it can be saved.

enum ValidationError: String, Hashable {
    case nameRequired = "NAME_REQUIRED"
    case nameTooLong = "NAME_TOO_LONG"
    case amountRequired = "AMOUNT_REQUIRED"
    case accountRequired = "ACCOUNT_REQUIRED"
    case categoryRequired = "CATEGORY_REQUIRED"
    case cardRequired = "CARD_REQUIRED"
    case descriptionTooLong = "DESCRIPTION_TOO_LONG"
    case sameAccount = "SAME_ACCOUNT"
    case rateRequired = "RATE_REQUIRED"
    case futureDate = "FUTURE_DATE"
    case dueDatePast = "DUE_DATE_PAST"
    case emailInvalid = "EMAIL_INVALID"
    case passwordTooShort = "PASSWORD_TOO_SHORT"
    case passwordTooLong = "PASSWORD_TOO_LONG"
    /// The new password and its repetition differ.
    case passwordsDontMatch = "PASSWORDS_DONT_MATCH"
    /// The code to recover the password is not 6 digits.
    case codeInvalid = "CODE_INVALID"
    /// Deleting the account asks for the password again; an empty one is not sent.
    case passwordRequired = "PASSWORD_REQUIRED"
}

let nameMaxLength = 60
let textMaxLength = 500
let passwordMinLength = 8

/// The API's limit: a huge password would only cost CPU to hash.
let passwordMaxLength = 128

/// A name: of an account, a category, a card, or the user's own on sign-up.
func validateName(_ name: String) -> ValidationError? {
    if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .nameRequired }
    if name.trimmingCharacters(in: .whitespacesAndNewlines).count > nameMaxLength { return .nameTooLong }
    return nil
}

private func isPositive(_ value: Decimal?) -> Bool { (value ?? 0) > 0 }

struct AccountDraft {
    var name: String
    var type: AccountType
    /// Fixed once the account exists.
    var currency: String
    /// Only used when the account is created.
    var initialBalance: Decimal
    var includeInSavings: Bool

    func validate() -> ValidationError? { validateName(name) }
}

struct CategoryDraft {
    var name: String
    /// Fixed once the category exists.
    var kind: MovementKind
    var colorHex: String

    func validate() -> ValidationError? { validateName(name) }
}

struct MovementDraft {
    var kind: MovementKind
    var amount: Decimal?
    var accountId: String?
    var categoryId: String?
    var description: String
    /// Nil on a new movement: it takes the day it is saved.
    var date: LocalDay?

    func validate(today: LocalDay) -> ValidationError? {
        if !isPositive(amount) { return .amountRequired }
        if accountId == nil { return .accountRequired }
        if categoryId == nil { return .categoryRequired }
        if description.count > textMaxLength { return .descriptionTooLong }
        if let date, date > today { return .futureDate }
        return nil
    }
}

struct TransferDraft {
    var fromAccountId: String
    var toAccountId: String
    var fromAmount: Decimal?
    var toAmount: Decimal?
    /// Nil between accounts of the same currency.
    var exchangeRate: Decimal?
    var date: LocalDay
    var note: String

    /// `sameCurrency`: whether both accounts share their currency, so no rate applies.
    func validate(today: LocalDay, sameCurrency: Bool) -> ValidationError? {
        if fromAccountId == toAccountId { return .sameAccount }
        if !isPositive(fromAmount) || !isPositive(toAmount) { return .amountRequired }
        if !sameCurrency && !isPositive(exchangeRate) { return .rateRequired }
        if note.count > textMaxLength { return .descriptionTooLong }
        if date > today { return .futureDate }
        return nil
    }
}

struct CreditCardDraft {
    var name: String
    var currency: String

    func validate() -> ValidationError? { validateName(name) }
}

/// A purchase is registered today and in the currency of its card.
struct CreditPurchaseDraft {
    var cardId: String?
    var amount: Decimal?
    var categoryId: String?
    var description: String
    /// Unlike every other date, a due date is in the future by nature.
    var dueDate: LocalDay

    func validate(today: LocalDay) -> ValidationError? {
        if !isPositive(amount) { return .amountRequired }
        if cardId == nil { return .cardRequired }
        if categoryId == nil { return .categoryRequired }
        if description.count > textMaxLength { return .descriptionTooLong }
        if dueDate < today { return .dueDatePast }
        return nil
    }

    /// For a purchase that already exists. Its due date may be in the past (an overdue purchase
    /// must still be fixable), but never before the day it was bought.
    func validateEdit(purchaseDate: LocalDay) -> ValidationError? {
        if !isPositive(amount) { return .amountRequired }
        if cardId == nil { return .cardRequired }
        if categoryId == nil { return .categoryRequired }
        if description.count > textMaxLength { return .descriptionTooLong }
        if dueDate < purchaseDate { return .dueDatePast }
        return nil
    }
}

/// `paidAmount` is what the bank really charged, in the currency of the paying account.
struct CreditPayment {
    var purchaseId: String
    var accountId: String?
    var paidAmount: Decimal?
    var paidOn: LocalDay

    func validate(today: LocalDay) -> ValidationError? {
        if accountId == nil { return .accountRequired }
        if !isPositive(paidAmount) { return .amountRequired }
        if paidOn > today { return .futureDate }
        return nil
    }
}

private func matches(_ pattern: String, _ text: String) -> Bool {
    text.range(of: pattern, options: .regularExpression) != nil
}

/// For the forms that only ask for the email, like recovering the password.
func validateEmail(_ email: String) -> ValidationError? {
    matches("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", email.trimmingCharacters(in: .whitespacesAndNewlines))
        ? nil : .emailInvalid
}

/// For a password that is being chosen: on sign-up and when a new one replaces a forgotten one.
func validateNewPassword(_ password: String) -> ValidationError? {
    let length = password.unicodeScalars.count
    if length < passwordMinLength { return .passwordTooShort }
    if length > passwordMaxLength { return .passwordTooLong }
    return nil
}

/// A new password typed twice, so a typo does not lock the user out.
func validatePasswordChange(_ password: String, confirmation: String) -> ValidationError? {
    validateNewPassword(password) ?? (password == confirmation ? nil : .passwordsDontMatch)
}

struct Credentials {
    var email: String
    var password: String

    func validate() -> ValidationError? { validateEmail(email) ?? validateNewPassword(password) }
}

/// The code that arrives by email to recover the password: 6 digits.
func validateResetCode(_ code: String) -> ValidationError? {
    matches("^[0-9]{6}$", code.trimmingCharacters(in: .whitespacesAndNewlines)) ? nil : .codeInvalid
}
