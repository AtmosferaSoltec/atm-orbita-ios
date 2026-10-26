import SwiftUI

/// Row of the movement lists: income (↗, up), expense (↙, down) or transfer (⇄).
struct EntryRow: View {
    let entry: Entry
    let onClick: () -> Void

    var body: some View {
        switch entry {
        case .movement(let movement):
            let income = movement.kind == .income
            let redundant = movement.description.isEmpty || movement.description == movement.category.name
            layout(
                icon: income ? "arrow.up.right" : "arrow.down.left",
                tint: income ? Palette.income : Palette.expense,
                container: income ? Palette.incomeSoft : Palette.expenseSoft,
                title: movement.description.isEmpty ? movement.category.name : movement.description,
                subtitle: [
                    redundant ? (income ? "Ingreso" : "Egreso") : movement.category.name,
                    movement.account.name,
                    formatDayMonth(movement.date),
                ].joined(separator: " · "),
                amount: formatSignedMoney(movement.amount, movement.account.currency, positive: income),
                amountColor: income ? Palette.income : Palette.expense
            )
        case .transfer(let transfer):
            let out = formatMoney(transfer.fromAmount, transfer.from.currency)
            let amount = transfer.from.currency == transfer.to.currency
                ? out : "\(out) → \(formatMoney(transfer.toAmount, transfer.to.currency))"
            layout(
                icon: "arrow.left.arrow.right",
                tint: Palette.transfer,
                container: Palette.transferSoft,
                title: transfer.note.isEmpty ? "Transferencia" : transfer.note,
                subtitle: "\(transfer.from.name) → \(transfer.to.name) · \(formatDayMonth(transfer.date))",
                amount: amount,
                amountColor: Palette.neutral
            )
        }
    }

    private func layout(
        icon: String, tint: Color, container: Color,
        title: String, subtitle: String, amount: String, amountColor: Color
    ) -> some View {
        Button(action: onClick) {
            HStack(spacing: 12) {
                IconBadge(systemName: icon, tint: tint, container: container, size: 40)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(OFont.titleSmall)
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(amount)
                            .font(OFont.titleSmall)
                            .foregroundStyle(amountColor)
                            .lineLimit(1)
                    }
                    Text(subtitle)
                        .font(OFont.bodySmall)
                        .foregroundStyle(Palette.muted)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// White card that stacks `EntryRow`s separated by soft dividers.
struct EntryList: View {
    let entries: [Entry]
    let onEntryClick: (Entry) -> Void

    var body: some View {
        OrbitaCard(padding: .vertical(4)) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                if index > 0 {
                    Rectangle()
                        .fill(Palette.dividerSoft)
                        .frame(height: 1)
                        .padding(.leading, 66)
                        .padding(.trailing, 14)
                }
                EntryRow(entry: entry) { onEntryClick(entry) }
            }
        }
    }
}

/// Heading under the tabs of the new movement / transfer forms: says what is being registered.
struct FormIntro: View {
    let systemName: String
    let tint: Color
    let container: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            IconBadge(systemName: systemName, tint: tint, container: container)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(OFont.titleMedium).foregroundStyle(Palette.ink)
                Text(subtitle).font(OFont.bodySmall).foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }
}

/// Month stepper: ‹ goes to the previous month, › to the next. An arrow at its limit is dimmed.
struct MonthSelector: View {
    let month: LocalDay
    let onPrevious: () -> Void
    let onNext: () -> Void
    var canGoPrevious = true
    var canGoNext = true

    var body: some View {
        OrbitaCard(padding: .all(10)) {
            HStack(spacing: 0) {
                CircleIconButton(
                    systemName: "chevron.left", label: "Mes anterior", container: Palette.background,
                    enabled: canGoPrevious, action: onPrevious
                )
                VStack(spacing: 0) {
                    Text(formatMonthYear(month)).font(OFont.titleSmall).foregroundStyle(Palette.ink).lineLimit(1)
                    Text("1 – \(formatDayMonth(month.lastOfMonth))").font(OFont.bodySmall).foregroundStyle(Palette.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 10)
                CircleIconButton(
                    systemName: "chevron.right", label: "Mes siguiente", container: Palette.background,
                    enabled: canGoNext, action: onNext
                )
            }
        }
    }
}

/// Inicio · Cuentas · [ + ] · Reportes · Crédito (v1.1).
struct OrbitaBottomBar: View {
    let current: BottomTab
    let onSelect: (BottomTab) -> Void
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Palette.outline).frame(height: 1)
            HStack(spacing: 0) {
                item(.home, "house", "Inicio")
                item(.accounts, "wallet.bifold", "Cuentas")
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 54, height: 54)
                        .background(Palette.primary, in: Circle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Nuevo movimiento")
                item(.reports, "chart.bar", "Reportes")
                item(.credit, "creditcard", "Crédito")
            }
            .frame(height: 72)
            .padding(.horizontal, 8)
        }
        .background(Palette.surface.ignoresSafeArea(edges: .bottom))
    }

    private func item(_ tab: BottomTab, _ icon: String, _ title: String) -> some View {
        let selected = tab == current
        let color = selected ? Palette.primary : Palette.muted
        return Button { onSelect(tab) } label: {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 21, weight: .medium))
                Text(title).font(OFont.labelSmall).lineLimit(1)
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Dark bar with white text over the foot of the screen: a form that cannot be saved yet, or a
/// failed operation. A newer message replaces the one on screen.
struct ToastHost: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        ZStack(alignment: .bottom) {
            if let toast = app.toast {
                Text(toast.text)
                    .font(OFont.bodyMedium)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.ink, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 88)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.2), value: app.toastId)
        .task(id: app.toastId) {
            let id = app.toastId
            guard app.toast != nil else { return }
            try? await Task.sleep(for: .seconds(4))
            app.clearToast(id: id)
        }
    }
}

/// Shown instead of a form that cannot be filled yet (e.g. a movement without any account).
struct NoticeScreen: View {
    let barTitle: String
    let title: String
    let message: String
    let onClose: () -> Void

    var body: some View {
        ScreenScaffold(header: {
            ModalTopBar(title: barTitle, icon: .close, onNavigate: onClose)
        }) {
            StateMessage(systemImage: "exclamationmark.circle", title: title, message: message)
        }
    }
}

/// `content` once its data is there; nothing while it arrives. If reading failed, a message
/// offers to try again, with a bar to leave (`onClose`) when the screen is not a tab.
struct Loaded<T, Content: View>: View {
    let load: Load<T>
    let onRetry: () -> Void
    var onClose: (() -> Void)?
    @ViewBuilder let content: (T) -> Content

    var body: some View {
        switch load {
        case .ready(let value):
            content(value)
        case .loading:
            Palette.background.ignoresSafeArea()
        case .failed:
            ScreenScaffold(header: {
                if let onClose {
                    ModalTopBar(title: "", icon: .close, onNavigate: onClose)
                }
            }) {
                StateMessage(
                    systemImage: "exclamationmark.circle",
                    title: "No se pudo cargar",
                    message: "Revisa tu conexión e inténtalo de nuevo.",
                    actionLabel: "Reintentar",
                    onAction: onRetry
                )
            }
        }
    }
}
