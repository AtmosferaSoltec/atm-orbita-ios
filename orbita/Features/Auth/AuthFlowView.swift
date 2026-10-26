import SwiftUI

/// The screens without a session. Recovering the password goes forgot → code → new password.
struct AuthFlowView: View {
    @Environment(AppModel.self) private var app

    @State private var step = AuthStep.login
    // The email the code was asked for, to say where it went, and the code once it is valid.
    @State private var recoveryEmail = ""
    @State private var recoveryCode = ""
    // Set once a new password is saved; told on the login form.
    @State private var passwordChanged = false

    private var errorText: String? { app.authError?.text }

    /// "Continuar con Google" only when the API offers it and the app can ask Google for a token.
    private var googleAction: ((String) -> Void)? {
        guard app.googleClientId != nil else { return nil }
        return { currency in
            passwordChanged = false
            app.continueWithGoogle(mainCurrency: currency)
        }
    }

    private func go(_ next: AuthStep) {
        app.clearAuthError()
        step = next
    }

    var body: some View {
        switch step {
        case .login, .register:
            let register = step == .register
            AuthScreen(
                register: register,
                onSubmit: { name, email, password, currency in
                    passwordChanged = false
                    if register {
                        app.signUp(name: name, email: email, password: password, mainCurrency: currency)
                    } else {
                        app.signIn(email: email, password: password)
                    }
                },
                onSwitch: {
                    app.cancelGoogleLink()
                    go(register ? .login : .register)
                },
                error: errorText,
                notice: passwordChanged ? "Tu contraseña se cambió. Inicia sesión con la nueva." : nil,
                defaultCurrency: defaultCurrencyFor(),
                onForgotPassword: { go(.forgot) },
                onGoogle: googleAction,
                busy: app.authBusy,
                googleLinking: app.googleLinking,
                onLinkGoogle: { app.linkGoogle(password: $0) },
                onCancelGoogleLink: { app.cancelGoogleLink() }
            )
        case .forgot:
            ForgotPasswordScreen(
                onSubmit: { email in
                    app.requestPasswordReset(email: email) {
                        recoveryEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
                        go(.code)
                    }
                },
                onBack: { go(.login) },
                error: errorText
            )
        case .code:
            ResetCodeScreen(
                email: recoveryEmail,
                onSubmit: { code in
                    app.verifyResetCode(email: recoveryEmail, code: code) {
                        recoveryCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
                        go(.newPassword)
                    }
                },
                onResend: { go(.forgot) },
                onBack: { go(.login) },
                error: errorText,
                demo: app.isDemo
            )
        case .newPassword:
            NewPasswordScreen(
                onSubmit: { password, confirmation in
                    app.resetPassword(email: recoveryEmail, code: recoveryCode, password: password, confirmation: confirmation) {
                        recoveryCode = ""
                        passwordChanged = true
                        go(.login)
                    }
                },
                onBack: { go(.login) },
                error: errorText
            )
        }
    }
}
