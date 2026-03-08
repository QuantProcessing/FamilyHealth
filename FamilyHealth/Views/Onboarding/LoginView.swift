import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(ServiceContainer.self) private var services
    @State private var phone = ""
    @State private var name = ""
    @State private var gender: User.Gender = .other
    @State private var showProfileSetup = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Logo
                VStack(spacing: 12) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.blue)
                    Text("FamilyHealth")
                        .font(.title.bold())
                }

                // Phone input
                VStack(spacing: 16) {
                    HStack {
                        Text("+86")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        TextField("手机号", text: $phone)
                            .keyboardType(.phonePad)
                            .textFieldStyle(.roundedBorder)
                    }

                    if appState.mode == .local {
                        TextField("您的姓名", text: $name)
                            .textFieldStyle(.roundedBorder)

                        Picker("性别", selection: $gender) {
                            ForEach(User.Gender.allCases, id: \.self) { g in
                                Text(g.displayName).tag(g)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .padding(.horizontal, 24)

                // Mode selector
                VStack(spacing: 8) {
                    Text("运行模式")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        ModeCard(
                            icon: "iphone",
                            title: "本地模式",
                            subtitle: "无需联网，数据保存在本地",
                            isSelected: appState.mode == .local
                        ) { appState.mode = .local }

                        ModeCard(
                            icon: "cloud",
                            title: "联网模式",
                            subtitle: "数据同步至云端，随时访问",
                            isSelected: appState.mode == .remote
                        ) { appState.mode = .remote }
                    }
                    .padding(.horizontal, 24)
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Spacer()

                // Login button
                Button {
                    Task { await login() }
                } label: {
                    Text(appState.mode == .local ? "创建本地账户" : "获取验证码")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(phone.isEmpty || (appState.mode == .local && name.isEmpty))
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }

    private func login() async {
        do {
            if appState.mode == .local {
                let user = try await services.authService.createLocalUser(
                    phone: phone, name: name, gender: gender
                )
                appState.currentUserId = user.id.uuidString
            } else {
                // TODO: Remote login with SMS verification
                errorMessage = "联网模式登录暂未实现"
            }
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
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.subheadline.bold())
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? .blue : .clear, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
