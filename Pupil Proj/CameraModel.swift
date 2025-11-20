import Foundation
import AVFoundation
import UIKit
import SwiftUI
import Combine

class CameraModel: NSObject, ObservableObject {
    @Published var leftEyeImages: [UIImage] = []
    @Published var rightEyeImages: [UIImage] = []
    @Published var debugMessage: String = "Idle"
    @Published var isBusy: Bool = false
    @Published var zoomFactor: CGFloat = 1.0

    var session = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var videoDeviceInput: AVCaptureDeviceInput!
    private var isSessionRunning = false

    enum EyeMode { case left, right }
    @Published var currentEye: EyeMode = .left
    
    override init() {
        super.init()
    }
    
    // MARK: - Session Management
    func startSession() {
        guard !isSessionRunning else { return }
        
        session.beginConfiguration()
        session.sessionPreset = .photo
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            debugMessage = "No back camera available"
            print(debugMessage)
            return
        }
        
        do {
            videoDeviceInput = try AVCaptureDeviceInput(device: device)
        } catch {
            debugMessage = "Error creating device input: \(error)"
            print(debugMessage)
            return
        }
        
        if session.canAddInput(videoDeviceInput) { session.addInput(videoDeviceInput) }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        
        session.commitConfiguration()
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
            self.isSessionRunning = true
            DispatchQueue.main.async {
                self.debugMessage = "Session started"
                print(self.debugMessage)
            }
        }
    }
    
    func stopSession() {
        if isSessionRunning {
            session.stopRunning()
            isSessionRunning = false
            debugMessage = "Session stopped"
        }
    }
    
    // MARK: - Torch control
    func setTorch(on: Bool) {
        guard let device = videoDeviceInput?.device, device.hasTorch else {
            debugMessage = on ? "Torch not available" : "Torch already off or not available"
            return
        }
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
            debugMessage = on ? "Torch ON" : "Torch OFF"
        } catch {
            debugMessage = "Could not set torch: \(error)"
            print(debugMessage)
        }
    }
    
    // MARK: - Zoom control
    private var lastZoom: CGFloat = 1.0
    func setZoom(_ factor: CGFloat) {
        guard let device = videoDeviceInput?.device else { return }
        let zoom = min(max(factor, 1.0), device.activeFormat.videoMaxZoomFactor)
        if abs(zoom - lastZoom) < 0.01 { return }
        lastZoom = zoom
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = zoom
            device.unlockForConfiguration()
            self.zoomFactor = zoom
        } catch {
            print("Failed to set zoom: \(error)")
        }
    }
    
    // MARK: - Take Multiple Photos with torch buffer
    func takeMultiplePhotos(count: Int, interval: TimeInterval, torchLeadTime: TimeInterval = 0.2, torchLagTime: TimeInterval = 0.3) {
        guard !isBusy else { return }
        guard videoDeviceInput != nil else {
            debugMessage = "Camera input not ready"
            return
        }
        
        isBusy = true
        debugMessage = "Preparing capture..."
        print(debugMessage)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + torchLeadTime) { [weak self] in
            self?.setTorch(on: true)
        }
        
        for i in 0..<count {
            let delay = interval * Double(i) + torchLeadTime
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self else { return }
                let settings = AVCapturePhotoSettings()
                settings.flashMode = .off
                self.photoOutput.capturePhoto(with: settings, delegate: self)
                self.debugMessage = "Capturing \(i+1)/\(count)"
                print(self.debugMessage)
            }
        }
        
        let totalDuration = (interval * Double(count)) + torchLeadTime + torchLagTime
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration) { [weak self] in
            guard let self = self else { return }
            self.setTorch(on: false)
            self.isBusy = false
            self.debugMessage = "Sequence complete"
            print(self.debugMessage)
        }
    }
}

extension CameraModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let error = error {
            print("Photo processing error: \(error)")
            return
        }
        guard let data = photo.fileDataRepresentation(),
              let uiImage = UIImage(data: data) else {
            print("Could not convert photo to UIImage")
            return
        }
        
        DispatchQueue.main.async {
            switch self.currentEye {
            case .left:
                self.leftEyeImages.append(uiImage)
            case .right:
                self.rightEyeImages.append(uiImage)
            }
        }
    }
}
