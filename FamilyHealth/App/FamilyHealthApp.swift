import SwiftUI
import SwiftData

@main
struct FamilyHealthApp: App {
    let container: ModelContainer

    @StateObject private var appState = AppState()

    init() {
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
                isStoredInMemoryOnly: false
            )
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environment(ServiceContainer(
                    mode: appState.mode,
                    modelContainer: container
                ))
        }
        .modelContainer(container)
    }
}
