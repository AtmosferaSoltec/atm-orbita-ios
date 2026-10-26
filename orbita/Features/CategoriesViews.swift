import SwiftUI

/// Manage income and expense categories.
struct CategoriesView: View {
    @Environment(AppModel.self) private var app
    @State private var loader = Loader<[Category]>()
    @State private var kind = MovementKind.expense

    var body: some View {
        Loaded(load: loader.state, onRetry: { loader.retry() }, onClose: { app.pop() }) { categories in
            ScreenScaffold(header: {
                ModalTopBar(title: "Categorías", icon: .back, onNavigate: { app.pop() })
            }, footer: {
                PrimaryButton(
                    title: "Nueva categoría", container: Palette.primarySoft, content: Palette.primary,
                    systemImage: "plus"
                ) { app.push(.categoryForm(category: nil, kind: kind)) }
            }) {
                SegmentedControl(
                    options: [(MovementKind.expense, "Egresos"), (.income, "Ingresos")],
                    selected: kind,
                    onSelect: { kind = $0 }
                )
                OrbitaCard(padding: .vertical(4)) {
                    let shown = categories.filter { $0.kind == kind }
                    ForEach(Array(shown.enumerated()), id: \.element.id) { index, category in
                        if index > 0 {
                            Rectangle().fill(Palette.dividerSoft).frame(height: 1).padding(.horizontal, 16)
                        }
                        Button { app.push(.categoryForm(category: category, kind: category.kind)) } label: {
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
        .task(id: [app.revision, loader.attempt]) { await loader.run { try await app.env.categories.categories() } }
    }
}

/// New category (`category` = nil) or rename / recolor / archive an existing one.
struct CategoryFormScreen: View {
    @Environment(AppModel.self) private var app
    let category: Category?
    let initialKind: MovementKind

    /// Only to tell a repeated name before saving; the API checks it again.
    @State private var existing: [Category] = []
    @State private var loader = Loader<[Category]>()

    @State private var name: String
    @State private var kind: MovementKind
    @State private var colorHex: String
    @State private var confirmArchive = false
    // Set when saving a repeated name; shown under the field until the name or the kind changes.
    @State private var nameTaken = false

    init(category: Category?, initialKind: MovementKind) {
        self.category = category
        self.initialKind = initialKind
        _name = State(initialValue: category?.name ?? "")
        _kind = State(initialValue: category?.kind ?? initialKind)
        _colorHex = State(initialValue: (category?.colorHex ?? Palette.categoryPaletteHex[0]).uppercased())
    }

    private var editing: Bool { category != nil }
    private var route: Route { .categoryForm(category: category, kind: initialKind) }

    // Unique per kind, ignoring case and accents; a category never clashes with itself.
    private var isTaken: Bool {
        let key = normalizeName(name)
        return existing.contains { $0.kind == kind && $0.id != category?.id && normalizeName($0.name) == key }
    }

    var body: some View {
        ScreenScaffold(header: {
            ModalTopBar(
                title: editing ? "Editar categoría" : "Nueva categoría",
                icon: editing ? .back : .close,
                onNavigate: { app.pop() }
            )
        }, footer: {
            PrimaryButton(title: editing ? "Guardar cambios" : "Guardar categoría", action: save)
        }) {
            FieldLabel("Nombre")
            OrbitaTextField(text: $name, placeholder: "Ej. Mascotas")
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                        .strokeBorder(Palette.expense, lineWidth: nameTaken ? 1.5 : 0)
                )
                .onChange(of: name) { _, _ in nameTaken = false }
            // The one error shown under its field instead of in the validation notice.
            if nameTaken {
                HintText(UiMessage.failed(.nameTaken).text, color: Palette.expense)
                    .padding(.top, 6)
                    .padding(.leading, 4)
            }

            // The kind (income / expense) is fixed once the category exists.
            if !editing {
                FieldLabel("Tipo")
                ChipGroup {
                    OrbitaChip(label: "Egreso", selected: kind == .expense) {
                        kind = .expense
                        nameTaken = false
                    }
                    OrbitaChip(label: "Ingreso", selected: kind == .income) {
                        kind = .income
                        nameTaken = false
                    }
                }
            }

            FieldLabel("Color")
            HStack(spacing: 6) {
                ForEach(Array(Palette.categoryPaletteHex.enumerated()), id: \.offset) { index, hex in
                    ColorSwatch(color: Color(categoryHex: hex), selected: hex == colorHex, label: "Color \(index + 1)") {
                        colorHex = hex
                    }
                }
            }

            if editing {
                PillButton(
                    title: "Archivar categoría", systemImage: "archivebox",
                    container: Palette.expenseSoft, content: Palette.expense
                ) { confirmArchive = true }
                .padding(.top, 28)
                HintText("Deja de aparecer al registrar movimientos, pero los anteriores se conservan.").padding(.top, 8)
            }
        }
        .confirmDialog(
            "¿Archivar esta categoría?", isPresented: $confirmArchive,
            message: "Deja de aparecer al registrar movimientos, pero los anteriores se conservan.",
            confirmLabel: "Archivar"
        ) {
            guard let category else { return }
            let route = route
            app.perform(onDone: { app.close(route) }) { try await app.env.categories.archive(id: category.id) }
        }
        .task(id: [app.revision, loader.attempt]) {
            await loader.run { try await app.env.categories.categories() }
            if let list = loader.state.value { existing = list }
        }
    }

    private func save() {
        if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isTaken {
            nameTaken = true
            return
        }
        let draft = CategoryDraft(name: name, kind: kind, colorHex: colorHex)
        let category = category
        let route = route
        app.perform(invalid: draft.validate(), onDone: { app.close(route) }) {
            if let category {
                try await app.env.categories.update(id: category.id, draft)
            } else {
                try await app.env.categories.create(draft, id: UUID().uuidString)
            }
        }
    }
}

private struct ColorSwatch: View {
    let color: Color
    let selected: Bool
    let label: String
    let onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            Circle()
                .fill(color)
                .frame(width: 30, height: 30)
                .frame(width: 44, height: 44)
                .overlay(Circle().strokeBorder(selected ? color : Color.clear, lineWidth: 2))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
