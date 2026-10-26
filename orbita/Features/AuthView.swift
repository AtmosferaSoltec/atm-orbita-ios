import SwiftUI

/// Login (`register` = false) or sign-up. Not in the original mockups (docs/05, section 9).
struct AuthView: View {
    let register: Bool
    let onSubmit: () -> Void
    let onSwitch: () -> Void
    var error: String?

    @State private var email = ""
    @State private var password = ""
    @State private var passwordVisible = false

    var body: some View {
        ScreenScaffold {
            Spacer().frame(height: 48)
            IconBadge(systemName: "wallet.bifold", tint: Palette.primary, container: Palette.primarySoft, size: 56)
            Text("Orbita")
                .font(OFont.labelLarge)
                .foregroundStyle(Palette.primary)
                .padding(.top, 20)
            Text(register ? "Crea tu cuenta" : "Inicia sesión")
                .font(OFont.headlineMedium)
                .foregroundStyle(Palette.ink)
            Text(register
                 ? "Cada persona solo ve sus propios datos."
                 : "Registra tus ingresos y gastos, y mira cuánto tienes ahorrado.")
                .font(OFont.bodyMedium)
                .foregroundStyle(Palette.muted)
                .padding(.top, 6)
                .padding(.bottom, 10)

            FieldLabel("Correo")
            OrbitaTextField(text: $email, placeholder: "tucorreo@ejemplo.com", keyboard: .emailAddress)

            FieldLabel("Contraseña")
            OrbitaTextField(text: $password, placeholder: "••••••••", isSecure: !passwordVisible) {
                Button { passwordVisible.toggle() } label: {
                    Image(systemName: passwordVisible ? "eye.slash" : "eye")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Palette.muted)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(passwordVisible ? "Ocultar contraseña" : "Mostrar contraseña")
            }
            if register {
                HintText("Mínimo 8 caracteres.").padding(.top, 8)
            }

            if let error {
                HStack(spacing: 10) {
                    IconBadge(
                        systemName: "exclamationmark.circle", tint: Palette.expense,
                        container: Palette.expenseSoft, size: 32
                    )
                    HintText(error, color: Palette.expense)
                }
                .padding(.top, 14)
            }

            PrimaryButton(title: register ? "Crear cuenta" : "Ingresar", action: onSubmit)
                .padding(.top, 24)

            HStack(spacing: 0) {
                Text(register ? "¿Ya tienes cuenta?" : "¿No tienes cuenta?")
                    .font(OFont.bodyMedium)
                    .foregroundStyle(Palette.muted)
                Button(action: onSwitch) {
                    Text(register ? "Inicia sesión" : "Regístrate")
                        .font(OFont.labelLarge)
                        .foregroundStyle(Palette.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        }
    }
}

#Preview("Iniciar sesión") { AuthView(register: false, onSubmit: {}, onSwitch: {}) }

#Preview("Iniciar sesión · error") {
    AuthView(register: false, onSubmit: {}, onSwitch: {}, error: "Correo o contraseña incorrectos.")
}

#Preview("Registro") { AuthView(register: true, onSubmit: {}, onSwitch: {}) }
