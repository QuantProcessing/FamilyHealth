import SwiftUI
import SwiftData

/// Dependency injection container that switches between local and remote service implementations.
@Observable
class ServiceContainer {
    let appState: AppState
    private var apiClient: APIClient?
    private var _modelContext: ModelContext?

    // Service instances
    private(set) var authService: AuthService
    private(set) var reportService: ReportService
    private(set) var caseService: CaseService
    private(set) var familyService: FamilyService

    init(appState: AppState) {
        self.appState = appState
        // Initialize with local services (will use placeholder context)
        self.authService = LocalAuthService(context: nil)
        self.reportService = LocalReportService(context: nil)
        self.caseService = LocalCaseService(context: nil)
        self.familyService = LocalFamilyService(context: nil)
    }

    func configure(modelContext: ModelContext) {
        self._modelContext = modelContext
        rebuildServices()
    }

    func rebuildServices() {
        switch appState.mode {
        case .local:
            guard let ctx = _modelContext else { return }
            authService = LocalAuthService(context: ctx)
            reportService = LocalReportService(context: ctx)
            caseService = LocalCaseService(context: ctx)
            familyService = LocalFamilyService(context: ctx)
        case .remote:
            let api = APIClient(baseURL: appState.serverURL ?? "http://localhost:8080")
            self.apiClient = api
            authService = RemoteAuthService(api: api)
            reportService = RemoteReportService(api: api)
            caseService = RemoteCaseService(api: api)
            familyService = RemoteFamilyService(api: api)
        }
    }
}
