import Foundation

/// The single place that decides which implementation is behind each repository: the API when
/// there is a base URL, the in-memory demo otherwise.
struct AppEnvironment {
    let auth: AuthRepository
    let accounts: AccountsRepository
    let categories: CategoriesRepository
    let entries: EntriesRepository
    let reports: ReportsRepository
    let credit: CreditRepository
    let settings: SettingsRepository
    let home: HomeRepository
    let dates: DateProvider

    /// In demo mode no email can arrive: the code screen says any 6 digits work.
    let isDemo: Bool

    static func make(apiBaseURL: URL? = AppConfig.apiBaseURL) -> AppEnvironment {
        guard let apiBaseURL else { return demo() }
        let session = ApiSession(client: ApiClient(baseURL: apiBaseURL), tokens: KeychainTokenStore())
        return AppEnvironment(
            auth: RemoteAuthRepository(api: session),
            accounts: RemoteAccountsRepository(api: session),
            categories: RemoteCategoriesRepository(api: session),
            entries: RemoteEntriesRepository(api: session),
            reports: RemoteReportsRepository(api: session),
            credit: RemoteCreditRepository(api: session),
            settings: RemoteSettingsRepository(api: session),
            home: RemoteHomeRepository(api: session),
            // With the API, "today" is the phone's date, which is the zone the profile was created with.
            dates: SystemDateProvider(),
            isDemo: false
        )
    }

    /// The demo data is dated: while it is in use, so is "today".
    static func demo() -> AppEnvironment {
        let store = DemoStore()
        let dates = DemoDateProvider()
        let accounts = DemoAccountsRepository(store: store)
        let settings = DemoSettingsRepository(store: store)
        let entries = DemoEntriesRepository(store: store, dates: dates)
        let reports = DemoReportsRepository(store: store)
        let credit = DemoCreditRepository(store: store, dates: dates)
        return AppEnvironment(
            auth: DemoAuthRepository(store: store),
            accounts: accounts,
            categories: DemoCategoriesRepository(store: store),
            entries: entries,
            reports: reports,
            credit: credit,
            settings: settings,
            home: DemoHomeRepository(
                accounts: accounts, settings: settings, entries: entries,
                reports: reports, credit: credit, dates: dates
            ),
            dates: dates,
            isDemo: true
        )
    }
}
