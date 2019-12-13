import UIKit
import MediaPlayer
import Photos

@objc public protocol ImagePickerDelegate: NSObjectProtocol {
    
    func wrapperDidPress(_ imagePicker: ImagePickerController, images: [UIImage])
    func doneButtonDidPress(_ imagePicker: ImagePickerController, images: [UIImage])
    func cancelButtonDidPress(_ imagePicker: ImagePickerController)
}

open class ImagePickerController: UIViewController {
    
    let configuration: Configuration
    
    struct GestureConstants {
        static let maximumHeight: CGFloat = 200
        static let minimumHeight: CGFloat = 125
        static let velocity: CGFloat = 100
    }
    
    open lazy var galleryView: ImageGalleryView = { [unowned self] in
        let galleryView = ImageGalleryView(configuration: self.configuration)
//        galleryView.delegate = self
        galleryView.selectedStack = self.stack
        galleryView.collectionView.layer.anchorPoint = CGPoint(x: 0, y: 0)
        galleryView.imageLimit = self.imageLimit
        
        return galleryView
        }()
    
    open lazy var bottomContainer: BottomContainerView = { [unowned self] in
        let view = BottomContainerView(configuration: self.configuration)
        view.backgroundColor = self.configuration.bottomContainerColor
        view.delegate = self
        
        return view
        }()
    
    open lazy var topView: TopView = { [unowned self] in
        let view = TopView(configuration: self.configuration)
        view.backgroundColor = UIColor.clear
        view.delegate = self
        
        return view
        }()
    
    lazy var cameraController: CameraView = { [unowned self] in
        let controller = CameraView(configuration: self.configuration)
        controller.delegate = self
        controller.startOnFrontCamera = self.startOnFrontCamera
        
        return controller
        }()
    
    lazy var panGestureRecognizer: UIPanGestureRecognizer = { [unowned self] in
        let gesture = UIPanGestureRecognizer()
        gesture.addTarget(self, action: #selector(panGestureRecognizerHandler(_:)))
        
        return gesture
        }()
    
    lazy var volumeView: MPVolumeView = { [unowned self] in
        let view = MPVolumeView()
        view.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        
        return view
        }()
    
    var volume = AVAudioSession.sharedInstance().outputVolume
    
    @objc open weak var delegate: ImagePickerDelegate?
    open var stack = ImageStack()
    @objc open var imageLimit = 0
    open var preferredImageSize: CGSize?
    open var startOnFrontCamera = false
    var totalSize: CGSize { return UIScreen.main.bounds.size }
    var initialFrame: CGRect?
    var initialContentOffset: CGPoint?
    var numberOfCells: Int?
    var statusBarHidden = true
    
    fileprivate var isTakingPicture = false
    open var doneButtonTitle: String? {
        didSet {
            if let doneButtonTitle = doneButtonTitle {
                bottomContainer.doneButton.setTitle(doneButtonTitle, for: UIControl.State())
            }
        }
    }
    
    // MARK: - Initialization
    
    @objc public required init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
    }
    
    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        self.configuration = Configuration()
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        self.configuration = Configuration()
        super.init(coder: aDecoder)
    }
    
    // MARK: - View lifecycle
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        for subview in [cameraController.view, galleryView, bottomContainer, topView] {
            view.addSubview(subview!)
            subview?.translatesAutoresizingMaskIntoConstraints = false
        }
        
        view.addSubview(volumeView)
        view.sendSubviewToBack(volumeView)
        
        view.backgroundColor = UIColor.white
        view.backgroundColor = configuration.mainColor
        
        cameraController.view.addGestureRecognizer(panGestureRecognizer)
        
        subscribe()
        setupConstraints()
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if configuration.managesAudioSession {
            _ = try? AVAudioSession.sharedInstance().setActive(true)
        }
        
        statusBarHidden = UIApplication.shared.isStatusBarHidden
    }
    
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let galleryHeight: CGFloat = UIScreen.main.nativeBounds.height == 960
            ? ImageGalleryView.Dimensions.galleryBarHeight : GestureConstants.minimumHeight
        
        galleryView.collectionView.transform = CGAffineTransform.identity
        galleryView.collectionView.contentInset = UIEdgeInsets.zero
        
        galleryView.frame = CGRect(x: totalSize.width - bottomContainer.frame.width - galleryHeight,
                                   y: 0,
                                   width: galleryHeight,
                                   height: totalSize.height)
        galleryView.updateFrames()
        checkStatus(nil)
        
        initialFrame = galleryView.frame
        initialContentOffset = galleryView.collectionView.contentOffset
        
        UIAccessibility.post(notification: UIAccessibility.Notification.screenChanged,
                             argument: UIAccessibility.Notification.screenChanged);
    }
    
    open func resetAssets() {
        self.stack.resetAssets([])
    }
    
    func checkStatus(_ completion: ((PHAuthorizationStatus) -> Void)?) {
        let currentStatus = PHPhotoLibrary.authorizationStatus()
        guard currentStatus != .authorized else {
            if let completion = completion {
                completion(.authorized)
            }
            return
        }
        
        if currentStatus == .notDetermined { hideViews() }
        
        PHPhotoLibrary.requestAuthorization { (authorizationStatus) -> Void in
            DispatchQueue.main.async {
                if authorizationStatus == .denied {
                    self.presentAskPermissionAlert()
                } else if authorizationStatus == .authorized {
                    self.permissionGranted()
                }
                
                if let completion = completion {
                    completion(authorizationStatus)
                }
            }
            
        }
    }
    
    func presentAskPermissionAlert() {
        let alertController = UIAlertController(title: configuration.requestPermissionTitle, message: configuration.requestPermissionMessage, preferredStyle: .alert)
        
        let alertAction = UIAlertAction(title: configuration.OKButtonTitle, style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.openURL(settingsURL)
            }
        }
        
        let cancelAction = UIAlertAction(title: configuration.cancelButtonTitle, style: .cancel) { _ in
            self.dismiss(animated: true, completion: nil)
        }
        
        alertController.addAction(alertAction)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    func hideViews() {
        enableGestures(false)
    }
    
    func permissionGranted() {
        galleryView.fetchPhotos()
        enableGestures(true)
    }
    
    // MARK: - Notifications
    
    deinit {
        if configuration.managesAudioSession {
            _ = try? AVAudioSession.sharedInstance().setActive(false)
        }
        
        NotificationCenter.default.removeObserver(self)
    }
    
    func subscribe() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(adjustButtonTitle(_:)),
                                               name: NSNotification.Name(rawValue: ImageStack.Notifications.imageDidPush),
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(adjustButtonTitle(_:)),
                                               name: NSNotification.Name(rawValue: ImageStack.Notifications.imageDidDrop),
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(dismissIfNeeded),
                                               name: NSNotification.Name(rawValue: ImageStack.Notifications.imageDidDrop),
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didReloadAssets(_:)),
                                               name: NSNotification.Name(rawValue: ImageStack.Notifications.stackDidReload),
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(volumeChanged(_:)),
                                               name: NSNotification.Name(rawValue: "AVSystemController_SystemVolumeDidChangeNotification"),
                                               object: nil)
    }
    
    @objc func didReloadAssets(_ notification: Notification) {
        adjustButtonTitle(notification)
        galleryView.collectionView.reloadData()
        galleryView.collectionView.setContentOffset(CGPoint.zero, animated: false)
    }
    
    @objc func volumeChanged(_ notification: Notification) {
        guard configuration.allowVolumeButtonsToTakePicture,
            let slider = volumeView.subviews.filter({ $0 is UISlider }).first as? UISlider,
            let userInfo = (notification as NSNotification).userInfo,
            let changeReason = userInfo["AVSystemController_AudioVolumeChangeReasonNotificationParameter"] as? String, changeReason == "ExplicitVolumeChange" else { return }
        
        slider.setValue(volume, animated: false)
        takePicture()
    }
    
    @objc func adjustButtonTitle(_ notification: Notification) {
        guard let sender = notification.object as? ImageStack else { return }
        
        let title = !sender.assets.isEmpty ?
            configuration.doneButtonTitle : configuration.cancelButtonTitle
        bottomContainer.doneButton.setTitle(title, for: UIControl.State())
    }
    
    @objc func dismissIfNeeded() {
        // If only one image is requested and a push occures, automatically dismiss the ImagePicker
        if imageLimit == 1 {
            doneButtonDidPress()
        }
    }
    
    // MARK: - Helpers
    
    open override var prefersStatusBarHidden: Bool {
        return statusBarHidden
    }
    
    open func collapseGalleryView(_ completion: (() -> Void)?) {
        galleryView.collectionViewLayout.invalidateLayout()
        UIView.animate(withDuration: 0.3, animations: {
            self.updateGalleryViewFrames(self.galleryView.topSeparator.frame.width)
            self.galleryView.collectionView.transform = CGAffineTransform.identity
            self.galleryView.collectionView.contentInset = UIEdgeInsets.zero
        }, completion: { _ in
            completion?()
        })
    }
    
    open func showGalleryView() {
        galleryView.collectionViewLayout.invalidateLayout()
        UIView.animate(withDuration: 0.3, animations: {
            self.updateGalleryViewFrames(GestureConstants.minimumHeight)
            self.galleryView.collectionView.transform = CGAffineTransform.identity
            self.galleryView.collectionView.contentInset = UIEdgeInsets.zero
        })
    }
    
    open func expandGalleryView() {
        galleryView.collectionViewLayout.invalidateLayout()
        
        UIView.animate(withDuration: 0.3, animations: {
            self.updateGalleryViewFrames(GestureConstants.maximumHeight)
            
            let scale = (GestureConstants.maximumHeight - ImageGalleryView.Dimensions.galleryBarHeight) / (GestureConstants.minimumHeight - ImageGalleryView.Dimensions.galleryBarHeight)
            self.galleryView.collectionView.transform = CGAffineTransform(scaleX: scale, y: scale)
            
            let value = self.view.frame.width * (scale - 1) / scale
            self.galleryView.collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: value, right: 0)
        })
    }
    
    func updateGalleryViewFrames(_ constant: CGFloat) {
        galleryView.frame.origin.x = totalSize.width - bottomContainer.frame.width - constant
        galleryView.frame.size.width = constant
    }
    
    func enableGestures(_ enabled: Bool) {
        galleryView.alpha = enabled ? 1 : 0
        bottomContainer.pickerButton.isEnabled = enabled
        bottomContainer.tapGestureRecognizer.isEnabled = enabled
        topView.flashButton.isEnabled = enabled
        topView.rotateCamera.isEnabled = configuration.canRotateCamera
    }
    
    fileprivate func isBelowImageLimit() -> Bool {
        return (imageLimit == 0 || imageLimit > galleryView.selectedStack.assets.count)
    }
    
    fileprivate func takePicture() {
        guard isBelowImageLimit() && !isTakingPicture else { return }
        isTakingPicture = true
        bottomContainer.pickerButton.isEnabled = false
        bottomContainer.stackView.startLoader()
        let action: () -> Void = { [weak self] in
            guard let `self` = self else { return }
            self.cameraController.takePicture { self.isTakingPicture = false }
        }
        
        if configuration.collapseCollectionViewWhileShot {
            collapseGalleryView(action)
        } else {
            action()
        }
    }
}

// MARK: - Action methods

extension ImagePickerController: BottomContainerViewDelegate {
    
    func pickerButtonDidPress() {
        checkStatus { [weak self] authorizationStatus in
            guard let strongSelf = self, case .authorized = authorizationStatus else { return }
            strongSelf.takePicture()
        }
        
    }
    
    func doneButtonDidPress() {
        var images: [UIImage]
        if let preferredImageSize = preferredImageSize {
            images = AssetManager.resolveAssets(stack.assets, size: preferredImageSize)
        } else {
            images = AssetManager.resolveAssets(stack.assets)
        }
        
        delegate?.doneButtonDidPress(self, images: images)
    }
    
    func cancelButtonDidPress() {
        delegate?.cancelButtonDidPress(self)
    }
    
    func imageStackViewDidPress() {
        var images: [UIImage]
        if let preferredImageSize = preferredImageSize {
            images = AssetManager.resolveAssets(stack.assets, size: preferredImageSize)
        } else {
            images = AssetManager.resolveAssets(stack.assets)
        }
        
        delegate?.wrapperDidPress(self, images: images)
    }
}

extension ImagePickerController: CameraViewDelegate {
    
    func setFlashButtonHidden(_ hidden: Bool) {
        if configuration.flashButtonAlwaysHidden {
            topView.flashButton.isHidden = hidden
        }
    }
    
    func imageToLibrary() {
        guard let collectionSize = galleryView.collectionSize else { return }
        
        galleryView.fetchPhotos {
            guard let asset = self.galleryView.assets.first else { return }
            if self.configuration.allowMultiplePhotoSelection == false {
                self.stack.assets.removeAll()
            }
            self.stack.pushAsset(asset)
        }
        
        galleryView.shouldTransform = true
        bottomContainer.pickerButton.isEnabled = true
        
        UIView.animate(withDuration: 0.3, animations: {
            self.galleryView.collectionView.transform = CGAffineTransform(translationX: collectionSize.width, y: 0)
        }, completion: { _ in
            self.galleryView.collectionView.transform = CGAffineTransform.identity
        })
    }
    
    func cameraNotAvailable() {
        topView.flashButton.isHidden = true
        topView.rotateCamera.isHidden = true
        bottomContainer.pickerButton.isEnabled = false
    }
    
    // MARK: - Rotation
    
    open override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }
    
    open override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return UIApplication.shared.statusBarOrientation
    }
}

// MARK: - TopView delegate methods

extension ImagePickerController: TopViewDelegate {
    
    func flashButtonDidPress(_ title: String) {
        cameraController.flashCamera(title)
    }
    
    func rotateDeviceDidPress() {
        cameraController.rotateCamera()
    }
}

// MARK: - Pan gesture handler

extension ImagePickerController: ImageGalleryPanGestureDelegate {
    
    func panGestureDidStart() {
        guard let collectionSize = galleryView.collectionSize else { return }
        
        initialFrame = galleryView.frame
        initialContentOffset = galleryView.collectionView.contentOffset
        if let contentOffset = initialContentOffset { numberOfCells = Int(contentOffset.y / collectionSize.height) }
    }
    
    @objc func panGestureRecognizerHandler(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)
        
        if gesture.location(in: view).x > galleryView.frame.origin.x - 25 {
            gesture.state == .began ? panGestureDidStart() : panGestureDidChange(translation)
        }
        
        if gesture.state == .ended {
            panGestureDidEnd(translation, velocity: velocity)
        }
    }
    
    func panGestureDidChange(_ translation: CGPoint) {
        guard let initialFrame = initialFrame else { return }
        
        let galleryHeight = initialFrame.width - translation.x
        
        if galleryHeight >= GestureConstants.maximumHeight { return }
        
        if galleryHeight <= ImageGalleryView.Dimensions.galleryBarHeight {
            updateGalleryViewFrames(ImageGalleryView.Dimensions.galleryBarHeight)
        } else if galleryHeight >= GestureConstants.minimumHeight {
            let scale = (galleryHeight - ImageGalleryView.Dimensions.galleryBarHeight) / (GestureConstants.minimumHeight - ImageGalleryView.Dimensions.galleryBarHeight)
            galleryView.collectionView.transform = CGAffineTransform(scaleX: scale, y: scale)
            galleryView.frame.origin.x = initialFrame.origin.x + translation.x
            galleryView.frame.size.width = initialFrame.width - translation.x
            
            let value = view.frame.height * (scale - 1) / scale
            galleryView.collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: value, right: 0)
        } else {
            galleryView.frame.origin.x = initialFrame.origin.x + translation.x
            galleryView.frame.size.width = initialFrame.width - translation.x
        }
        
        galleryView.updateNoImagesLabel()
    }
    
    func panGestureDidEnd(_ translation: CGPoint, velocity: CGPoint) {
        guard let initialFrame = initialFrame else { return }
        let galleryHeight = initialFrame.width - translation.x
        if galleryView.frame.width < GestureConstants.minimumHeight && velocity.x < 0 {
            showGalleryView()
        } else if velocity.x < -GestureConstants.velocity {
            expandGalleryView()
        } else if velocity.x > GestureConstants.velocity || galleryHeight < GestureConstants.minimumHeight {
            collapseGalleryView(nil)
        }
    }
}
