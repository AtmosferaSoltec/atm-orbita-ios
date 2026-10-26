import SwiftUI

/// Navigable mockup of every screen, fed with sample data and in-memory state.
/// Signed out: Iniciar sesión ⇄ Registro. Signed in: Inicio · Cuentas · [ + ] · Reportes · Crédito.
struct ContentView: View {
    @State private var model = AppModel()

    var body: some View {
        Group {
            if model.isLoggedIn {
                MainView()
            } else {
                AuthView(
                    register: model.showsRegister,
                    onSubmit: { model.login() },
                    onSwitch: { model.showsRegister.toggle() }
                )
            }
        }
        .environment(model)
        .preferredColorScheme(.light)
    }
}

private struct MainView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        NavigationStack(path: $model.path) {
            VStack(spacing: 0) {
                Group {
                    switch model.tab {
                    case .home: HomeView()
                    case .accounts: AccountsView()
                    case .reports: ReportsView()
                    case .credit: CreditView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                OrbitaBottomBar(
                    current: model.tab,
                    onSelect: { model.tab = $0 },
                    onAdd: { model.flow = .newEntry(credit: false, startsAsTransfer: false) }
                )
            }
            .background(Palette.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Route.self) { route in
                destination(for: route)
                    .toolbar(.hidden, for: .navigationBar)
            }
        }
        .fullScreenCover(item: $model.flow) { flow in
            flowView(for: flow)
                .environment(model)
        }
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .settings: SettingsView()
        case .movements: MovementsView()
        case .categories: CategoriesView()
        case .categoryForm(let category, let kind): CategoryFormView(category: category, initialKind: kind)
        case .accountEdit(let account): AccountFormView(account: account, onClose: model.pop, onSave: model.pop)
        case .payCredit(let purchase): PayCreditView(purchase: purchase)
        }
    }

    @ViewBuilder
    private func flowView(for flow: Flow) -> some View {
        let close = { model.flow = nil }
        switch flow {
        case .newEntry(let credit, let startsAsTransfer):
            NewEntryFlowView(credit: credit, startsAsTransfer: startsAsTransfer, onClose: close)
        case .editMovement(let movement):
            MovementFormView(editing: movement, onClose: close, onSave: close, onDelete: close)
        case .editTransfer(let transfer):
            TransferFormView(editing: transfer, onClose: close, onSave: close, onDelete: close)
        case .newAccount:
            AccountFormView(account: nil, onClose: close, onSave: close)
        }
    }
}

/// Keeps the swipe-back gesture although the system navigation bar is hidden.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}

#Preview { ContentView() }
