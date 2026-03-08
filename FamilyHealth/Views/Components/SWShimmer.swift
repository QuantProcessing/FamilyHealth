import SwiftUI

/// ShipSwift-style shimmer loading effect modifier.
/// Usage: `Text("Loading...").swShimmer(active: isLoading)`
struct SWShimmerModifier: ViewModifier {
    let active: Bool
    let duration: Double
    let bounce: Bool

    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        if active {
            content
                .redacted(reason: .placeholder)
                .overlay(
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [
                                .clear,
                                .white.opacity(0.4),
                                .clear,
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geo.size.width * 0.4)
                        .offset(x: phase * (geo.size.width * 1.4) - geo.size.width * 0.2)
                    }
                    .mask(content)
                )
                .onAppear {
                    withAnimation(
                        .linear(duration: duration)
                        .repeatForever(autoreverses: bounce)
                    ) {
                        phase = 1
                    }
                }
        } else {
            content
        }
    }
}

extension View {
    /// Applies a shimmer loading effect when `active` is true.
    func swShimmer(active: Bool = true, duration: Double = 1.5, bounce: Bool = false) -> some View {
        modifier(SWShimmerModifier(active: active, duration: duration, bounce: bounce))
    }
}
