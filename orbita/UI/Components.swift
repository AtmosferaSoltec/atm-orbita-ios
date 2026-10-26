import SwiftUI

let screenPadding: CGFloat = 20

// MARK: - Scaffold and headers

/// Scrollable screen body with the standard horizontal padding and an optional pinned footer.
struct ScreenScaffold<Header: View, Content: View, Footer: View>: View {
    let header: Header
    let footer: Footer
    let content: Content

    init(
        @ViewBuilder header: () -> Header = { EmptyView() },
        @ViewBuilder footer: () -> Footer = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) {
        self.header = header()
        self.footer = footer()
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            header.padding(.horizontal, screenPadding)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) { content }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, screenPadding)
                    .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            if Footer.self != EmptyView.self {
                footer
                    .padding(.horizontal, screenPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background.ignoresSafeArea())
    }
}

/// Title block of the tab screens: optional overline, 26 pt title and a trailing action.
struct ScreenHeader<Action: View>: View {
    let title: String
    var overline: String?
    var subtitle: String?
    let action: Action

    init(
        title: String, overline: String? = nil, subtitle: String? = nil,
        @ViewBuilder action: () -> Action = { EmptyView() }
    ) {
        self.title = title
        self.overline = overline
        self.subtitle = subtitle
        self.action = action()
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                if let overline {
                    Text(overline).font(OFont.labelMedium).foregroundStyle(Palette.muted)
                }
                Text(title)
                    .font(OFont.headlineMedium)
                    .foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(OFont.bodyMedium)
                        .foregroundStyle(Palette.muted)
                        .padding(.top, 2)
                        .padding(.trailing, 12)
                }
            }
            Spacer(minLength: 8)
            action
        }
        .padding(.top, 12)
        .padding(.bottom, 16)
    }
}

enum NavigationIcon {
    case close, back

    var systemName: String { self == .close ? "xmark" : "chevron.left" }
    var label: String { self == .close ? "Cerrar" : "Volver" }
}

/// Top bar of the full-screen flows (no tab bar): close/back button on the left.
struct ModalTopBar<Action: View>: View {
    let title: String
    let icon: NavigationIcon
    let onNavigate: () -> Void
    let action: Action

    init(
        title: String,
        icon: NavigationIcon,
        onNavigate: @escaping () -> Void,
        @ViewBuilder action: () -> Action = { EmptyView() }
    ) {
        self.title = title
        self.icon = icon
        self.onNavigate = onNavigate
        self.action = action()
    }

    var body: some View {
        HStack(spacing: 12) {
            CircleIconButton(systemName: icon.systemName, label: icon.label, action: onNavigate)
            Text(title)
                .font(OFont.titleLarge)
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            action
        }
        .padding(.top, 8)
        .padding(.bottom, 16)
    }
}

struct CircleIconButton: View {
    let systemName: String
    let label: String
    var container: Color = Palette.surface
    var tint: Color = Palette.ink
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(enabled ? tint : tint.opacity(0.3))
                .frame(width: 48, height: 48)
                .background(container, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}

struct SectionTitle: View {
    let text: String
    var actionLabel: String?
    var onAction: () -> Void = {}

    var body: some View {
        HStack {
            Text(text)
                .font(OFont.titleMedium)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if let actionLabel {
                Button(action: onAction) {
                    Text(actionLabel)
                        .font(OFont.labelLarge)
                        .foregroundStyle(Palette.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 24)
        .padding(.bottom, 10)
    }
}

struct FieldLabel: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(OFont.labelMedium)
            .foregroundStyle(Palette.muted)
            .padding(.top, 18)
            .padding(.bottom, 8)
    }
}

struct HintText: View {
    let text: String
    var color: Color = Palette.muted

    init(_ text: String, color: Color = Palette.muted) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(OFont.bodySmall)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Containers

struct OrbitaCard<Content: View>: View {
    var onClick: (() -> Void)?
    var radius: CGFloat = Radius.card
    var container: Color = Palette.surface
    var padding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
    @ViewBuilder let content: Content

    var body: some View {
        let card = VStack(alignment: .leading, spacing: 0) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(container, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        if let onClick {
            Button(action: onClick) { card }.buttonStyle(.plain)
        } else {
            card
        }
    }
}

extension EdgeInsets {
    static func all(_ value: CGFloat) -> EdgeInsets {
        EdgeInsets(top: value, leading: value, bottom: value, trailing: value)
    }

    static func vertical(_ value: CGFloat) -> EdgeInsets {
        EdgeInsets(top: value, leading: 0, bottom: value, trailing: 0)
    }
}

/// Savings cards are violet-blue-teal with white text; credit is yellow-amber with dark text.
enum HeroTone {
    case savings, credit

    var gradient: [Color] {
        switch self {
        case .savings: [Palette.heroGradientStart, Palette.heroGradientMid, Palette.heroGradientEnd]
        case .credit: [Palette.creditGradientStart, Palette.creditGradientMid, Palette.creditGradientEnd]
        }
    }

    var glow: Color { self == .savings ? Palette.heroGlow : .white }
}

/// Highlighted card (savings total, credit to pay) over a three-color gradient.
/// `scrim` darkens it from top (0 %) to bottom (80 % black); the screens use it on every tone so
/// the cards look alike, and it is what lets white text sit on the yellow credit tone.
struct HeroCard<Content: View>: View {
    var tone: HeroTone = .savings
    var scrim = false
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                // Diagonal gradient plus two soft glows for depth.
                GeometryReader { proxy in
                    ZStack {
                        LinearGradient(colors: tone.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                        RadialGradient(
                            colors: [tone.glow.opacity(0.30), .clear],
                            center: UnitPoint(x: 0.95, y: 0), startRadius: 0, endRadius: proxy.size.width * 0.7
                        )
                        RadialGradient(
                            colors: [tone.gradient[0].opacity(0.55), .clear],
                            center: UnitPoint(x: 0, y: 1), startRadius: 0, endRadius: proxy.size.width * 0.7
                        )
                        if scrim {
                            LinearGradient(colors: [.clear, Color.black.opacity(0.80)], startPoint: .top, endPoint: .bottom)
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.heroCard, style: .continuous))
    }
}

/// Translucent surface used inside a `HeroCard`.
let heroGlass = Color.white.opacity(0.14)

struct CardDivider: View {
    var color: Color = Palette.dividerSoft

    var body: some View {
        Rectangle().fill(color).frame(height: 1).padding(.vertical, 12)
    }
}

struct IconBadge: View {
    let systemName: String
    let tint: Color
    let container: Color
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.44, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(container, in: RoundedRectangle(cornerRadius: Radius.iconBadge, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct ColorDot: View {
    let color: Color
    var size: CGFloat = 12

    var body: some View {
        Circle().fill(color).frame(width: size, height: size)
    }
}

// MARK: - Selection controls

/// Pill-shaped segmented control. With `fill` every option takes the same width (tabs);
/// without it the control wraps its content (S/ | US$ selector). `onHero` is the dark variant.
struct SegmentedControl<Value: Hashable>: View {
    let options: [(Value, String)]
    let selected: Value
    let onSelect: (Value) -> Void
    var fill = true
    var onHero = false

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                let isSelected = option.0 == selected
                Button { onSelect(option.0) } label: {
                    Text(option.1)
                        .font(OFont.labelLarge)
                        .foregroundStyle(textColor(isSelected))
                        .lineLimit(1)
                        .padding(.horizontal, 14)
                        .frame(maxWidth: fill ? .infinity : nil, minHeight: fill ? 40 : 32)
                        .background(
                            isSelected ? Palette.surface : Color.clear,
                            in: RoundedRectangle(cornerRadius: Radius.pill, style: .continuous)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .frame(maxWidth: fill ? .infinity : nil)
        .background(
            onHero ? Color.white.opacity(0.12) : Palette.neutralSoft,
            in: RoundedRectangle(cornerRadius: Radius.pill, style: .continuous)
        )
        .fixedSize(horizontal: !fill, vertical: false)
    }

    private func textColor(_ isSelected: Bool) -> Color {
        if isSelected { return Palette.ink }
        return onHero ? Palette.onHeroMuted : Palette.muted
    }
}

struct OrbitaChip: View {
    let label: String
    let selected: Bool
    var dotColor: Color?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let dotColor {
                    Circle().fill(selected ? Color.white : dotColor).frame(width: 8, height: 8)
                }
                Text(label)
                    .font(OFont.labelLarge)
                    .foregroundStyle(selected ? Color.white : Palette.ink)
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(selected ? Palette.primary : Palette.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(selected ? Palette.primary : Palette.chipBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Wraps its children onto several lines (chip groups).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(width: bounds.width, subviews: subviews)
        for (index, origin) in result.origins.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        return (CGSize(width: maxX, height: y + rowHeight), origins)
    }
}

struct ChipGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        FlowLayout(spacing: 8) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Label + switch; the whole row toggles.
struct SwitchRow: View {
    let label: String
    @Binding var isOn: Bool
    var labelFont: Font = OFont.bodyMedium
    var labelColor: Color = Palette.ink

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(label).font(labelFont).foregroundStyle(labelColor)
        }
        .tint(Palette.primary)
        .frame(minHeight: 48)
    }
}

// MARK: - Buttons

struct PrimaryButton: View {
    let title: String
    var container: Color = Palette.primary
    var content: Color = .white
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage).font(.system(size: 17, weight: .semibold))
                }
                Text(title).font(OFont.titleMedium)
            }
            .foregroundStyle(content)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(container, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Small pill button with soft background (Transferir, Marcar como pagada…).
struct PillButton: View {
    let title: String
    var systemImage: String?
    var container: Color = Palette.primarySoft
    var content: Color = Palette.primary
    /// Takes all the width it is given (two buttons side by side).
    var fill = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage).font(.system(size: 15, weight: .semibold))
                }
                Text(title).font(OFont.labelLarge).lineLimit(1)
            }
            .foregroundStyle(content)
            .padding(.horizontal, 16)
            .frame(maxWidth: fill ? .infinity : nil, minHeight: 44)
            .background(container, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Non-interactive status chip (due dates, "próximamente").
struct StatusChip: View {
    let text: String
    let container: Color
    let content: Color
    var systemImage: String?

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 12, weight: .semibold))
            }
            Text(text).font(OFont.labelSmall).lineLimit(1)
        }
        .foregroundStyle(content)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(container, in: Capsule())
    }
}

// MARK: - Fields

private struct FieldBox<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 0) { content }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                    .strokeBorder(Palette.outline, lineWidth: 1)
            )
    }
}

struct OrbitaTextField<Trailing: View>: View {
    @Binding var text: String
    var placeholder = ""
    var prefix: String?
    var leadingIcon: String?
    var keyboard: UIKeyboardType = .default
    var isSecure = false
    let trailing: Trailing

    init(
        text: Binding<String>,
        placeholder: String = "",
        prefix: String? = nil,
        leadingIcon: String? = nil,
        keyboard: UIKeyboardType = .default,
        isSecure: Bool = false,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        _text = text
        self.placeholder = placeholder
        self.prefix = prefix
        self.leadingIcon = leadingIcon
        self.keyboard = keyboard
        self.isSecure = isSecure
        self.trailing = trailing()
    }

    var body: some View {
        FieldBox {
            if let leadingIcon {
                Image(systemName: leadingIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.muted)
                    .padding(.trailing, 10)
            }
            if let prefix {
                Text(prefix).font(OFont.bodyLarge).foregroundStyle(Palette.muted).padding(.trailing, 8)
            }
            Group {
                if isSecure {
                    SecureField("", text: $text, prompt: promptText)
                } else {
                    TextField("", text: $text, prompt: promptText)
                }
            }
            .font(OFont.bodyLarge)
            .foregroundStyle(Palette.ink)
            .keyboardType(keyboard)
            .textInputAutocapitalization(keyboard == .emailAddress || isSecure ? .never : .sentences)
            .autocorrectionDisabled(keyboard == .emailAddress || isSecure)
            trailing
        }
    }

    private var promptText: Text {
        Text(placeholder).font(OFont.bodyLarge).foregroundStyle(Palette.switchOff)
    }
}

/// Field that opens a menu to pick one of `options`. `detail` is a secondary text shown on the
/// right (e.g. the account balance) and `leading` an icon or color dot per option.
struct DropdownField<Option: Hashable, Leading: View>: View {
    let options: [Option]
    let selected: Option
    let onSelect: (Option) -> Void
    let label: (Option) -> String
    var detail: ((Option) -> String)?
    @ViewBuilder let leading: (Option) -> Leading

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button {
                    onSelect(option)
                } label: {
                    let text = detail.map { "\(label(option))  ·  \($0(option))" } ?? label(option)
                    if option == selected {
                        Label(text, systemImage: "checkmark")
                    } else {
                        Text(text)
                    }
                }
            }
        } label: {
            FieldBox {
                leading(selected).padding(.trailing, 10)
                Text(label(selected))
                    .font(OFont.bodyLarge)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let detail {
                    Text(detail(selected))
                        .font(OFont.bodySmall)
                        .foregroundStyle(Palette.muted)
                        .padding(.leading, 8)
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.muted)
                    .padding(.leading, 8)
            }
        }
        .buttonStyle(.plain)
    }
}

/// Multi-line text box with an optional character counter.
struct OrbitaTextArea: View {
    @Binding var text: String
    var placeholder = ""
    var maxLength: Int?
    var minHeight: CGFloat = 96
    /// Called when the box gets the focus (the amount keypad closes then).
    var onFocus: (() -> Void)?

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(OFont.bodyLarge)
                        .foregroundStyle(Palette.switchOff)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .font(OFont.bodyLarge)
                    .foregroundStyle(Palette.ink)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: minHeight)
                    .focused($focused)
                    .onChange(of: focused) { _, isFocused in
                        if isFocused { onFocus?() }
                    }
                    .onChange(of: text) { _, newValue in
                        if let maxLength, newValue.count > maxLength {
                            text = String(newValue.prefix(maxLength))
                        }
                    }
            }
            if let maxLength {
                Text("\(text.count)/\(maxLength)")
                    .font(OFont.labelSmall)
                    .foregroundStyle(Palette.muted)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                .strokeBorder(Palette.outline, lineWidth: 1)
        )
    }
}

/// Read-only field that opens a picker (date, account…). Pickers are not wired in the mockup.
struct PickerField: View {
    let value: String
    var leadingIcon: String? = "calendar"
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            FieldBox {
                if let leadingIcon {
                    Image(systemName: leadingIcon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.muted)
                        .padding(.trailing, 10)
                }
                Text(value)
                    .font(OFont.bodyLarge)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
}

/// Big editable amount with its currency symbol (38 pt / 800).
struct AmountInput: View {
    let symbol: String
    @Binding var text: String
    var color: Color = Palette.ink
    var font: Font = OFont.displaySmall

    var body: some View {
        HStack(spacing: 10) {
            Text(symbol).font(font).foregroundStyle(Palette.muted)
            TextField(
                "",
                text: $text,
                prompt: Text("0.00").font(font).foregroundStyle(Palette.chipBorder)
            )
            .font(font)
            .foregroundStyle(color)
            .keyboardType(.decimalPad)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Two-column text row used in summaries.
struct LabelValueRow: View {
    let label: String
    let value: String
    var labelColor: Color = Palette.muted
    var valueColor: Color = Palette.ink
    var valueFont: Font = OFont.titleSmall

    var body: some View {
        HStack(spacing: 12) {
            Text(label).font(OFont.bodyMedium).foregroundStyle(labelColor)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(value).font(valueFont).foregroundStyle(valueColor)
        }
    }
}

struct HeroLabel: View {
    let text: String
    var color: Color = .white

    init(_ text: String, color: Color = .white) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text).font(OFont.labelMedium).foregroundStyle(color)
    }
}

struct HeroAmount: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(OFont.displaySmall)
            .foregroundStyle(Palette.onHero)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

// MARK: - Dialogs and states

extension View {
    /// Confirmation for destructive actions (logical delete, archive).
    func confirmDialog(
        _ title: String,
        isPresented: Binding<Bool>,
        message: String,
        confirmLabel: String,
        onConfirm: @escaping () -> Void
    ) -> some View {
        alert(title, isPresented: isPresented) {
            Button("Cancelar", role: .cancel) {}
            Button(confirmLabel, role: .destructive, action: onConfirm)
        } message: {
            Text(message)
        }
    }
}

/// Empty / error placeholder with an optional action.
struct StateMessage: View {
    let systemImage: String
    let title: String
    var message: String?
    var actionLabel: String?
    var onAction: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            IconBadge(systemName: systemImage, tint: Palette.neutral, container: Palette.neutralSoft, size: 56)
            Text(title)
                .font(OFont.titleMedium)
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .padding(.top, 14)
            if let message {
                Text(message)
                    .font(OFont.bodyMedium)
                    .foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
            }
            if let actionLabel {
                PillButton(title: actionLabel, action: onAction).padding(.top, 16)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

/// Skeleton block for loading states.
struct SkeletonBlock: View {
    var height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
            .fill(Palette.outline)
            .frame(maxWidth: .infinity)
            .frame(height: height)
    }
}

/// Card with a dashed border (Nueva cuenta).
struct DashedButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage).font(.system(size: 17, weight: .semibold))
                Text(title).font(OFont.labelLarge)
            }
            .foregroundStyle(Palette.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(Palette.chipBorder, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
