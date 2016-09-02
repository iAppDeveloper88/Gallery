import UIKit
import Cartography
import AVFoundation

class CameraController: UIViewController, CameraManDelegate, CameraViewDelegate, CartDelegate {

  var locationManager: LocationManager?
  lazy var cameraMan: CameraMan = self.makeCameraMan()
  lazy var cameraView: CameraView = self.makeCameraView()

  // MARK: - Life cycle

  override func viewDidLoad() {
    super.viewDidLoad()

    setup()
    setupLocation()

    cameraMan.setup()
  }

  override func viewWillAppear(animated: Bool) {
    super.viewWillAppear(animated)

    locationManager?.start()
  }

  override func viewWillDisappear(animated: Bool) {
    super.viewWillDisappear(animated)

    locationManager?.stop()
  }

  // MARK: - Setup

  func setup() {
    view.addSubview(cameraView)

    cameraView.translatesAutoresizingMaskIntoConstraints = false

    constrain(cameraView) { cameraView in
      cameraView.edges == cameraView.superview!.edges
    }

    cameraView.closeButton.addTarget(self, action: #selector(closeButtonTouched(_:)), forControlEvents: .TouchUpInside)
    cameraView.flashButton.addTarget(self, action: #selector(flashButtonTouched(_:)), forControlEvents: .TouchUpInside)
    cameraView.rotateButton.addTarget(self, action: #selector(rotateButtonTouched(_:)), forControlEvents: .TouchUpInside)
    cameraView.stackView.addTarget(self, action: #selector(stackViewTouched(_:)), forControlEvents: .TouchUpInside)
    cameraView.shutterButton.addTarget(self, action: #selector(shutterButtonTouched(_:)), forControlEvents: .TouchUpInside)
    cameraView.doneButton.addTarget(self, action: #selector(doneButtonTouched(_:)), forControlEvents: .TouchUpInside)
  }

  func setupLocation() {
    if Config.Camera.recordLocation {
      locationManager = LocationManager()
    }
  }

  // MARK: - Action

  func closeButtonTouched(button: UIButton) {
    EventHub.shared.close?()
  }

  func flashButtonTouched(button: UIButton) {
    cameraView.flashButton.toggle()

    if let flashMode = AVCaptureFlashMode(rawValue: cameraView.flashButton.selectedIndex) {
      cameraMan.flash(flashMode)
    }
  }

  func rotateButtonTouched(button: UIButton) {
    UIView.animateWithDuration(0.3, animations: {
      self.cameraView.rotateOverlayView.alpha = 1
    }, completion: { _ in
      self.cameraMan.switchCamera {
        UIView.animateWithDuration(0.7) {
          self.cameraView.rotateOverlayView.alpha = 0
        }
      }
    })
  }

  func stackViewTouched(stackView: StackView) {
    EventHub.shared.stackViewTouched?()
  }

  func shutterButtonTouched(button: ShutterButton) {
    guard let previewLayer = cameraView.previewLayer else { return }

    button.enabled = false
    UIView.animateWithDuration(0.1, animations: {
      self.cameraView.shutterOverlayView.alpha = 1
    }, completion: { _ in
      UIView.animateWithDuration(0.1) {
        self.cameraView.shutterOverlayView.alpha = 0
      }
    })

    self.cameraView.stackView.startLoading()
    cameraMan.takePhoto(previewLayer, location: locationManager?.latestLocation) { asset in
      button.enabled = true
      self.cameraView.stackView.stopLoading()

      if let asset = asset {
        Cart.shared.add(Image(asset: asset), newlyTaken: true)
      }
    }
  }

  func doneButtonTouched(button: UIButton) {
    EventHub.shared.doneWithImages?()
  }

  // MARK: - CameraManDelegate

  func cameraManDidStart(cameraMan: CameraMan) {
    cameraView.setupPreviewLayer(cameraMan.session)
  }

  func cameraManNotAvailable(cameraMan: CameraMan) {
    cameraView.focusImageView.hidden = true
  }

  func cameraMan(cameraMan: CameraMan, didChangeInput input: AVCaptureDeviceInput) {
    cameraView.flashButton.hidden = !input.device.hasFlash
  }

  // MARK: - CameraViewDelegate

  func cameraView(cameraView: CameraView, didTouch point: CGPoint) {
    cameraMan.focus(point)
  }

  // MARK: - CartDelegate

  func cart(cart: Cart, didAdd image: Image, newlyTaken: Bool) {
    cameraView.stackView.reload(cart.images, added: true)
    refreshView()
  }

  func cart(cart: Cart, didRemove image: Image) {
    cameraView.stackView.reload(cart.images)
    refreshView()
  }

  func cartDidReload(cart: Cart) {
    cameraView.stackView.reload(cart.images)
    refreshView()
  }

  // MARK: - View

  func refreshView() {
    cameraView.doneButton.enabled = !Cart.shared.images.isEmpty
    cameraView.stackView.hidden = Cart.shared.images.isEmpty
  }

  // MARK: - Controls

  func makeCameraMan() -> CameraMan {
    let man = CameraMan()
    man.delegate = self

    return man
  }

  func makeCameraView() -> CameraView {
    let cameraView = CameraView()
    cameraView.delegate = self

    return cameraView
  }
}
