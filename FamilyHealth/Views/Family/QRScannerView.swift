import SwiftUI
import AVFoundation

/// QR Code scanner view using AVFoundation camera
struct QRScannerView: UIViewControllerRepresentable {
    let onCodeScanned: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let vc = QRScannerViewController()
        vc.onCodeScanned = { code in
            onCodeScanned(code)
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}

class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCodeScanned: ((String) -> Void)?
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasScanned = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let session = captureSession, !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }

    private func setupCamera() {
        let session = AVCaptureSession()

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            showNoCameraUI()
            return
        }

        if session.canAddInput(input) { session.addInput(input) }

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]
        }

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)

        self.captureSession = session
        self.previewLayer = preview

        // Add scan frame overlay
        addScanOverlay()

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    private func addScanOverlay() {
        let overlay = UIView(frame: view.bounds)
        overlay.backgroundColor = .clear
        view.addSubview(overlay)

        let scanSize: CGFloat = 250
        let x = (view.bounds.width - scanSize) / 2
        let y = (view.bounds.height - scanSize) / 2
        let scanRect = CGRect(x: x, y: y, width: scanSize, height: scanSize)

        let path = UIBezierPath(rect: view.bounds)
        let scanPath = UIBezierPath(roundedRect: scanRect, cornerRadius: 12)
        path.append(scanPath.reversing())

        let maskLayer = CAShapeLayer()
        maskLayer.path = path.cgPath
        maskLayer.fillColor = UIColor.black.withAlphaComponent(0.5).cgColor
        overlay.layer.addSublayer(maskLayer)

        // Corner markers
        let cornerLength: CGFloat = 24
        let cornerWidth: CGFloat = 3
        let corners: [(CGPoint, CGFloat, CGFloat)] = [
            (CGPoint(x: scanRect.minX, y: scanRect.minY), 1, 1),
            (CGPoint(x: scanRect.maxX, y: scanRect.minY), -1, 1),
            (CGPoint(x: scanRect.minX, y: scanRect.maxY), 1, -1),
            (CGPoint(x: scanRect.maxX, y: scanRect.maxY), -1, -1),
        ]
        for (point, dx, dy) in corners {
            let h = UIView(frame: CGRect(x: point.x, y: point.y, width: cornerLength * dx, height: cornerWidth))
            h.backgroundColor = .systemBlue
            overlay.addSubview(h)
            let v = UIView(frame: CGRect(x: point.x, y: point.y, width: cornerWidth, height: cornerLength * dy))
            v.backgroundColor = .systemBlue
            overlay.addSubview(v)
        }

        // Label
        let label = UILabel()
        label.text = "将二维码放入框内扫描"
        label.textColor = .white
        label.font = .systemFont(ofSize: 14)
        label.textAlignment = .center
        label.frame = CGRect(x: 0, y: scanRect.maxY + 20, width: view.bounds.width, height: 20)
        overlay.addSubview(label)
    }

    private func showNoCameraUI() {
        let label = UILabel()
        label.text = "无法访问相机"
        label.textColor = .white
        label.textAlignment = .center
        label.frame = view.bounds
        view.addSubview(label)
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !hasScanned,
              let metadata = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = metadata.stringValue else { return }
        hasScanned = true
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        onCodeScanned?(code)
    }
}
