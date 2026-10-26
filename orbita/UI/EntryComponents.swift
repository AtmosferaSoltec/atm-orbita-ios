import SwiftUI

/// Row of the movement lists: income (↙), expense (↗) or transfer (⇄).
struct EntryRow: View {
    let entry: MockEntry
    let onClick: () -> Void

    var body: some View {
        switch entry {
        case .movement(let movement):
            let income = movement.kind == .income
            let redundant = movement.description.isEmpty || movement.description == movement.category.name
            layout(
                icon: income ? "arrow.down.left" : "arrow.up.right",
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
                tint: Palette.neutral,
                container: Palette.neutralSoft,
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
    let entries: [MockEntry]
    let onEntryClick: (MockEntry) -> Void

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

enum BottomTab: Hashable { case home, accounts, reports, credit }

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
