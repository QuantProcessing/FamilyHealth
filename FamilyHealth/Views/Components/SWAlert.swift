import SwiftUI

/// ShipSwift-style alert toast notification.
/// Usage: `.swAlert(isPresented: $showAlert, type: .success, message: "保存成功")`
struct SWAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    let type: SWAlertType
    let message: String
    let duration: Double

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if isPresented {
                SWAlertView(type: type, message: message)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                            withAnimation(.spring(response: 0.3)) {
                                isPresented = false
                            }
                        }
                    }
                    .padding(.top, 8)
            }
        }
        .animation(.spring(response: 0.3), value: isPresented)
    }
}

enum SWAlertType {
    case success, error, warning, info

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error:   return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info:    return "info.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .success: return .green
        case .error:   return .red
        case .warning: return .orange
        case .info:    return .blue
        }
    }
}

struct SWAlertView: View {
    let type: SWAlertType
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: type.icon)
                .foregroundStyle(type.color)
                .font(.title3)
            Text(message)
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
    }
}

extension View {
    func swAlert(isPresented: Binding<Bool>, type: SWAlertType, message: String, duration: Double = 2.0) -> some View {
        modifier(SWAlertModifier(isPresented: isPresented, type: type, message: message, duration: duration))
    }
}
