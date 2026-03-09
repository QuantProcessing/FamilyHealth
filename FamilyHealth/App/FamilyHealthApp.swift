import SwiftUI
import SwiftData

@main
struct FamilyHealthApp: App {
    let modelContainer: ModelContainer
    let serviceContainer: ServiceContainer

    @StateObject private var appState = AppState()

    init() {
        let appState = AppState()
        _appState = StateObject(wrappedValue: appState)

        do {
            let schema = Schema([
                User.self,
                HealthReport.self,
                ReportFile.self,
                MedicalCase.self,
                Medication.self,
                CaseAttachment.self,
                FamilyGroup.self,
                FamilyMember.self,
                AIModelConfig.self,
                ChatConversation.self,
                ChatMessage.self,
            ])
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic  // iCloud sync — data stays local, syncs to iCloud
            )
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        // Create single shared ServiceContainer
        serviceContainer = ServiceContainer(appState: appState)
        serviceContainer.configure(modelContext: modelContainer.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environment(serviceContainer)
        }
        .modelContainer(modelContainer)
    }
}
