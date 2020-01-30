import Foundation
import AVFoundation
import PhotosUI
import Photos

protocol CameraManDelegate: class {
    func cameraManNotAvailable(_ cameraMan: CameraMan)
    func cameraManDidStart(_ cameraMan: CameraMan)
    func cameraMan(_ cameraMan: CameraMan, didChangeInput input: AVCaptureDeviceInput)
}

class CameraMan {
    weak var delegate: CameraManDelegate?
    
    let session = AVCaptureSession()
    let queue = DispatchQueue(label: "no.hyper.ImagePicker.Camera.SessionQueue")
    
    var backCamera: AVCaptureDeviceInput?
    var frontCamera: AVCaptureDeviceInput?
    var stillImageOutput: AVCaptureStillImageOutput?
    var startOnFrontCamera: Bool = false
    var albumTitle: String?
    
    deinit {
        stop()
    }
    
    // MARK: - Setup
    
    @objc func setDefaultFocusAndExposure() {
        guard let device = currentInput?.device else { return }
        
        do {
            try device.lockForConfiguration()
            
            device.isSubjectAreaChangeMonitoringEnabled = true
            
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            
            device.unlockForConfiguration()
            
        } catch {
            
        }
    }
    
    func setup(_ startOnFrontCamera: Bool = false, albumTitle: String? = nil) {
        self.startOnFrontCamera = startOnFrontCamera
        self.albumTitle = albumTitle
        checkPermission()
    }
    
    func setupDevices() {
        // Input
        AVCaptureDevice
            .devices()
            .filter {
                return $0.hasMediaType(AVMediaType.video)
            }.forEach {
                switch $0.position {
                case .front:
                    self.frontCamera = try? AVCaptureDeviceInput(device: $0)
                case .back:
                    self.backCamera = try? AVCaptureDeviceInput(device: $0)
                default:
                    break
                }
        }
        
        // Output
        stillImageOutput = AVCaptureStillImageOutput()
        stillImageOutput?.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
    }
    
    func addInput(_ input: AVCaptureDeviceInput) {
        configurePreset(input)
        
        if session.canAddInput(input) {
            session.addInput(input)
            
            DispatchQueue.main.async {
                self.delegate?.cameraMan(self, didChangeInput: input)
            }
        }
    }
    
    // MARK: - Permission
    
    func checkPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
        
        switch status {
        case .authorized:
            start()
        case .notDetermined:
            requestPermission()
        default:
            delegate?.cameraManNotAvailable(self)
        }
    }
    
    func requestPermission() {
        AVCaptureDevice.requestAccess(for: AVMediaType.video) { granted in
            DispatchQueue.main.async {
                if granted {
                    self.start()
                } else {
                    self.delegate?.cameraManNotAvailable(self)
                }
            }
        }
    }
    
    // MARK: - Session
    
    var currentInput: AVCaptureDeviceInput? {
        return session.inputs.first as? AVCaptureDeviceInput
    }
    
    fileprivate func start() {
        // Devices
        setupDevices()
        
        guard let input = (self.startOnFrontCamera) ? frontCamera ?? backCamera : backCamera, let output = stillImageOutput else { return }
        
        addInput(input)
        
        setDefaultFocusAndExposure()
        
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        
        queue.async {
            self.session.startRunning()
            
            DispatchQueue.main.async {
                self.delegate?.cameraManDidStart(self)
            }
        }
    }
    
    func stop() {
        self.session.stopRunning()
    }
    
    func switchCamera(_ completion: (() -> Void)? = nil) {
        guard let currentInput = currentInput
            else {
                completion?()
                return
        }
        
        queue.async {
            guard let input = (currentInput == self.backCamera) ? self.frontCamera : self.backCamera
                else {
                    DispatchQueue.main.async {
                        completion?()
                    }
                    return
            }
            
            self.configure {
                self.session.removeInput(currentInput)
                self.addInput(input)
            }
            
            DispatchQueue.main.async {
                completion?()
            }
        }
    }
    
    func takePhoto(_ previewLayer: AVCaptureVideoPreviewLayer, location: CLLocation?, completion: (() -> Void)? = nil) {
        guard let connection = stillImageOutput?.connection(with: AVMediaType.video) else { return }
        
        connection.videoOrientation = Helper.getVideoOrientation(fromUIInferfaceOrientation: UIApplication.shared.statusBarOrientation)
        
        queue.async {
            self.stillImageOutput?.captureStillImageAsynchronously(from: connection) { buffer, error in
                guard let buffer = buffer, error == nil && CMSampleBufferIsValid(buffer),
                    let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(buffer),
                    let image = UIImage(data: imageData)
                    else {
                        DispatchQueue.main.async {
                            completion?()
                        }
                        return
                }
                
                guard let albumTitle = self.albumTitle else {
                    self.savePhoto(image, location: location, completion: completion)
                    return;
                }
                
                PHPhotoLibrary.shared().savePhoto(image: image, albumName: albumTitle, completion: { (_) in
                    DispatchQueue.main.async {
                        completion?()
                    }
                })
            }
        }
    }
    
    func savePhoto(_ image: UIImage, location: CLLocation?, completion: (() -> Void)? = nil) {
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
            request.creationDate = Date()
            request.location = location
        }, completionHandler: { (_, _) in
            DispatchQueue.main.async {
                completion?()
            }
        })
    }
    
    func flash(_ mode: AVCaptureDevice.FlashMode) {
        guard let device = currentInput?.device, device.isFlashModeSupported(mode) else { return }
        
        queue.async {
            self.lock {
                device.flashMode = mode
            }
        }
    }
    
    func focus(_ point: CGPoint) {
        guard let device = currentInput?.device,
            device.isFocusModeSupported(.autoFocus),
            device.isExposureModeSupported(.autoExpose) else { return }
        
        queue.async {
            self.lock {
                device.focusPointOfInterest = point
                device.exposurePointOfInterest = point
                device.focusMode = .autoFocus
                device.exposureMode = .autoExpose
            }
        }
    }
    
    func zoom(_ zoomFactor: CGFloat) {
        guard let device = currentInput?.device, device.position == .back else { return }
        
        queue.async {
            self.lock {
                device.videoZoomFactor = zoomFactor
            }
        }
    }
    
    // MARK: - Lock
    
    func lock(_ block: () -> Void) {
        if let device = currentInput?.device, (try? device.lockForConfiguration()) != nil {
            block()
            device.unlockForConfiguration()
        }
    }
    
    // MARK: - Configure
    func configure(_ block: () -> Void) {
        session.beginConfiguration()
        block()
        session.commitConfiguration()
    }
    
    // MARK: - Preset
    
    func configurePreset(_ input: AVCaptureDeviceInput) {
        for asset in preferredPresets() {
            if input.device.supportsSessionPreset(AVCaptureSession.Preset(rawValue: asset)) && self.session.canSetSessionPreset(AVCaptureSession.Preset(rawValue: asset)) {
                self.session.sessionPreset = AVCaptureSession.Preset(rawValue: asset)
                return
            }
        }
    }
    
    func preferredPresets() -> [String] {
        return [
            AVCaptureSession.Preset.photo.rawValue,
            AVCaptureSession.Preset.high.rawValue,
            AVCaptureSession.Preset.low.rawValue
        ]
    }
}

extension PHPhotoLibrary {
    // MARK: - PHPhotoLibrary+SaveImage
    
    // MARK: - Public
    
    func savePhoto(image:UIImage, albumName:String, completion:((PHAsset?)->())? = nil) {
        func save() {
            if let album = PHPhotoLibrary.shared().findAlbum(albumName: albumName) {
                PHPhotoLibrary.shared().saveImage(image: image, album: album, completion: completion)
            } else {
                PHPhotoLibrary.shared().createAlbum(albumName: albumName, completion: { (collection) in
                    if let collection = collection {
                        PHPhotoLibrary.shared().saveImage(image: image, album: collection, completion: completion)
                    } else {
                        completion?(nil)
                    }
                })
            }
        }
        
        if PHPhotoLibrary.authorizationStatus() == .authorized {
            save()
        } else {
            PHPhotoLibrary.requestAuthorization({ (status) in
                if status == .authorized {
                    save()
                }
            })
        }
    }
    
    // MARK: - Private
    
    fileprivate func findAlbum(albumName: String) -> PHAssetCollection? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        let fetchResult : PHFetchResult = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
        guard let photoAlbum = fetchResult.firstObject else {
            return nil
        }
        return photoAlbum
    }
    
    fileprivate func createAlbum(albumName: String, completion: @escaping (PHAssetCollection?)->()) {
        var albumPlaceholder: PHObjectPlaceholder?
        PHPhotoLibrary.shared().performChanges({
            let createAlbumRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
            albumPlaceholder = createAlbumRequest.placeholderForCreatedAssetCollection
        }, completionHandler: { success, error in
            if success {
                guard let placeholder = albumPlaceholder else {
                    completion(nil)
                    return
                }
                let fetchResult = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [placeholder.localIdentifier], options: nil)
                guard let album = fetchResult.firstObject else {
                    completion(nil)
                    return
                }
                completion(album)
            } else {
                completion(nil)
            }
        })
    }
    
    fileprivate func saveImage(image: UIImage, album: PHAssetCollection, completion:((PHAsset?)->())? = nil) {
        var placeholder: PHObjectPlaceholder?
        PHPhotoLibrary.shared().performChanges({
            let createAssetRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
            guard let albumChangeRequest = PHAssetCollectionChangeRequest(for: album),
                let photoPlaceholder = createAssetRequest.placeholderForCreatedAsset else { return }
            placeholder = photoPlaceholder
            let fastEnumeration = NSArray(array: [photoPlaceholder] as [PHObjectPlaceholder])
            albumChangeRequest.addAssets(fastEnumeration)
        }, completionHandler: { success, error in
            guard let placeholder = placeholder else {
                completion?(nil)
                return
            }
            if success {
                let assets:PHFetchResult<PHAsset> =  PHAsset.fetchAssets(withLocalIdentifiers: [placeholder.localIdentifier], options: nil)
                let asset:PHAsset? = assets.firstObject
                completion?(asset)
            } else {
                completion?(nil)
            }
        })
    }
}
