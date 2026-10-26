import SwiftUI

/// Pushed screens (no tab bar, ‹ back button).
enum Route: Hashable {
    case settings
    case movements
    case categories
    case categoryForm(category: MockCategory?, kind: MovementKind)
    case accountEdit(MockAccount)
    case payCredit(MockCreditPurchase)
}

/// Full-screen flows (X close button).
enum Flow: Identifiable, Hashable {
    case newEntry(credit: Bool, startsAsTransfer: Bool)
    case editMovement(MockMovement)
    case editTransfer(MockTransfer)
    case newAccount

    var id: String {
        switch self {
        case .newEntry: "new-entry"
        case .editMovement(let movement): "movement-\(movement.id)"
        case .editTransfer(let transfer): "transfer-\(transfer.id)"
        case .newAccount: "new-account"
        }
    }
}

/// In-memory state of the mockup: navigation, session and sample data.
/// Phase 1 replaces it with view models and the Supabase session.
@Observable
final class AppModel {
    var isLoggedIn = false
    var showsRegister = false

    var tab: BottomTab = .home
    var path: [Route] = []
    var flow: Flow?

    var accounts = SampleData.accounts
    var purchases = SampleData.creditPurchases
    var displayCurrency = PEN

    func login() {
        isLoggedIn = true
        resetNavigation()
    }

    func logout() {
        isLoggedIn = false
        showsRegister = false
        resetNavigation()
    }

    func open(_ entry: MockEntry) {
        switch entry {
        case .movement(let movement): flow = .editMovement(movement)
        case .transfer(let transfer): flow = .editTransfer(transfer)
        }
    }

    func setIncludeInSavings(_ include: Bool, for account: MockAccount) {
        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else { return }
        accounts[index].includeInSavings = include
    }

    func markPaid(_ purchase: MockCreditPurchase) {
        purchases.removeAll { $0.id == purchase.id }
        pop()
    }

    func push(_ route: Route) { path.append(route) }

    func pop() {
        if !path.isEmpty { path.removeLast() }
    }

    private func resetNavigation() {
        path = []
        flow = nil
        tab = .home
    }
}
