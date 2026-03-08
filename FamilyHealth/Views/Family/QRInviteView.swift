import SwiftUI

/// QR code invite display screen
struct QRInviteView: View {
    let groupName: String
    let inviteCode: String
    @Environment(\.dismiss) private var dismiss
    @State private var showCopied = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // QR Code
                VStack(spacing: 16) {
                    if let qrImage = QRCodeGenerator.generate(from: inviteCode, size: 220) {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 220, height: 220)
                            .padding(20)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
                    }

                    Text(groupName)
                        .font(.title3.bold())

                    Text("邀请家人扫描此二维码加入家庭组")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Expiry notice
                HStack {
                    Image(systemName: "clock")
                    Text("二维码 24 小时内有效")
                }
                .font(.caption)
                .foregroundStyle(.orange)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.orange.opacity(0.1))
                .clipShape(Capsule())

                Spacer()

                // Actions
                VStack(spacing: 12) {
                    Button {
                        UIPasteboard.general.string = inviteCode
                        showCopied = true
                    } label: {
                        Label("复制邀请链接", systemImage: "doc.on.doc")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button {
                        // Share sheet
                        let av = UIActivityViewController(
                            activityItems: [inviteCode],
                            applicationActivities: nil
                        )
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let root = windowScene.windows.first?.rootViewController {
                            root.present(av, animated: true)
                        }
                    } label: {
                        Label("分享", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray5))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .navigationTitle("邀请加入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .swAlert(isPresented: $showCopied, type: .success, message: "已复制到剪贴板")
        }
    }
}
