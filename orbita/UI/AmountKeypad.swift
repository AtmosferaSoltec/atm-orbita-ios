import SwiftUI
import UIKit

/// Big amount typed with `AmountKeypad`; grey while it is zero, with a blinking cursor when active.
struct AmountDisplay: View {
    let symbol: String
    let cents: Int64
    var color: Color = Palette.ink
    var active = false
    var font: Font = OFont.displaySmall
    var cursorHeight: CGFloat = 36

    @State private var cursorVisible = true

    var body: some View {
        HStack(spacing: 10) {
            Text(symbol).font(font).foregroundStyle(Palette.muted)
            Text(formatAmount(centsToAmount(cents)))
                .font(font)
                .foregroundStyle(cents == 0 ? Palette.chipBorder : color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if active {
                Rectangle()
                    .fill(Palette.primary)
                    .frame(width: 2, height: cursorHeight)
                    .opacity(cursorVisible ? 1 : 0)
                    .padding(.leading, -6)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: active) {
            cursorVisible = true
            guard active else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                cursorVisible.toggle()
            }
        }
    }
}

/// In-app numeric keypad for amounts (the system keyboard is not used). There is no decimal key:
/// digits enter from the right and the point places itself. Long-press on backspace clears.
struct AmountKeypad: View {
    let onDigits: (String) -> Void
    let onBackspace: () -> Void
    let onClear: () -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            ForEach(["123", "456", "789"], id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(Array(row), id: \.self) { digit in digitKey(String(digit)) }
                }
            }
            HStack(spacing: 8) {
                Color.clear.frame(maxWidth: .infinity, minHeight: 54)
                digitKey("0")
                KeypadKey(onTap: onBackspace, onLongPress: onClear) {
                    Image(systemName: "delete.left")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Palette.ink)
                }
                .accessibilityLabel("Borrar")
                .accessibilityHint("Mantén pulsado para borrar todo")
            }
            PrimaryButton(title: "Listo", systemImage: "checkmark", action: onDone)
        }
        .padding(12)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.heroCard, style: .continuous))
    }

    private func digitKey(_ digit: String) -> some View {
        KeypadKey(onTap: { onDigits(digit) }) {
            Text(digit).font(OFont.custom(24, .bold)).foregroundStyle(Palette.ink)
        }
    }
}

private struct KeypadKey<Content: View>: View {
    let onTap: () -> Void
    var onLongPress: (() -> Void)?
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Palette.neutralSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .onTapGesture {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onTap()
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                guard let onLongPress else { return }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onLongPress()
            }
            .accessibilityAddTraits(.isButton)
    }
}
