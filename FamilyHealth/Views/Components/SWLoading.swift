import SwiftUI

/// ShipSwift-style modern loading indicator with pulse animation.
struct SWLoadingView: View {
    let message: String
    @State private var isAnimating = false

    init(_ message: String = "加载中...") {
        self.message = message
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Outer pulse ring
                Circle()
                    .stroke(lineWidth: 3)
                    .foregroundStyle(.blue.opacity(0.3))
                    .frame(width: 48, height: 48)
                    .scaleEffect(isAnimating ? 1.3 : 1)
                    .opacity(isAnimating ? 0 : 0.6)

                // Inner spinner
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .foregroundStyle(.blue)
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
            }

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}

/// ShipSwift-style skeleton placeholder for cards
struct SWSkeletonCard: View {
    var height: CGFloat = 80

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 14)
                        .frame(maxWidth: 180)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 12)
                        .frame(maxWidth: 120)
                }
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .swShimmer()
    }
}
