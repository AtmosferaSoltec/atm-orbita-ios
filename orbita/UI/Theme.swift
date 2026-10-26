import CoreText
import SwiftUI

// Design tokens from ORBITA_SPEC section 5 (same values as the Android theme).

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    /// `#RRGGBB` -> color; an unreadable value falls back to the neutral category color.
    init(categoryHex hex: String) {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        if digits.count == 6, let value = UInt32(digits, radix: 16) {
            self.init(hex: value)
        } else {
            self = Palette.categoryOther
        }
    }
}

extension Category {
    var color: Color { Color(categoryHex: colorHex) }
}

enum Palette {
    static let background = Color(hex: 0xF3F5F7)
    static let surface = Color.white
    static let ink = Color(hex: 0x0E1A2B)
    static let muted = Color(hex: 0x5B6778)
    static let mutedLight = Color(hex: 0x94A0B2)
    static let outline = Color(hex: 0xE3E8EE)
    static let dividerSoft = Color(hex: 0xEEF1F5)
    static let primary = Color(hex: 0x1D4ED8)
    static let primarySoft = Color(hex: 0xE8EEFD)
    static let onHero = Color.white
    static let onHeroMuted = Color(hex: 0xC7D2E3)

    // Gradient of the highlighted cards (Inicio, Cuentas): violet -> blue -> teal
    static let heroGradientStart = Color(hex: 0x3B1D8F)
    static let heroGradientMid = Color(hex: 0x1D4ED8)
    static let heroGradientEnd = Color(hex: 0x0E7490)
    static let heroGlow = Color(hex: 0x67E8F9)

    // Gradient of the credit card (Crédito): yellow -> amber -> orange
    static let creditGradientStart = Color(hex: 0xFDE047)
    static let creditGradientMid = Color(hex: 0xFBBF24)
    static let creditGradientEnd = Color(hex: 0xF59E0B)

    static let income = Color(hex: 0x2EAD5B)
    static let incomeSoft = Color(hex: 0xE6F6EC)
    static let expense = Color(hex: 0xE53935)
    static let expenseSoft = Color(hex: 0xFDECEA)
    static let neutral = Color(hex: 0x3B4A60)
    static let neutralSoft = Color(hex: 0xEEF1F5)
    // Transfers and currency exchanges (sky blue); credit card reminder (orange)
    static let transfer = Color(hex: 0x0EA5E9)
    static let transferSoft = Color(hex: 0xE0F2FE)
    static let orange = Color(hex: 0xF97316)
    static let orangeSoft = Color(hex: 0xFFEDD5)
    static let chipBorder = Color(hex: 0xCBD3DE)
    static let switchOff = Color(hex: 0x8793A6)

    // Category colors
    static let categoryHousing = Color(hex: 0x1D4ED8)
    static let categoryFood = Color(hex: 0x0E7490)
    static let categoryTransport = Color(hex: 0xB45309)
    static let categoryLeisure = Color(hex: 0xBE185D)
    static let categoryOther = Color(hex: 0x64748B)
    static let categoryHealth = Color(hex: 0x7C3AED)
    static let categorySalary = Color(hex: 0x0B7A5A)
    static let categoryFreelance = Color(hex: 0x0E7490)

    /// The seven swatches of the category form, as `#RRGGBB`.
    static let categoryPaletteHex = ["#1D4ED8", "#0E7490", "#B45309", "#BE185D", "#64748B", "#7C3AED", "#0B7A5A"]
}

enum Radius {
    static let card: CGFloat = 20
    static let heroCard: CGFloat = 28
    static let pill: CGFloat = 22
    static let button: CGFloat = 18
    static let field: CGFloat = 14
    static let iconBadge: CGFloat = 14
}

/// Manrope (bundled variable font). Sizes follow the Android type scale.
enum OFont {
    private static func manrope(_ size: CGFloat, _ weight: Font.Weight, _ style: Font.TextStyle) -> Font {
        .custom("Manrope", size: size, relativeTo: style).weight(weight)
    }

    static let displaySmall = manrope(38, .heavy, .largeTitle)
    static let headlineMedium = manrope(26, .heavy, .title)
    static let titleLarge = manrope(20, .heavy, .title3)
    static let titleMedium = manrope(16, .heavy, .headline)
    static let titleSmall = manrope(15, .bold, .subheadline)
    static let bodyLarge = manrope(16, .medium, .body)
    static let bodyMedium = manrope(14, .medium, .callout)
    static let bodySmall = manrope(13, .medium, .footnote)
    static let labelLarge = manrope(14, .bold, .callout)
    static let labelMedium = manrope(13, .semibold, .footnote)
    static let labelSmall = manrope(12, .semibold, .caption)

    /// A size outside the scale (e.g. the 42 pt amount of the savings card).
    static func custom(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
        manrope(size, weight, .largeTitle)
    }
}

enum FontLoader {
    /// Registers the bundled Manrope file so `Font.custom("Manrope")` resolves.
    static func registerManrope() {
        guard let url = Bundle.main.url(forResource: "Manrope", withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
}
