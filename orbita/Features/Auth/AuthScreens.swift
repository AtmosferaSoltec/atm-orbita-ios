import SwiftUI

/// Login (`register` = false) or sign-up.
struct AuthScreen: View {
    let register: Bool
    let onSubmit: (_ name: String, _ email: String, _ password: String, _ mainCurrency: String) -> Void
    let onSwitch: () -> Void
    var error: String?
    /// Good news shown on the login form, e.g. after choosing a new password.
    var notice: String?
    /// The currency offered on sign-up: the one of the phone's region, or soles.
    var defaultCurrency = PEN
    var onForgotPassword: () -> Void = {}
    /// Shows "Continuar con Google" (nil hides it); a new account starts on the currency.
    var onGoogle: ((_ mainCurrency: String) -> Void)?
    var busy = false
    /// The Google email already has an account: its password is asked once to link it.
    var googleLinking = false
    var onLinkGoogle: (_ password: String) -> Void = { _ in }
    var onCancelGoogleLink: () -> Void = {}

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var currency: String

    init(
        register: Bool,
        onSubmit: @escaping (String, String, String, String) -> Void,
        onSwitch: @escaping () -> Void,
        error: String? = nil,
        notice: String? = nil,
        defaultCurrency: String = PEN,
        onForgotPassword: @escaping () -> Void = {},
        onGoogle: ((String) -> Void)? = nil,
        busy: Bool = false,
        googleLinking: Bool = false,
        onLinkGoogle: @escaping (String) -> Void = { _ in },
        onCancelGoogleLink: @escaping () -> Void = {}
    ) {
        self.register = register
        self.onSubmit = onSubmit
        self.onSwitch = onSwitch
        self.error = error
        self.notice = notice
        self.defaultCurrency = defaultCurrency
        self.onForgotPassword = onForgotPassword
        self.onGoogle = onGoogle
        self.busy = busy
        self.googleLinking = googleLinking
        self.onLinkGoogle = onLinkGoogle
        self.onCancelGoogleLink = onCancelGoogleLink
        _currency = State(initialValue: defaultCurrency)
    }

    var body: some View {
        AuthScaffold {
            AuthHeading(
                title: register ? "Crea tu cuenta" : "Inicia sesión",
                subtitle: register
                    ? "Cada persona solo ve sus propios datos."
                    : "Registra tus ingresos y gastos, y mira cuánto tienes ahorrado."
            )

            if register {
                FieldLabel("Nombre")
                OrbitaTextField(text: $name, placeholder: "Cómo quieres que te llamemos")
                    .onChange(of: name) { _, value in
                        if value.count > nameMaxLength { name = String(value.prefix(nameMaxLength)) }
                    }
            }

            FieldLabel("Correo")
            EmailField(text: $email)

            FieldLabel("Contraseña")
            PasswordField(text: $password)
            if register {
                HintText("Mínimo 8 caracteres.").padding(.top, 8)

                // The user's main currency: their first account ("Efectivo") starts on it.
                FieldLabel("Moneda")
                DropdownField(
                    options: supportedCurrencies,
                    selected: currencyInfo(currency),
                    onSelect: { currency = $0.code },
                    label: { $0.label },
                    detail: { $0.code },
                    leading: { _ in EmptyView() }
                )
                HintText("Es la moneda de tus cuentas. Podrás cambiarla después en Ajustes.").padding(.top, 8)
            } else {
                HStack {
                    Spacer()
                    Button(action: onForgotPassword) {
                        Text("¿Olvidaste tu contraseña?")
                            .font(OFont.labelLarge)
                            .foregroundStyle(Palette.primary)
                            .padding(.horizontal, 8)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            if let error {
                AuthMessage(text: error, isError: true)
            } else if let notice, !register {
                AuthMessage(text: notice, isError: false)
            }

            PrimaryButton(title: register ? "Crear cuenta" : "Ingresar") {
                onSubmit(name, email, password, currency)
            }
            .padding(.top, 24)

            if let onGoogle {
                GoogleSection(
                    busy: busy, linking: googleLinking,
                    onContinue: { onGoogle(currency) }, onLink: onLinkGoogle, onCancelLink: onCancelGoogleLink
                )
            }

            AuthLink(
                prefix: register ? "¿Ya tienes cuenta?" : "¿No tienes cuenta?",
                link: register ? "Inicia sesión" : "Regístrate",
                action: onSwitch
            )
        }
    }
}

/// Asks for the email the 6-digit code to choose a new password will be sent to.
struct ForgotPasswordScreen: View {
    let onSubmit: (_ email: String) -> Void
    let onBack: () -> Void
    var error: String?

    @State private var email = ""

    var body: some View {
        AuthScaffold {
            AuthHeading(
                title: "Recupera tu contraseña",
                subtitle: "Escribe tu correo y te enviaremos un código para crear una contraseña nueva."
            )
            FieldLabel("Correo")
            EmailField(text: $email)
            if let error { AuthMessage(text: error, isError: true) }
            PrimaryButton(title: "Enviar código") { onSubmit(email) }.padding(.top, 24)
            AuthLink(link: "Volver a iniciar sesión", action: onBack)
        }
    }
}

/// The code that arrived by email, shown whether `email` has an account or not: the app never
/// tells which emails are registered. In `demo` mode no email arrives and any 6 digits work.
struct ResetCodeScreen: View {
    let email: String
    let onSubmit: (_ code: String) -> Void
    let onResend: () -> Void
    let onBack: () -> Void
    var error: String?
    var demo = false

    @State private var code = ""

    private let codeLength = 6

    var body: some View {
        AuthScaffold {
            AuthHeading(
                title: "Escribe el código",
                subtitle: "Si \(email) tiene una cuenta, te enviamos un código de 6 dígitos. Vence en 15 minutos."
            )
            FieldLabel("Código")
            OrbitaTextField(text: $code, placeholder: "000000", keyboard: .numberPad)
                // Only digits, at most 6: what a code can be.
                .onChange(of: code) { _, typed in
                    let cleaned = String(typed.filter(\.isNumber).prefix(codeLength))
                    if cleaned != typed { code = cleaned }
                }
            HintText(demo
                ? "Modo demo: no llega ningún correo; sirve cualquier código de 6 dígitos."
                : "¿No llega? Revisa el correo no deseado o pide otro código."
            ).padding(.top, 8)
            if let error { AuthMessage(text: error, isError: true) }
            PrimaryButton(title: "Continuar") { onSubmit(code) }.padding(.top, 24)
            AuthLink(link: "Pedir otro código", action: onResend)
            AuthLink(link: "Volver a iniciar sesión", action: onBack)
        }
    }
}

/// After a valid code: choosing the new password.
struct NewPasswordScreen: View {
    let onSubmit: (_ password: String, _ confirmation: String) -> Void
    let onBack: () -> Void
    var error: String?

    @State private var password = ""
    @State private var confirmation = ""

    var body: some View {
        AuthScaffold {
            AuthHeading(
                title: "Crea una contraseña nueva",
                subtitle: "Al guardarla se cerrará la sesión en todos tus dispositivos."
            )
            FieldLabel("Contraseña nueva")
            PasswordField(text: $password)
            HintText("Mínimo 8 caracteres.").padding(.top, 8)
            FieldLabel("Repite la contraseña nueva").padding(.top, 16)
            PasswordField(text: $confirmation)
            if let error { AuthMessage(text: error, isError: true) }
            PrimaryButton(title: "Guardar contraseña") { onSubmit(password, confirmation) }.padding(.top, 24)
            AuthLink(link: "Volver a iniciar sesión", action: onBack)
        }
    }
}

// MARK: - Pieces shared by every screen without a session

/// Scrollable body whose content is centered vertically when it fits.
private struct AuthScaffold<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) { content }
                    .padding(.horizontal, screenPadding)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .center)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Palette.background.ignoresSafeArea())
    }
}

/// The floating cards, the title and the subtitle every one of these screens starts with.
private struct AuthHeading: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FloatingCards().padding(.top, 24)
            Text(title).font(OFont.headlineMedium).foregroundStyle(Palette.ink).padding(.top, 20)
            Text(subtitle).font(OFont.bodyMedium).foregroundStyle(Palette.muted).padding(.top, 6)
            Color.clear.frame(height: 10)
        }
    }
}

private struct EmailField: View {
    @Binding var text: String

    var body: some View {
        OrbitaTextField(text: $text, placeholder: "tucorreo@ejemplo.com", keyboard: .emailAddress)
    }
}

/// Password with the eye that shows or hides it.
private struct PasswordField: View {
    @Binding var text: String
    @State private var visible = false

    var body: some View {
        OrbitaTextField(text: $text, placeholder: "••••••••", isSecure: !visible) {
            Button { visible.toggle() } label: {
                Image(systemName: visible ? "eye.slash" : "eye")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Palette.muted)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(visible ? "Ocultar contraseña" : "Mostrar contraseña")
        }
    }
}

/// What the form has to say above its button: a problem in red, or good news in green.
private struct AuthMessage: View {
    let text: String
    let isError: Bool

    var body: some View {
        HStack(spacing: 10) {
            if isError {
                IconBadge(systemName: "exclamationmark.circle", tint: Palette.expense, container: Palette.expenseSoft, size: 32)
            } else {
                IconBadge(systemName: "checkmark", tint: Palette.income, container: Palette.incomeSoft, size: 32)
            }
            HintText(text, color: isError ? Palette.expense : Palette.ink)
            Spacer(minLength: 0)
        }
        .padding(.top, 14)
    }
}

/// The line under the button that leads to another of these screens.
private struct AuthLink: View {
    var prefix: String?
    let link: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            if let prefix { Text(prefix).font(OFont.bodyMedium).foregroundStyle(Palette.muted) }
            Button(action: action) {
                Text(link)
                    .font(OFont.labelLarge)
                    .foregroundStyle(Palette.primary)
                    .padding(.horizontal, 8)
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
}

/// Under the email form: "o continúa con" and the Google button. When the email already has an
/// account (`linking`), it asks once for that account's password instead.
private struct GoogleSection: View {
    let busy: Bool
    let linking: Bool
    let onContinue: () -> Void
    let onLink: (String) -> Void
    let onCancelLink: () -> Void

    @State private var password = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Rectangle().fill(Palette.outline).frame(height: 1)
                Text("o continúa con").font(OFont.bodySmall).foregroundStyle(Palette.muted).padding(.horizontal, 12)
                Rectangle().fill(Palette.outline).frame(height: 1)
            }
            .padding(.top, 20)
            .padding(.bottom, 16)
            if linking {
                HintText("Ya tienes una cuenta con este correo. Confirma tu contraseña de Orbita para vincular Google y conservar tus datos. Solo lo pediremos esta vez.")
                FieldLabel("Contraseña de Orbita")
                PasswordField(text: $password)
                PrimaryButton(title: "Vincular Google e ingresar") { onLink(password) }.padding(.top, 16)
                AuthLink(link: "Usar otra cuenta", action: onCancelLink)
            } else {
                Button(action: onContinue) {
                    HStack(spacing: 10) {
                        Text("G").font(OFont.custom(18, .heavy)).foregroundStyle(Palette.primary)
                        Text(busy ? "Verificando tu cuenta…" : "Continuar con Google")
                            .font(OFont.labelLarge)
                            .foregroundStyle(Palette.ink)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Palette.surface, in: Capsule())
                    .overlay(Capsule().strokeBorder(Palette.chipBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(busy)
            }
        }
    }
}

// MARK: - Floating cards

/// Two empty brand cards that float above the form and take turns at the front. They only carry
/// the app name in the top-left corner.
private struct FloatingCards: View {
    private let tones: [HeroTone] = [.savings, .credit]

    @State private var front = 0
    // The card that is drawn on top: it changes halfway through the swap, so the cards never clip.
    @State private var onTop = 0

    var body: some View {
        TimelineView(.animation) { timeline in
            // ±6 of vertical sway, 2.6 s cycle, in opposite directions.
            let phase = timeline.date.timeIntervalSinceReferenceDate / 2.6 * 2 * .pi
            let drift = CGFloat(sin(phase))
            ZStack {
                ForEach(Array(tones.enumerated()), id: \.offset) { index, tone in
                    FloatingCard(tone: tone)
                        .frame(width: 264, height: 166)
                        .modifier(CardPose(
                            depth: index == front ? 0 : 1,
                            side: index % 2 == 0 ? 1 : -1,
                            drift: drift
                        ))
                        .zIndex(index == onTop ? 1 : 0)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(3200))
                withAnimation(.easeInOut(duration: 0.9)) { front = (front + 1) % tones.count }
                try? await Task.sleep(for: .milliseconds(450))
                onTop = front
            }
        }
        .accessibilityHidden(true)
    }
}

private func lerp(_ from: CGFloat, _ to: CGFloat, _ fraction: CGFloat) -> CGFloat {
    from + (to - from) * fraction
}

private struct CardPose: ViewModifier, Animatable {
    var depth: CGFloat
    let side: CGFloat
    var drift: CGFloat

    // Only the depth animates; the sway is driven by the clock.
    var animatableData: CGFloat {
        get { depth }
        set { depth = newValue }
    }

    func body(content: Content) -> some View {
        // The cards move apart halfway through, so the swap never clips.
        let swing = CGFloat(sin(Double(depth) * .pi)) * 64 * side
        let scale = lerp(1, 0.92, depth)
        content
            .scaleEffect(scale)
            .rotationEffect(.degrees(Double(lerp(-4, 7, depth))))
            .offset(
                x: lerp(-10, 22, depth) + swing,
                y: lerp(14, -18, depth) + drift * 6 * side
            )
    }
}

private struct FloatingCard: View {
    let tone: HeroTone

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: Radius.heroCard, style: .continuous)
                .fill(LinearGradient(colors: tone.gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: Radius.heroCard, style: .continuous)
                .fill(RadialGradient(
                    colors: [tone.glow.opacity(0.30), .clear],
                    center: UnitPoint(x: 0.95, y: 0), startRadius: 0, endRadius: 185
                ))
            RoundedRectangle(cornerRadius: Radius.heroCard, style: .continuous)
                .fill(RadialGradient(
                    colors: [tone.gradient[0].opacity(0.55), .clear],
                    center: UnitPoint(x: 0, y: 1), startRadius: 0, endRadius: 185
                ))
            HStack(alignment: .top) {
                Text("Orbita")
                    .font(OFont.titleMedium)
                    .foregroundStyle(tone == .savings ? Color.white : Palette.ink)
                Spacer()
                CardChip()
            }
            .padding(20)
        }
        .shadow(color: tone.gradient.last!.opacity(0.45), radius: 16, y: 8)
    }
}

/// Metallic contact chip, drawn so the empty card still reads as a bank card.
private struct CardChip: View {
    private let line = Palette.ink.opacity(0.35)

    var body: some View {
        Canvas { context, size in
            let shape = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 6)
            context.fill(
                shape,
                with: .linearGradient(
                    Gradient(colors: [Color.white, Color(hex: 0xE2E8F0), Color(hex: 0xB6C0CE)]),
                    startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)
                )
            )
            context.stroke(shape, with: .color(line), lineWidth: 1)
            // Contact pads: a center pad with lines running out to both sides.
            let left = size.width * 0.32
            let right = size.width * 0.68
            var lines = Path()
            lines.move(to: CGPoint(x: left, y: 0))
            lines.addLine(to: CGPoint(x: left, y: size.height))
            lines.move(to: CGPoint(x: right, y: 0))
            lines.addLine(to: CGPoint(x: right, y: size.height))
            for fraction in [0.34, 0.66] {
                let y = size.height * fraction
                lines.move(to: CGPoint(x: 0, y: y))
                lines.addLine(to: CGPoint(x: left, y: y))
                lines.move(to: CGPoint(x: right, y: y))
                lines.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(lines, with: .color(line), lineWidth: 1)
        }
        .frame(width: 40, height: 30)
    }
}
