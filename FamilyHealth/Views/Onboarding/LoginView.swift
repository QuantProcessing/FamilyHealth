import SwiftUI

// LoginView is no longer used — app auto-creates user on first launch.
// Kept for reference but not shown in the app flow.

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(ServiceContainer.self) private var services
    @State private var phone = ""
    @State private var name = ""
    @State private var gender: User.Gender = .male
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: FHSpacing.xxxl) {
                Spacer()
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(FHColors.primary)
                Text("FamilyHealth")
                    .font(.title.bold())

                VStack(spacing: FHSpacing.lg) {
                    TextField("您的姓名", text: $name)
                        .textFieldStyle(.roundedBorder)
                    Picker("性别", selection: $gender) {
                        ForEach(User.Gender.allCases, id: \.self) { g in
                            Text(g.displayName).tag(g)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal, FHSpacing.xxl)

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(FHColors.danger)
                }

                Spacer()

                Button {
                    Task { await login() }
                } label: {
                    Text("开始使用")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(name.isEmpty ? AnyShapeStyle(Color.gray.opacity(0.4)) : AnyShapeStyle(FHGradients.accentButton))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: FHRadius.large))
                }
                .disabled(name.isEmpty)
                .padding(.horizontal, FHSpacing.xxl)
                .padding(.bottom, FHSpacing.xxxl)
            }
        }
    }

    private func login() async {
        do {
            let user = try await services.authService.createLocalUser(
                phone: phone, name: name, gender: gender
            )
            appState.currentUserId = user.id.uuidString
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
