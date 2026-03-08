import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @State private var currentPage = 0

    private let pages: [(image: String, title: String, subtitle: String)] = [
        ("heart.text.clipboard", "家庭健康守护", "轻松管理全家人的体检报告和病例记录"),
        ("brain.head.profile", "AI 智能分析", "AI 帮你解读体检报告，给出专业健康建议"),
        ("lock.shield", "隐私安全", "支持本地存储，数据完全由你掌控"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    VStack(spacing: 24) {
                        Spacer()

                        Image(systemName: pages[index].image)
                            .font(.system(size: 80))
                            .foregroundStyle(.blue)
                            .symbolRenderingMode(.hierarchical)

                        Text(pages[index].title)
                            .font(.largeTitle.bold())

                        Text(pages[index].subtitle)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        Spacer()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button {
                withAnimation {
                    if currentPage < pages.count - 1 {
                        currentPage += 1
                    } else {
                        appState.hasCompletedOnboarding = true
                    }
                }
            } label: {
                Text(currentPage < pages.count - 1 ? "下一步" : "开始使用")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }
}
