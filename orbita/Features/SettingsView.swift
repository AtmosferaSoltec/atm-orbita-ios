import SwiftUI

private enum FxMode { case manual, auto }

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var rate = formatRate(SampleData.usdToPen)

    var body: some View {
        // Shown with 4 decimals; the rate must be > 0.
        let inverse = parsePositiveDecimal(rate).map { formatDecimalFixed((1 / $0).rounded(scale: 4), 4) } ?? "—"

        ScreenScaffold {
            ModalTopBar(title: "Ajustes", icon: .back) { model.pop() }
        } content: {
            SectionTitle(text: "Monedas").padding(.top, 0)
            OrbitaCard {
                LabelValueRow(label: "Moneda predeterminada", value: "Soles (S/)")
                CardDivider()
                HStack {
                    Text("Ver ahorro total en")
                        .font(OFont.bodyMedium)
                        .foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    SegmentedControl(
                        options: [(PEN, "S/"), (USD, "US$")],
                        selected: model.displayCurrency,
                        onSelect: { model.displayCurrency = $0 },
                        fill: false
                    )
                }
            }

            SectionTitle(text: "Tipo de cambio")
            OrbitaCard {
                // "Automático" is announced but not available yet.
                SegmentedControl(
                    options: [(FxMode.manual, "Manual"), (FxMode.auto, "Automático · pronto")],
                    selected: .manual,
                    onSelect: { _ in }
                )
                HStack(spacing: 12) {
                    Text("1 US$ = S/").font(OFont.titleMedium).foregroundStyle(Palette.ink)
                    OrbitaTextField(text: $rate, placeholder: "0.00", keyboard: .decimalPad)
                        .frame(width: 120)
                }
                .padding(.top, 14)
                Text("Equivale a 1 S/ = US$ \(inverse)")
                    .font(OFont.labelMedium)
                    .foregroundStyle(Palette.ink)
                    .padding(.top, 10)
                HintText("Se usa para el total de ahorros y como valor sugerido en las transferencias. Puedes cambiarlo cuando quieras.")
                    .padding(.top, 6)
            }

            SectionTitle(text: "Categorías")
            OrbitaCard(onClick: { model.push(.categories) }) {
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
                LabelValueRow(label: "Sesión", value: SampleData.userEmail)
                PillButton(
                    title: "Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right",
                    container: Palette.expenseSoft, content: Palette.expense
                ) { model.logout() }
                    .padding(.top, 12)
            }

            SectionTitle(text: "Próximamente")
            OrbitaCard {
                VStack(spacing: 4) {
                    ForEach(
                        ["Exportar a PDF", "Modo sin internet", "Cambio automático diario", "Acceso con Google"],
                        id: \.self
                    ) { item in
                        HStack(spacing: 10) {
                            Image(systemName: "clock")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Palette.muted)
                            Text(item).font(OFont.bodyMedium).foregroundStyle(Palette.muted)
                            Spacer()
                        }
                        .frame(minHeight: 36)
                    }
                }
            }
        }
    }

    private func formatDecimalFixed(_ value: Decimal, _ digits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits
        formatter.usesGroupingSeparator = false
        return formatter.string(from: value as NSDecimalNumber) ?? "—"
    }
}

#Preview("Ajustes") { SettingsView().environment(AppModel()) }
