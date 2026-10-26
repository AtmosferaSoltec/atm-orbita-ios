import SwiftUI

/// Manage income and expense categories. Not in the original mockups (docs/05, section 9).
struct CategoriesView: View {
    @Environment(AppModel.self) private var model
    @State private var kind = MovementKind.expense

    var body: some View {
        ScreenScaffold {
            ModalTopBar(title: "Categorías", icon: .back) { model.pop() }
        } footer: {
            PrimaryButton(
                title: "Nueva categoría",
                container: Palette.primarySoft, content: Palette.primary, systemImage: "plus"
            ) { model.push(.categoryForm(category: nil, kind: kind)) }
        } content: {
            SegmentedControl(
                options: [(MovementKind.expense, "Egresos"), (MovementKind.income, "Ingresos")],
                selected: kind,
                onSelect: { kind = $0 }
            )
            OrbitaCard(padding: .vertical(4)) {
                let categories = SampleData.categories(of: kind)
                ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                    if index > 0 {
                        Rectangle().fill(Palette.dividerSoft).frame(height: 1).padding(.horizontal, 16)
                    }
                    Button { model.push(.categoryForm(category: category, kind: category.kind)) } label: {
                        HStack(spacing: 14) {
                            ColorDot(color: category.color, size: 14)
                            Text(category.name)
                                .font(OFont.titleSmall)
                                .foregroundStyle(Palette.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "pencil")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Palette.muted)
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 56)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 12)
        }
    }
}

/// New category (`category` = nil) or rename / recolor / archive an existing one.
struct CategoryFormView: View {
    @Environment(AppModel.self) private var model
    let category: MockCategory?

    @State private var name: String
    @State private var kind: MovementKind
    @State private var color: Color
    @State private var confirmArchive = false

    init(category: MockCategory?, initialKind: MovementKind) {
        self.category = category
        _name = State(initialValue: category?.name ?? "")
        _kind = State(initialValue: category?.kind ?? initialKind)
        _color = State(initialValue: category?.color ?? Palette.categoryPalette[0])
    }

    private var editing: Bool { category != nil }

    var body: some View {
        ScreenScaffold {
            ModalTopBar(
                title: editing ? "Editar categoría" : "Nueva categoría",
                icon: editing ? .back : .close
            ) { model.pop() }
        } footer: {
            PrimaryButton(title: editing ? "Guardar cambios" : "Guardar categoría") { model.pop() }
        } content: {
            FieldLabel("Nombre")
            OrbitaTextField(text: $name, placeholder: "Ej. Mascotas")

            // The kind (income / expense) is fixed once the category exists.
            if !editing {
                FieldLabel("Tipo")
                ChipGroup {
                    OrbitaChip(label: "Egreso", selected: kind == .expense) { kind = .expense }
                    OrbitaChip(label: "Ingreso", selected: kind == .income) { kind = .income }
                }
            }

            FieldLabel("Color")
            HStack(spacing: 6) {
                ForEach(Array(Palette.categoryPalette.enumerated()), id: \.offset) { index, option in
                    ColorSwatch(color: option, selected: option == color, label: "Color \(index + 1)") {
                        color = option
                    }
                }
            }

            if editing {
                PillButton(
                    title: "Archivar categoría", systemImage: "archivebox",
                    container: Palette.expenseSoft, content: Palette.expense
                ) { confirmArchive = true }
                    .padding(.top, 28)
                HintText("Deja de aparecer al registrar movimientos, pero los anteriores se conservan.")
                    .padding(.top, 8)
            }
        }
        .confirmDialog(
            "¿Archivar esta categoría?",
            isPresented: $confirmArchive,
            message: "Deja de aparecer al registrar movimientos, pero los anteriores se conservan.",
            confirmLabel: "Archivar",
            onConfirm: { model.pop() }
        )
    }
}

private struct ColorSwatch: View {
    let color: Color
    let selected: Bool
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 30, height: 30)
                .frame(width: 44, height: 44)
                .overlay(Circle().strokeBorder(selected ? color : Color.clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

#Preview("Categorías") { CategoriesView().environment(AppModel()) }
#Preview("Nueva categoría") { CategoryFormView(category: nil, initialKind: .expense).environment(AppModel()) }
