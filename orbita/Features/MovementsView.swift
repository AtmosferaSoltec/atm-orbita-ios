import SwiftUI

/// Recent movements and transfers, one month at a time, with search and an account filter.
struct MovementsView: View {
    @Environment(AppModel.self) private var app
    @State private var loader = Loader<MovementsData>()

    var body: some View {
        Loaded(load: loader.state, onRetry: { loader.retry() }, onClose: { app.pop() }) { data in
            MovementsList(accounts: data.accounts, entries: data.entries, today: app.today)
        }
        .task(id: [app.revision, loader.attempt]) { await loader.run { try await app.loadMovementsData() } }
    }
}

private struct MovementsList: View {
    @Environment(AppModel.self) private var app
    let accounts: [Account]
    let entries: [Entry]
    let today: LocalDay

    @State private var query = ""
    @State private var accountId: String?
    @State private var month: LocalDay

    init(accounts: [Account], entries: [Entry], today: LocalDay) {
        self.accounts = accounts
        self.entries = entries
        self.today = today
        _month = State(initialValue: today.firstOfMonth)
    }

    // The current month plus the four before it; older activity is only seen in Reportes.
    private var newestMonth: LocalDay { today.firstOfMonth }
    private var oldestMonth: LocalDay { newestMonth.adding(months: -(movementMonthsShown - 1)) }

    private var shown: [Entry] {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return entries.filter { entry in
            let text: String
            let inAccount: Bool
            switch entry {
            case .movement(let movement):
                text = movement.description
                inAccount = accountId == nil || movement.account.id == accountId
            case .transfer(let transfer):
                text = transfer.note
                inAccount = accountId == nil || transfer.from.id == accountId || transfer.to.id == accountId
            }
            let inMonth = entry.date.firstOfMonth == month
            let matches = search.isEmpty || text.range(of: search, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            return inMonth && inAccount && matches
        }
    }

    var body: some View {
        let shown = shown
        ScreenScaffold(header: {
            ModalTopBar(title: "Movimientos", icon: .back, onNavigate: { app.pop() })
        }) {
            OrbitaTextField(text: $query, placeholder: "Buscar por descripción", leadingIcon: "magnifyingglass")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    OrbitaChip(label: "Todas las cuentas", selected: accountId == nil) { accountId = nil }
                    ForEach(accounts) { account in
                        OrbitaChip(label: account.name, selected: accountId == account.id) { accountId = account.id }
                    }
                }
            }
            .padding(.top, 12)
            MonthSelector(
                month: month,
                onPrevious: { month = month.adding(months: -1) },
                onNext: { month = month.adding(months: 1) },
                canGoPrevious: month > oldestMonth,
                canGoNext: month < newestMonth
            )
            .padding(.vertical, 12)
            if shown.isEmpty {
                let filtering = !query.trimmingCharacters(in: .whitespaces).isEmpty || accountId != nil
                StateMessage(
                    systemImage: "magnifyingglass",
                    title: filtering ? "No hay movimientos con estos filtros" : "No hay movimientos en este mes"
                )
            } else {
                EntryList(entries: shown) { app.open($0) }
            }
        }
    }
}
