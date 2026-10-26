import SwiftUI

private enum FormTab { case expense, income, transfer }

/// New movement flow: switches in place between the movement form and the transfer form.
struct NewEntryFlowView: View {
    let initialCredit: Bool
    let onClose: () -> Void
    @State private var isTransfer: Bool

    init(credit: Bool, startsAsTransfer: Bool, onClose: @escaping () -> Void) {
        initialCredit = credit
        self.onClose = onClose
        _isTransfer = State(initialValue: startsAsTransfer)
    }

    var body: some View {
        if isTransfer {
            TransferFormView(onClose: onClose, onSave: onClose, onOpenMovement: { isTransfer = false })
        } else {
            MovementFormView(
                initialCredit: initialCredit, onClose: onClose, onSave: onClose,
                onOpenTransfer: { isTransfer = true }
            )
        }
    }
}

/// New movement, or edit/delete when `editing` is set. With "Compra con tarjeta de crédito" on,
/// it saves a pending purchase instead of a movement (v1.1).
struct MovementFormView: View {
    @Environment(AppModel.self) private var model
    var editing: MockMovement?
    var initialCredit = false
    let onClose: () -> Void
    let onSave: () -> Void
    var onOpenTransfer: () -> Void = {}
    var onDelete: () -> Void = {}

    @State private var kind: MovementKind
    @State private var amount: String
    @State private var account: MockAccount
    @State private var category: MockCategory
    @State private var details: String
    @State private var credit: Bool
    @State private var confirmDelete = false

    init(
        editing: MockMovement? = nil,
        initialCredit: Bool = false,
        onClose: @escaping () -> Void,
        onSave: @escaping () -> Void,
        onOpenTransfer: @escaping () -> Void = {},
        onDelete: @escaping () -> Void = {}
    ) {
        self.editing = editing
        self.initialCredit = initialCredit
        self.onClose = onClose
        self.onSave = onSave
        self.onOpenTransfer = onOpenTransfer
        self.onDelete = onDelete
        let initialKind = editing?.kind ?? .expense
        _kind = State(initialValue: initialKind)
        _amount = State(initialValue: editing.map { plainAmount($0.amount) } ?? "45.52")
        _account = State(initialValue: editing?.account ?? SampleData.debitAccount)
        _category = State(initialValue: editing?.category ?? SampleData.categories(of: initialKind)[0])
        _details = State(initialValue: editing?.description ?? "Almuerzo con equipo")
        _credit = State(initialValue: initialCredit)
    }

    private var isExpense: Bool { kind == .expense }
    private var onCredit: Bool { credit && isExpense && editing == nil }

    var body: some View {
        // The list may hold a newer copy of the account (e.g. savings switch changed).
        let selectedAccount = model.accounts.first { $0.id == account.id } ?? account
        let symbol = currencySymbol(onCredit ? PEN : account.currency)

        ScreenScaffold {
            ModalTopBar(
                title: editing != nil ? "Editar movimiento" : "Nuevo movimiento",
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
            PrimaryButton(title: saveTitle, action: onSave)
        } content: {
            SegmentedControl(
                options: tabs,
                selected: isExpense ? FormTab.expense : FormTab.income,
                onSelect: { tab in
                    switch tab {
                    case .transfer:
                        onOpenTransfer()
                    default:
                        kind = tab == .expense ? .expense : .income
                        // Changing the type selects its first category.
                        category = SampleData.categories(of: kind)[0]
                    }
                }
            )

            OrbitaCard {
                Text("Monto").font(OFont.labelMedium).foregroundStyle(Palette.muted)
                AmountInput(symbol: symbol, text: $amount, color: isExpense ? Palette.ink : Palette.income)
                    .padding(.top, 4)
            }
            .padding(.top, 14)

            if !onCredit {
                FieldLabel(isExpense ? "Sale de la cuenta" : "Ingresa a la cuenta")
                DropdownField(
                    options: model.accounts,
                    selected: selectedAccount,
                    onSelect: { account = $0 },
                    label: { $0.name },
                    detail: { formatMoney($0.balance, $0.currency) }
                ) { option in
                    Image(systemName: option.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.primary)
                }
            }

            FieldLabel("Categoría")
            DropdownField(
                options: SampleData.categories(of: kind),
                selected: category,
                onSelect: { category = $0 },
                label: { $0.name }
            ) { option in
                ColorDot(color: option.color)
            }

            FieldLabel("Descripción")
            OrbitaTextArea(text: $details, placeholder: "Ej. Almuerzo con equipo", maxLength: 500)

            FieldLabel("Fecha")
            PickerField(value: formatDate(editing?.date ?? SampleData.today))

            // Only for new expenses (v1.1)
            if isExpense && editing == nil {
                OrbitaCard {
                    SwitchRow(label: "Compra con tarjeta de crédito", isOn: $credit, labelFont: OFont.titleSmall)
                    HintText("No descuenta de tus cuentas. Queda pendiente hasta que la pagues.")
                    if credit {
                        FieldLabel("Fecha límite de pago")
                        PickerField(value: formatDate(Cal.adding(days: 13, to: SampleData.today)))
                    }
                }
                .padding(.top, 18)
            }
        }
        .confirmDialog(
            "¿Eliminar este movimiento?",
            isPresented: $confirmDelete,
            message: "Dejará de contar en tus saldos y reportes.",
            confirmLabel: "Eliminar",
            onConfirm: onDelete
        )
    }

    private var tabs: [(FormTab, String)] {
        var tabs: [(FormTab, String)] = [(.expense, "Egreso"), (.income, "Ingreso")]
        // An existing movement cannot become a transfer.
        if editing == nil { tabs.append((.transfer, "Transferencia")) }
        return tabs
    }

    private var saveTitle: String {
        if editing != nil { return "Guardar cambios" }
        if onCredit { return "Guardar compra pendiente" }
        return isExpense ? "Guardar egreso" : "Guardar ingreso"
    }
}

/// Full list of movements and transfers with search and filters.
/// Not in the original mockups (docs/05, section 9).
struct MovementsView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var accountID: String?

    private var entries: [MockEntry] {
        SampleData.entries.filter { entry in
            let text: String
            let inAccount: Bool
            switch entry {
            case .movement(let movement):
                text = movement.description
                inAccount = accountID == nil || movement.account.id == accountID
            case .transfer(let transfer):
                text = transfer.note
                inAccount = accountID == nil || transfer.from.id == accountID || transfer.to.id == accountID
            }
            let trimmed = query.trimmingCharacters(in: .whitespaces)
            return inAccount && (trimmed.isEmpty || text.localizedCaseInsensitiveContains(trimmed))
        }
    }

    var body: some View {
        let entries = entries
        let months = Dictionary(grouping: entries) { Cal.firstOfMonth($0.date) }
            .sorted { $0.key > $1.key }

        ScreenScaffold {
            ModalTopBar(title: "Movimientos", icon: .back) { model.pop() }
        } content: {
            OrbitaTextField(text: $query, placeholder: "Buscar por descripción", leadingIcon: "magnifyingglass")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    OrbitaChip(label: "Todas las cuentas", selected: accountID == nil) { accountID = nil }
                    ForEach(model.accounts) { account in
                        OrbitaChip(label: account.name, selected: accountID == account.id) { accountID = account.id }
                    }
                }
            }
            .padding(.top, 12)

            HStack(spacing: 8) {
                PillButton(
                    title: "Categoría: todas", systemImage: "tag",
                    container: Palette.surface, content: Palette.neutral
                )
                PillButton(
                    title: "Fechas: todas", systemImage: "calendar",
                    container: Palette.surface, content: Palette.neutral
                )
            }
            .padding(.top, 8)

            if entries.isEmpty {
                StateMessage(systemImage: "magnifyingglass", title: "No hay movimientos con estos filtros")
            }
            ForEach(months, id: \.key) { month, monthEntries in
                Text(formatMonthYear(month))
                    .font(OFont.labelMedium)
                    .foregroundStyle(Palette.muted)
                    .padding(.top, 20)
                    .padding(.bottom, 8)
                    .padding(.leading, 4)
                EntryList(entries: monthEntries) { model.open($0) }
            }
        }
    }
}

#Preview("Nuevo movimiento") {
    MovementFormView(initialCredit: false, onClose: {}, onSave: {}).environment(AppModel())
}

#Preview("Compra con tarjeta") {
    MovementFormView(initialCredit: true, onClose: {}, onSave: {}).environment(AppModel())
}

#Preview("Movimientos") { MovementsView().environment(AppModel()) }
