import SwiftUI

private enum FxMode: Hashable { case manual, auto }

/// How long after the last key a typed exchange rate is saved.
private let rateSaveDelay = Duration.milliseconds(700)

private extension FxPair {
    /// Same currencies and the same rate, whatever its scale ("3.2" and "3.200000").
    func sameAs(_ other: FxPair) -> Bool {
        main == other.main && secondary == other.secondary && rate != nil && rate == other.rate
    }
}

/// Ajustes: currencies, exchange rate, categories, session and account.
struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @State private var loader = Loader<UserSettings>()

    var body: some View {
        Loaded(load: loader.state, onRetry: { loader.retry() }, onClose: { app.pop() }) { settings in
            SettingsForm(fx: settings.fx, displayCurrency: settings.displayCurrency)
        }
        .task(id: [app.revision, loader.attempt]) { await loader.run { try await app.env.settings.settings() } }
    }
}

private struct SettingsForm: View {
    @Environment(AppModel.self) private var app
    let fx: FxPair
    let displayCurrency: String

    // The pair on screen. A pair of currencies is only saved together with its rate, so a new
    // pair stays here, unsaved, until the user types one; leaving the screen discards it.
    @State private var pair: FxPair
    // The text restarts whenever the pair of currencies changes; empty when there is no rate.
    @State private var rate: String
    @State private var confirmDeleteAccount = false
    @State private var deletePassword = ""

    init(fx: FxPair, displayCurrency: String) {
        self.fx = fx
        self.displayCurrency = displayCurrency
        _pair = State(initialValue: fx)
        _rate = State(initialValue: fx.rate.map(formatRate) ?? "")
    }

    private struct PairKey: Hashable {
        let main: String
        let secondary: String
    }

    private var parsedRate: Decimal? { parsePositiveDecimal(rate) }

    // Swapping the two currencies keeps a known rate (its inverse) and is saved at once; any
    // other currency leaves the rate empty and waits for the user to type it.
    private func choosePair(_ next: FxPair) {
        pair = next
        if next.rate != nil { app.perform { try await app.env.settings.setFx(next) } }
    }

    /// A typed rate is saved once the user stops typing, not on every key: each save is a new row
    /// of the rate's history, and "3.20" must not become "3", "3.2" and "3.20".
    private var pending: FxPair? {
        guard let parsedRate else { return nil }
        let candidate = FxPair(main: pair.main, secondary: pair.secondary, rate: parsedRate)
        return candidate.sameAs(fx) ? nil : candidate
    }

    var body: some View {
        let mainSymbol = currencySymbol(pair.main)
        let secondarySymbol = currencySymbol(pair.secondary)
        // Shown with 4 decimals; the rate must be > 0.
        let inverse = parsedRate.map { plainDecimal((1 / $0).rounded(scale: 4), decimals: 4) } ?? "—"
        ScreenScaffold(header: {
            ModalTopBar(title: "Ajustes", icon: .back, onNavigate: { app.pop() })
        }) {
            SectionTitle(text: "Monedas")
            OrbitaCard {
                Text("Moneda predeterminada").font(OFont.bodyMedium).foregroundStyle(Palette.muted)
                DropdownField(
                    options: supportedCurrencies, selected: currencyInfo(pair.main),
                    onSelect: { choosePair(pair.withMain($0.code)) },
                    label: { $0.label }, detail: { $0.code }, leading: { _ in EmptyView() }
                )
                .padding(.top, 8)
                HintText("Es la moneda con la que se crean tus cuentas nuevas. Puedes cambiarla cuando quieras; tus cuentas actuales conservan la suya.")
                    .padding(.top, 8)
                CardDivider()
                Text("Moneda secundaria").font(OFont.bodyMedium).foregroundStyle(Palette.muted)
                DropdownField(
                    options: supportedCurrencies, selected: currencyInfo(pair.secondary),
                    onSelect: { choosePair(pair.withSecondary($0.code)) },
                    label: { $0.label }, detail: { $0.code }, leading: { _ in EmptyView() }
                )
                .padding(.top, 8)
                HintText("Sirve para ver el equivalente de tus ahorros en otra moneda. El tipo de cambio de abajo es entre estas dos monedas.")
                    .padding(.top, 8)
                CardDivider()
                HStack {
                    Text("Ver ahorro total en")
                        .font(OFont.bodyMedium)
                        .foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    SegmentedControl(
                        options: [(pair.main, mainSymbol), (pair.secondary, secondarySymbol)],
                        selected: displayCurrency,
                        // Only between the two saved currencies, and only once there is a rate.
                        onSelect: { currency in
                            if pair == fx && fx.isConfigured {
                                app.perform { try await app.env.settings.setDisplayCurrency(currency) }
                            }
                        },
                        fill: false
                    )
                }
            }

            SectionTitle(text: "Tipo de cambio")
            OrbitaCard {
                // "Automático" is announced but not available yet.
                SegmentedControl(
                    options: [(FxMode.manual, "Manual"), (FxMode.auto, "Automático · pronto")],
                    selected: .manual, onSelect: { _ in }
                )
                HStack(spacing: 12) {
                    Text("1 \(secondarySymbol) = \(mainSymbol)").font(OFont.titleMedium).foregroundStyle(Palette.ink)
                    // Only a valid rate (> 0) is saved, together with the pair on screen.
                    OrbitaTextField(text: $rate, placeholder: "0.00", keyboard: .decimalPad)
                        .frame(width: 120)
                        .onChange(of: rate) { _, value in
                            let cleaned = sanitizeDecimalInput(value, maxDecimals: 6)
                            if cleaned != value { rate = cleaned }
                        }
                }
                .padding(.top, 14)
                if parsedRate == nil {
                    // No rate yet (a new user, or a pair just chosen): nothing is saved until it is typed.
                    HintText(
                        rate.trimmingCharacters(in: .whitespaces).isEmpty
                            ? "Configura tu tipo de cambio"
                            : UiMessage.invalid(.rateRequired).text,
                        color: Palette.expense
                    )
                    .padding(.top, 8)
                }
                Text("Equivale a 1 \(mainSymbol) = \(secondarySymbol) \(inverse)")
                    .font(OFont.labelMedium)
                    .foregroundStyle(Palette.ink)
                    .padding(.top, 10)
                HintText("Se usa para el total de ahorros y como valor sugerido en las transferencias. Puedes cambiarlo cuando quieras.")
                    .padding(.top, 6)
                HintText("Al cambiar de monedas, escribe el tipo de cambio entre las dos para guardar.")
                    .padding(.top, 4)
            }

            SectionTitle(text: "Categorías")
            OrbitaCard(onClick: { app.push(.categories) }) {
                HStack(spacing: 12) {
                    IconBadge(systemName: "tag", tint: Palette.primary, container: Palette.primarySoft, size: 40)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Gestionar categorías").font(OFont.titleSmall).foregroundStyle(Palette.ink)
                        HintText("Crear, renombrar, cambiar color o archivar.")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.muted)
                }
            }

            SectionTitle(text: "Seguridad")
            OrbitaCard {
                HStack(spacing: 12) {
                    IconBadge(systemName: "shield", tint: Palette.neutral, container: Palette.neutralSoft, size: 40)
                    HintText("Inicias sesión con tu correo y contraseña. Cada persona solo ve sus propios datos.")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                CardDivider()
                LabelValueRow(label: "Sesión", value: app.email)
                HStack {
                    PillButton(
                        title: "Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right",
                        container: Palette.expenseSoft, content: Palette.expense
                    ) { app.signOut() }
                    Spacer()
                }
                .padding(.top, 12)
                // The one action that cannot be undone: it sits apart, under its own divider.
                CardDivider()
                HStack {
                    PillButton(
                        title: "Eliminar cuenta", systemImage: "trash",
                        container: Palette.expenseSoft, content: Palette.expense
                    ) { confirmDeleteAccount = true }
                    Spacer()
                }
                HintText("Se borran todos tus datos. No se puede deshacer.").padding(.top, 8)
            }

            SectionTitle(text: "Próximamente")
            OrbitaCard {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(["Exportar a PDF", "Modo sin internet", "Cambio automático diario", "Acceso con Google"], id: \.self) { item in
                        HStack(spacing: 10) {
                            Image(systemName: "clock").font(.system(size: 15, weight: .medium)).foregroundStyle(Palette.muted)
                            Text(item).font(OFont.bodyMedium).foregroundStyle(Palette.muted)
                        }
                        .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                    }
                }
            }
        }
        // The pair on screen follows what is saved.
        .onChange(of: fx) { _, saved in pair = saved }
        .onChange(of: PairKey(main: pair.main, secondary: pair.secondary)) { _, _ in
            rate = pair.rate.map(formatRate) ?? ""
        }
        .task(id: pending) {
            guard let pending else { return }
            try? await Task.sleep(for: rateSaveDelay)
            if Task.isCancelled { return }
            app.perform { try await app.env.settings.setFx(pending) }
        }
        // Leaving the screen right after typing still saves it.
        .onDisappear {
            if let pending { app.perform { try await app.env.settings.setFx(pending) } }
        }
        // Deleting the account is the one action that cannot be undone at all, so it asks for the
        // password again.
        .alert("¿Eliminar tu cuenta?", isPresented: $confirmDeleteAccount) {
            SecureField("Contraseña", text: $deletePassword)
            Button("Cancelar", role: .cancel) { deletePassword = "" }
            Button("Eliminar cuenta", role: .destructive) {
                let password = deletePassword
                deletePassword = ""
                app.deleteAccount(password: password)
            }
        } message: {
            Text("Se borrarán todos tus datos: cuentas, movimientos, categorías y tarjetas. No se puede deshacer.\n\nEscribe tu contraseña para confirmar.")
        }
    }

    private func plainDecimal(_ value: Decimal, decimals: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = decimals
        formatter.maximumFractionDigits = decimals
        formatter.roundingMode = .halfUp
        return formatter.string(from: value as NSDecimalNumber) ?? "—"
    }
}
