import SwiftUI

/// The three screens that introduce Orbita the first time it opens; `onFinish` on "Comenzar" or "Omitir".
struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var page = 0

    private struct Page {
        let systemName: String
        let tint: Color
        let container: Color
        let title: String
        let text: String
    }

    private let pages = [
        Page(
            systemName: "wallet.bifold.fill", tint: Palette.primary, container: Palette.primarySoft,
            title: "Todo tu dinero en un solo lugar",
            text: "Registra tus ingresos y gastos por cuenta, en soles o en dólares, y mira cuánto tienes ahorrado."
        ),
        Page(
            systemName: "creditcard.fill", tint: Palette.orange, container: Palette.orangeSoft,
            title: "Transferencias y tarjetas de crédito",
            text: "Mueve dinero entre tus cuentas y deja tus compras con tarjeta pendientes hasta que las pagues."
        ),
        Page(
            systemName: "chart.pie.fill", tint: Palette.income, container: Palette.incomeSoft,
            title: "Entiende a dónde va tu plata",
            text: "Los reportes te muestran en qué categorías gastas y cuánto ingresas cada mes."
        ),
    ]

    private var isLast: Bool { page == pages.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if !isLast {
                    Button("Omitir", action: onFinish)
                        .font(OFont.labelLarge)
                        .foregroundStyle(Palette.muted)
                        .padding(12)
                }
            }
            .frame(height: 48)

            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    let item = pages[index]
                    VStack(spacing: 0) {
                        Spacer()
                        IconBadge(systemName: item.systemName, tint: item.tint, container: item.container, size: 104)
                        Text(item.title)
                            .font(OFont.headlineMedium)
                            .foregroundStyle(Palette.ink)
                            .multilineTextAlignment(.center)
                            .padding(.top, 36)
                        Text(item.text)
                            .font(OFont.bodyLarge)
                            .foregroundStyle(Palette.muted)
                            .multilineTextAlignment(.center)
                            .padding(.top, 12)
                        Spacer()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? Palette.primary : Palette.outline)
                        .frame(width: index == page ? 24 : 8, height: 8)
                }
            }
            .padding(.vertical, 24)
            .accessibilityHidden(true)

            PrimaryButton(title: isLast ? "Comenzar" : "Siguiente") {
                if isLast {
                    onFinish()
                } else {
                    withAnimation { page += 1 }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .animation(.easeOut(duration: 0.2), value: page)
    }
}
