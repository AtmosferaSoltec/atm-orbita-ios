import Foundation

/// Something the user must be told: a form that cannot be saved yet, or a failed operation.
enum UiMessage: Equatable {
    case invalid(ValidationError)
    case failed(DataError)

    /// Text of the message in the language of the interface (es-PE). The app picks it from the
    /// code; the API's own message is never shown.
    var text: String {
        switch self {
        case .invalid(let error): Self.text(for: error)
        case .failed(let error): Self.text(for: error)
        }
    }

    private static func text(for error: ValidationError) -> String {
        switch error {
        case .nameRequired: "Escribe un nombre."
        case .nameTooLong: "El nombre puede tener hasta 60 caracteres."
        case .amountRequired: "Escribe un monto mayor que cero."
        case .accountRequired: "Elige una cuenta."
        case .categoryRequired: "Elige una categoría."
        case .cardRequired: "Elige una tarjeta de crédito."
        case .descriptionTooLong: "El texto puede tener hasta 500 caracteres."
        case .sameAccount: "Elige dos cuentas distintas."
        case .rateRequired: "Escribe un tipo de cambio mayor que cero."
        case .futureDate: "La fecha no puede ser posterior a hoy."
        case .dueDatePast: "La fecha límite de pago no puede ser anterior a hoy."
        case .emailInvalid: "Escribe un correo válido."
        case .passwordTooShort: "La contraseña debe tener al menos 8 caracteres."
        case .passwordTooLong: "La contraseña puede tener hasta 128 caracteres."
        case .passwordsDontMatch: "Las contraseñas no coinciden."
        case .passwordRequired: "Escribe tu contraseña."
        case .codeInvalid: "Escribe los 6 dígitos del código."
        }
    }

    private static func text(for error: DataError) -> String {
        switch error {
        case .network: "Sin conexión. Revisa tu internet e inténtalo de nuevo."
        case .invalidCredentials: "Correo o contraseña incorrectos."
        case .emailAlreadyRegistered: "Ese correo ya tiene una cuenta. Inicia sesión."
        case .emailNotConfirmed: "Revisa tu correo y confirma tu cuenta para poder ingresar."
        case .notFound: "Este registro ya no existe."
        case .nameTaken: "Ya tienes una categoría de este tipo con ese nombre."
        case .fxNotConfigured: "Configura tu tipo de cambio en Ajustes para usar otra moneda."
        case .purchaseAlreadyPaid: "Esta compra ya está pagada."
        case .cardHasPendingPurchases:
            "Esta tarjeta tiene pagos pendientes. Págalos o elimínalos antes de archivarla."
        case .paymentLocked:
            "Este egreso es el pago de una compra con tarjeta: solo puedes cambiar la cuenta, el monto y la fecha."
        case .sessionExpired: "Tu sesión terminó. Inicia sesión de nuevo."
        case .tooManyRequests: "Demasiados intentos. Espera un momento."
        case .resetCodeInvalid: "El código no es válido o ya venció. Pide uno nuevo."
        case .wrongPassword: "La contraseña no es correcta."
        case .googleUnavailable: "El acceso con Google no está disponible en este momento."
        case .googleInvalid: "No pudimos verificar tu cuenta de Google. Vuelve a continuar con Google."
        case .googleChallengeExpired: "El intento de acceso venció. Vuelve a continuar con Google."
        case .googleLinkRequired: "Confirma tu contraseña de Orbita para vincular Google."
        case .googleIdentityConflict:
            "Tu cuenta ya tiene otra cuenta de Google vinculada. Usa esa cuenta o ingresa con contraseña."
        case .unknown: "Algo salió mal. Inténtalo de nuevo."
        }
    }
}

extension DataException {
    /// A form the data source rejected is told like the app's own validation.
    var uiMessage: UiMessage {
        invalid.map(UiMessage.invalid) ?? .failed(error)
    }
}

/// The text of any error a screen can get.
func uiMessage(for error: Error) -> UiMessage {
    (error as? DataException)?.uiMessage ?? .failed(.unknown)
}
