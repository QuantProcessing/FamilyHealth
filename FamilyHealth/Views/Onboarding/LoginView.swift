import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(ServiceContainer.self) private var services
    @State private var phone = ""
    @State private var name = ""
    @State private var gender: User.Gender = .male
    @State private var errorMessage: String?
    @State private var logoBreathing = false

    var body: some View {
        NavigationStack {
            ZStack {
                FHGradients.onboardingBg.ignoresSafeArea()

                VStack(spacing: FHSpacing.xxxl) {
                    Spacer()

                    // Logo with breathing animation
                    VStack(spacing: FHSpacing.md) {
                        ZStack {
                            Circle()
                                .fill(FHColors.primary.opacity(0.08))
                                .frame(width: 110, height: 110)
                                .scaleEffect(logoBreathing ? 1.08 : 0.95)

                            Image(systemName: "heart.circle.fill")
                                .font(.system(size: 72))
                                .foregroundStyle(FHColors.primary)
                                .symbolRenderingMode(.hierarchical)
                        }

                        Text("FamilyHealth")
                            .font(.title.bold())
                    }
                    .fhStaggerEntrance(index: 0)

                    // User info input
                    VStack(spacing: FHSpacing.lg) {
                        HStack {
                            Text("+86")
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, FHSpacing.md)
                                .padding(.vertical, 10)
                                .background(FHColors.subtleGray)
                                .clipShape(RoundedRectangle(cornerRadius: FHRadius.small))

                            TextField("手机号", text: $phone)
                                .keyboardType(.phonePad)
                                .textFieldStyle(.roundedBorder)
                        }

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
                    .fhStaggerEntrance(index: 1)

                    // Description
                    VStack(spacing: FHSpacing.sm) {
                        HStack(spacing: FHSpacing.sm) {
                            Image(systemName: BuildConfig.isServerMode ? "cloud.fill" : "lock.shield")
                                .foregroundStyle(FHColors.success)
                            Text(BuildConfig.isServerMode
                                 ? "账户数据通过服务器同步"
                                 : "所有数据安全存储在您的设备上")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .fhStaggerEntrance(index: 2)

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(FHColors.danger)
                            .transition(.opacity)
                    }

                    Spacer()

                    // Login button
                    Button {
                        Task { await login() }
                    } label: {
                        Text("创建账户")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                (phone.isEmpty || name.isEmpty)
                                    ? AnyShapeStyle(Color.gray.opacity(0.4))
                                    : AnyShapeStyle(FHGradients.accentButton)
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: FHRadius.large))
                            .fhShadow(.medium)
                    }
                    .disabled(phone.isEmpty || name.isEmpty)
                    .fhPressStyle()
                    .padding(.horizontal, FHSpacing.xxl)
                    .padding(.bottom, FHSpacing.xxxl)
                    .fhStaggerEntrance(index: 3)
                }
            }
            .onAppear {
                withAnimation(FHAnimation.gentlePulse) {
                    logoBreathing = true
                }
            }
        }
    }

    private func login() async {
        do {
            #if SERVER_MODE
            // Server mode: register via server API, then create local user
            let api = APIClient(baseURL: BuildConfig.serverURL)
            let authService = RemoteAuthService(api: api)
            let user = try await authService.createLocalUser(
                phone: phone, name: name, gender: gender
            )
            appState.currentUserId = user.id.uuidString
            #else
            // Local mode: create user in local SwiftData
            let user = try await services.authService.createLocalUser(
                phone: phone, name: name, gender: gender
            )
            appState.currentUserId = user.id.uuidString
            #endif
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ModeCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: FHSpacing.sm) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? FHColors.primary : .secondary)
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(isSelected ? FHColors.primary : .primary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? FHColors.primary.opacity(0.08) : FHColors.subtleGray)
            .overlay(
                RoundedRectangle(cornerRadius: FHRadius.medium)
                    .stroke(isSelected ? FHColors.primary : .clear, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: FHRadius.medium))
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(FHAnimation.springBounce, value: isSelected)
        }
        .fhPressStyle()
    }
}
