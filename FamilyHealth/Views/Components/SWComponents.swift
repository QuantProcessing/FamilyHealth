import SwiftUI

/// ShipSwift-style empty state view with illustration and call-to-action.
struct SWEmptyState: View {
    let icon: String
    let title: String
    let description: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        icon: String,
        title: String,
        description: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.actionTitle = actionTitle
        self.action = action
    }

    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Animated icon
            ZStack {
                Circle()
                    .fill(.blue.opacity(0.08))
                    .frame(width: 120, height: 120)
                    .scaleEffect(isAnimating ? 1.05 : 0.95)

                Circle()
                    .fill(.blue.opacity(0.05))
                    .frame(width: 100, height: 100)

                Image(systemName: icon)
                    .font(.system(size: 44))
                    .foregroundStyle(.blue)
                    .symbolRenderingMode(.hierarchical)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }

            VStack(spacing: 8) {
                Text(title)
                    .font(.title3.bold())

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline.bold())
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .padding(.top, 4)
            }

            Spacer()
        }
    }
}

/// ShipSwift-style section header
struct SWSectionHeader: View {
    let title: String
    let action: String?
    let onAction: (() -> Void)?

    init(_ title: String, action: String? = nil, onAction: (() -> Void)? = nil) {
        self.title = title
        self.action = action
        self.onAction = onAction
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            if let action, let onAction {
                Button(action, action: onAction)
                    .font(.subheadline)
            }
        }
    }
}

/// ShipSwift-style card container
struct SWCard<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .padding()
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }
}

/// ShipSwift-style badge/pill label
struct SWBadge: View {
    let text: String
    let color: Color

    init(_ text: String, color: Color = .blue) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

/// ShipSwift-style avatar with status indicator
struct SWAvatar: View {
    let name: String
    let imageData: Data?
    let size: CGFloat
    let color: Color

    init(name: String, imageData: Data? = nil, size: CGFloat = 44, color: Color = .blue) {
        self.name = name
        self.imageData = imageData
        self.size = size
        self.color = color
    }

    var body: some View {
        Group {
            if let data = imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(color.opacity(0.15))
                    Text(String(name.prefix(1)))
                        .font(.system(size: size * 0.4, weight: .bold))
                        .foregroundStyle(color)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

/// ShipSwift-style indicator row for health metrics
struct SWIndicatorRow: View {
    let label: String
    let value: String
    let status: Status

    enum Status {
        case normal, elevated, high

        var color: Color {
            switch self {
            case .normal: return .green
            case .elevated: return .orange
            case .high: return .red
            }
        }

        var text: String {
            switch self {
            case .normal: return "正常"
            case .elevated: return "偏高"
            case .high: return "异常"
            }
        }
    }

    var body: some View {
        HStack {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)

            Text(label)
                .font(.subheadline)

            Spacer()

            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            SWBadge(status.text, color: status.color)
        }
    }
}
