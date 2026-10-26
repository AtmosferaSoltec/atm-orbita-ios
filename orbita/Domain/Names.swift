import Foundation

// Stands in for the ñ while the accents are removed; it cannot be typed.
private let enyePlaceholder: Character = "\u{01}"

/// A name as it is stored and shown: trimmed, with single spaces, otherwise as typed.
func cleanName(_ name: String) -> String {
    name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
}

/// The key two names are compared by: lowercase, without accents, with single spaces.
/// "Alimentación", "alimentacion" and "ALIMENTACIÓN" give the same key. The ñ is a letter of
/// its own, not an accented n, so it stays: "Año" and "Ano" are different names.
///
/// It is never shown. The backend computes the same key to keep category names unique, so both
/// must give the same result.
func normalizeName(_ name: String) -> String {
    // Composed first, so an ñ typed as n + combining tilde is protected too.
    let composed = cleanName(name).lowercased().precomposedStringWithCanonicalMapping
        .replacingOccurrences(of: "ñ", with: String(enyePlaceholder))
    let withoutAccents = String(
        composed.decomposedStringWithCanonicalMapping.unicodeScalars.filter { scalar in
            switch scalar.properties.generalCategory {
            case .nonspacingMark, .spacingMark, .enclosingMark: false
            default: true
            }
        }
    )
    return withoutAccents
        .replacingOccurrences(of: String(enyePlaceholder), with: "ñ")
        .precomposedStringWithCanonicalMapping
}
