import SwiftUI

/// ShipSwift-style step indicator for multi-step forms.
struct SWStepper: View {
    let steps: [String]
    let currentStep: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<steps.count, id: \.self) { index in
                // Step circle
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(stepColor(for: index))
                            .frame(width: 32, height: 32)

                        if index < currentStep {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        } else {
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .foregroundStyle(index == currentStep ? .white : .secondary)
                        }
                    }

                    Text(steps[index])
                        .font(.caption2)
                        .foregroundStyle(index <= currentStep ? .primary : .secondary)
                }

                // Connector line
                if index < steps.count - 1 {
                    Rectangle()
                        .fill(index < currentStep ? Color.blue : Color(.systemGray4))
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 20)
                }
            }
        }
        .padding(.horizontal)
    }

    private func stepColor(for index: Int) -> Color {
        if index < currentStep { return .blue }
        if index == currentStep { return .blue }
        return Color(.systemGray5)
    }
}
