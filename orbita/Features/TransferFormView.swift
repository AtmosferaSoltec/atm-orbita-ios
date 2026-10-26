import SwiftUI

private enum TransferTab { case expense, income, transfer }

/// Transfer between two own accounts; with different currencies out, rate and in are linked.
struct TransferFormView: View {
    var from: MockAccount
    var to: MockAccount
    var editing: MockTransfer?
    let onClose: () -> Void
    let onSave: () -> Void
    var onOpenMovement: () -> Void = {}
    var onDelete: () -> Void = {}

    @State private var out: String
    @State private var rate: String
    @State private var incoming: String
    @State private var note: String
    @State private var confirmDelete = false
    private let referenceRate: Decimal

    init(
        editing: MockTransfer? = nil,
        onClose: @escaping () -> Void,
        onSave: @escaping () -> Void,
        onOpenMovement: @escaping () -> Void = {},
        onDelete: @escaping () -> Void = {}
    ) {
        let from = editing?.from ?? SampleData.dollarAccount
        let to = editing?.to ?? SampleData.debitAccount
        self.from = from
        self.to = to
        self.editing = editing
        self.onClose = onClose
        self.onSave = onSave
        self.onOpenMovement = onOpenMovement
        self.onDelete = onDelete

        let reference: Decimal
        if from.currency == to.currency {
            reference = 1
        } else if from.currency == USD {
            reference = SampleData.usdToPen
        } else {
            reference = (1 / SampleData.usdToPen).rounded(scale: 6)
        }
        referenceRate = reference
        _out = State(initialValue: plainAmount(editing?.fromAmount ?? D("20.00")))
        _rate = State(initialValue: formatRate(reference))
        _incoming = State(initialValue: plainAmount(editing?.toAmount ?? D("20.00") * reference))
        _note = State(initialValue: editing?.note ?? "")
    }

    private var sameCurrency: Bool { from.currency == to.currency }

    var body: some View {
        let outAmount = parsePositiveDecimal(out) ?? 0
        let inAmount = sameCurrency ? outAmount : (parsePositiveDecimal(incoming) ?? 0)
        let fromAfter = from.balance - outAmount
        let toAfter = to.balance + inAmount

        ScreenScaffold {
            ModalTopBar(
                title: editing != nil ? "Editar transferencia" : "Transferir",
                icon: .close,
                onNavigate: onClose
            ) {
                if editing != nil {
                    CircleIconButton(
                        systemName: "trash", label: "Eliminar",
                        container: Palette.expenseSoft, tint: Palette.expense
                    ) { confirmDelete = true }
                }
            }
        } footer: {
            PrimaryButton(title: editing != nil ? "Guardar cambios" : "Guardar transferencia", action: onSave)
        } content: {
            if editing == nil {
                SegmentedControl(
                    options: [
                        (TransferTab.expense, "Egreso"),
                        (TransferTab.income, "Ingreso"),
                        (TransferTab.transfer, "Transferencia"),
                    ],
                    selected: .transfer,
                    onSelect: { if $0 != .transfer { onOpenMovement() } }
                )
                .padding(.bottom, 14)
            }

            ZStack {
                VStack(spacing: 10) {
                    AccountSlot(label: "Desde", account: from)
                    AccountSlot(label: "Hacia", account: to)
                }
                Image(systemName: "arrow.down")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.neutral)
                    .frame(width: 36, height: 36)
                    .background(Palette.surface, in: Circle())
                    .overlay(Circle().strokeBorder(Palette.outline, lineWidth: 1))
            }

            OrbitaCard {
                CardLabel("Monto que sale")
                AmountInput(symbol: currencySymbol(from.currency), text: outBinding)
                // Same currency: no exchange rate, in = out.
                if !sameCurrency {
                    CardDivider()
                    HStack {
                        CardLabel("Tipo de cambio · editable")
                        Spacer()
                        CardLabel("Referencia")
                    }
                    HStack(spacing: 8) {
                        Text("1 \(currencySymbol(from.currency)) = \(currencySymbol(to.currency))")
                            .font(OFont.titleMedium)
                            .foregroundStyle(Palette.ink)
                        TextField("", text: rateBinding)
                            .font(OFont.titleMedium)
                            .foregroundStyle(Palette.ink)
                            .keyboardType(.decimalPad)
                            .frame(width: 64)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                Palette.neutralSoft,
                                in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                            )
                        Spacer()
                        Text("manual \(formatRate(referenceRate))")
                            .font(OFont.bodySmall)
                            .foregroundStyle(Palette.muted)
                    }
                    .padding(.top, 6)
                    CardDivider()
                    CardLabel("Monto que entra · editable")
                    AmountInput(
                        symbol: currencySymbol(to.currency), text: incomingBinding, font: OFont.headlineMedium
                    )
                }
            }
            .padding(.top, 12)

            if !sameCurrency {
                HintText("Si el banco aplicó otro cambio, edita el tipo de cambio o el monto que entra y el otro valor se recalcula.")
                    .padding(.top, 10)
                    .padding(.horizontal, 4)
            }

            SectionTitle(text: "Saldos después de transferir")
            OrbitaCard {
                LabelValueRow(
                    label: from.name,
                    value: formatMoney(fromAfter, from.currency),
                    valueColor: fromAfter.isNegative ? Palette.expense : Palette.ink
                )
                LabelValueRow(label: to.name, value: formatMoney(toAfter, to.currency))
                    .padding(.top, 10)
            }
            // Warn, but do not block.
            if fromAfter.isNegative {
                HintText("El saldo de \(from.name) quedaría en negativo.", color: Palette.expense)
                    .padding(.top, 8)
                    .padding(.leading, 4)
            }

            FieldLabel("Fecha")
            PickerField(value: formatDate(editing?.date ?? SampleData.today))

            FieldLabel("Nota (opcional)")
            OrbitaTextField(text: $note, placeholder: "Ej. Cambio de dólares")
        }
        .confirmDialog(
            "¿Eliminar esta transferencia?",
            isPresented: $confirmDelete,
            message: "Dejará de contar en tus saldos y reportes.",
            confirmLabel: "Eliminar",
            onConfirm: onDelete
        )
    }

    // The three fields are linked, so each one updates the others only when the user edits it.

    private var outBinding: Binding<String> {
        Binding(get: { out }, set: { newValue in
            out = newValue
            recalculateIncoming()
        })
    }

    private var rateBinding: Binding<String> {
        Binding(get: { rate }, set: { newValue in
            rate = newValue
            recalculateIncoming()
        })
    }

    private var incomingBinding: Binding<String> {
        Binding(get: { incoming }, set: { newValue in
            incoming = newValue
            // rate = in ÷ out (stored with 6 decimals, shown with 2 to 4)
            if let i = parsePositiveDecimal(newValue), let o = parsePositiveDecimal(out) {
                rate = formatRate((i / o).rounded(scale: 6))
            }
        })
    }

    // in = round(out × rate, 2)
    private func recalculateIncoming() {
        guard let o = parsePositiveDecimal(out), let r = parsePositiveDecimal(rate) else { return }
        incoming = plainAmount(o * r)
    }
}

private struct CardLabel: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text).font(OFont.labelMedium).foregroundStyle(Palette.muted)
    }
}

/// "Desde" / "Hacia" card; tapping it opens the account selector (not wired in the mockup).
private struct AccountSlot: View {
    let label: String
    let account: MockAccount

    var body: some View {
        OrbitaCard(onClick: {}) {
            HStack(spacing: 12) {
                IconBadge(systemName: account.icon, tint: Palette.primary, container: Palette.primarySoft, size: 40)
                VStack(alignment: .leading, spacing: 0) {
                    CardLabel(label)
                    Text(account.name).font(OFont.titleSmall).foregroundStyle(Palette.ink).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text("Saldo \(formatMoney(account.balance, account.currency))")
                    .font(OFont.bodySmall)
                    .foregroundStyle(Palette.muted)
            }
        }
    }
}

#Preview("Transferir") { TransferFormView(onClose: {}, onSave: {}) }

#Preview("Editar transferencia") {
    if case .transfer(let transfer) = SampleData.entries[3] {
        TransferFormView(editing: transfer, onClose: {}, onSave: {})
    }
}
