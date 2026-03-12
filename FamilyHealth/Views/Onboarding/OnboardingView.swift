import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @State private var currentPage = 0
    @State private var iconScale: CGFloat = 0.6
    @State private var textOpacity: Double = 0

    private let pages: [(image: String, title: String, subtitle: String, color: Color)] = [
        ("heart.text.clipboard", "家庭健康守护", "轻松管理全家人的体检报告和病例记录", FHColors.primary),
        ("brain.head.profile", "AI 智能分析", "AI 帮你解读体检报告，给出专业健康建议", FHColors.aiPurple),
        ("lock.shield", "隐私安全", "支持本地存储，数据完全由你掌控", FHColors.success),
    ]

    var body: some View {
        ZStack {
            // Subtle gradient background
            FHGradients.onboardingBg.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        onboardingPage(index: index)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                // Bottom button
                Button {
                    withAnimation(FHAnimation.springBounce) {
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
                        .background(FHGradients.accentButton)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: FHRadius.large))
                        .fhShadow(.medium)
                }
                .fhPressStyle()
                .padding(.horizontal, FHSpacing.xxl)
                .padding(.bottom, 48)
            }
        }
        .onChange(of: currentPage) { _, _ in
            // Re-trigger entrance animations on page change
            iconScale = 0.6
            textOpacity = 0
            withAnimation(FHAnimation.springBounce.delay(0.1)) { iconScale = 1.0 }
            withAnimation(.easeOut(duration: 0.4).delay(0.25)) { textOpacity = 1.0 }
        }
        .onAppear {
            withAnimation(FHAnimation.springBounce.delay(0.2)) { iconScale = 1.0 }
            withAnimation(.easeOut(duration: 0.4).delay(0.35)) { textOpacity = 1.0 }
        }
    }

    private func onboardingPage(index: Int) -> some View {
        let page = pages[index]
        return VStack(spacing: FHSpacing.xxl) {
            Spacer()

            // Animated hero icon with glow
            ZStack {
                // Glow rings
                Circle()
                    .fill(page.color.opacity(0.08))
                    .frame(width: 160, height: 160)
                    .scaleEffect(iconScale * 1.1)

                Circle()
                    .fill(page.color.opacity(0.05))
                    .frame(width: 130, height: 130)

                Image(systemName: page.image)
                    .font(.system(size: 64))
                    .foregroundStyle(page.color)
                    .symbolRenderingMode(.hierarchical)
                    .scaleEffect(iconScale)
            }

            VStack(spacing: FHSpacing.sm) {
                Text(page.title)
                    .font(.largeTitle.bold())

                Text(page.subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .opacity(textOpacity)

            Spacer()
        }
    }
}
