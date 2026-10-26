import SwiftUI

/// Root of the app: login or sign-up without a session, the tabs with one. Every screen reads its
/// data from the repositories of `AppModel.env`; whether those are the demo data or the API is
/// decided in `AppEnvironment`.
struct ContentView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.scenePhase) private var scenePhase
    @State private var wasInBackground = false

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            switch app.session {
            // The stored session is being restored: nothing to show yet.
            case .loading:
                EmptyView()
            case .signedOut:
                AuthFlowView()
            case .signedIn:
                MainFlow()
            }
            ToastHost()
        }
        .preferredColorScheme(.light)
        .onChange(of: scenePhase) { _, phase in
            // Back from the background: the data may have changed on another device meanwhile.
            switch phase {
            case .background:
                wasInBackground = true
            case .active:
                if wasInBackground { app.refreshAll() }
                wasInBackground = false
            default:
                break
            }
        }
    }
}

/// The tabs, and the back stack of screens pushed over them.
private struct MainFlow: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var app = app

        NavigationStack(path: $app.path) {
            VStack(spacing: 0) {
                Group {
                    switch app.tab {
                    case .home: HomeView()
                    case .accounts: AccountsView()
                    case .reports: ReportsView()
                    case .credit: CreditView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                OrbitaBottomBar(
                    current: app.tab,
                    onSelect: {
                        app.reportFocus = nil
                        app.tab = $0
                    },
                    onAdd: { app.push(.movementForm()) }
                )
            }
            .background(Palette.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Route.self) { route in
                destination(for: route)
                    .toolbar(.hidden, for: .navigationBar)
            }
        }
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .settings:
            SettingsView()
        case .movements:
            MovementsView()
        case .movementForm(let editing, let credit, let purchase):
            MovementFormScreen(editing: editing, initialCredit: credit, editingPurchase: purchase)
        case .transferForm(let editing):
            TransferFormScreen(editing: editing)
        case .payCredit(let purchase):
            PayCreditScreen(purchase: purchase)
        case .creditCardForm(let card):
            CreditCardFormScreen(card: card)
        case .accountForm(let account):
            AccountFormView(account: account)
        case .categories:
            CategoriesView()
        case .categoryForm(let category, let kind):
            CategoryFormScreen(category: category, initialKind: kind)
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

#Preview {
    ContentView().environment(AppModel(env: .demo()))
}
