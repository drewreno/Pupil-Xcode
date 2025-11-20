import SwiftUI
import AVFoundation

struct CameraPreview: UIViewRepresentable {
    @ObservedObject var camera: CameraModel

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.session = camera.session
        view.videoGravity = .resizeAspect // true camera aspect ratio

        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        view.addGestureRecognizer(pinchGesture)
        
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.session = camera.session
    }

    func makeCoordinator() -> Coordinator { Coordinator(camera: camera) }

    class Coordinator: NSObject {
        var camera: CameraModel
        init(camera: CameraModel) { self.camera = camera }
        
        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            if gesture.state == .changed || gesture.state == .ended {
                let newZoom = camera.zoomFactor * gesture.scale
                camera.setZoom(newZoom)
                gesture.scale = 1.0
            }
        }
    }
}

class PreviewView: UIView {
    var session: AVCaptureSession? {
        get { videoPreviewLayer.session }
        set { videoPreviewLayer.session = newValue }
    }
    
    var videoGravity: AVLayerVideoGravity = .resizeAspect {
        didSet { videoPreviewLayer.videoGravity = videoGravity }
    }
    
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        videoPreviewLayer.frame = bounds
    }
}
