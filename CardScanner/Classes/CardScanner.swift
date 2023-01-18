//
//  CardScanner.swift
//  CardScanner
//
//  Created by Narlei Moreira on 09/30/2020.
//  Copyright (c) 2020 Narlei Moreira. All rights reserved.
//

import AVFoundation
import CoreImage
import UIKit
import Vision

@available(iOS 13.0, *)
public class CardScanner: UIViewController {
    // MARK: - Private Properties

    private let captureSession = AVCaptureSession()
    private lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let preview = AVCaptureVideoPreviewLayer(session: self.captureSession)
        preview.videoGravity = .resizeAspectFill
        return preview
    }()

    private let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: AVMediaType.video, position: .back)
    var currentOrientation = UIDevice.current.orientation
    private var viewGuide: PartialTransparentView!

    private var creditCardNumber: String?
    private var creditCardName: String?
    private var creditCardCVV: String?
    private var creditCardDate: String?
    private let videoOutput = AVCaptureVideoDataOutput()

    // MARK: - Public Properties

    public var labelCardNumber: UILabel = UILabel(frame: .zero)
    public var labelCardDate: UILabel = UILabel(frame: .zero)
    public var labelCardCVV: UILabel = UILabel(frame: .zero)
    public var labelHintBottom: UILabel = UILabel(frame: .zero)
    public var labelHintTop: UILabel = UILabel(frame: .zero)
    public var buttonComplete: UIButton = UIButton(frame: .zero)

    public var hintTopText = "Center your card until the fields are recognized"
    public var hintBottomText = "Touch a recognized value to delete the value and try again"
    public var buttonConfirmTitle = "Confirm"
    public var buttonConfirmBackgroundColor: UIColor = .red
    public var viewTitle = "Card scanner"
    let flashButton = UIButton(frame: .zero)
    var flashButtonVertical = [NSLayoutConstraint]()
    var flashButtonHorizontal = [NSLayoutConstraint]()
    var color: UIColor
    // MARK: - Instance dependencies

    private var resultsHandler: (_ number: String?, _ date: String?, _ cvv: String?) -> Void?

    // MARK: - Initializers

    init(color: UIColor, resultsHandler: @escaping (_ number: String?, _ date: String?, _ cvv: String?) -> Void) {
        self.resultsHandler = resultsHandler
        self.color = color
        super.init(nibName: nil, bundle: nil)
    }

    public class func getScanner(color: UIColor, resultsHandler: @escaping (_ number: String?, _ date: String?, _ cvv: String?) -> Void) -> UINavigationController {
        let viewScanner = CardScanner(color: color, resultsHandler: resultsHandler)
        let navigation = UINavigationController(rootViewController: viewScanner)
        return navigation
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func loadView() {
        view = UIView()
    }

    deinit {
        stop()
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        title = viewTitle
//        view.translatesAutoresizingMaskIntoConstraints = false
        let buttomItem = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(self.close))
        buttomItem.tintColor = color
        navigationItem.leftBarButtonItem = buttomItem
        navigationController?.navigationBar.tintColor = color
        let textAttributes = [NSAttributedString.Key.foregroundColor: color]
        navigationController?.navigationBar.titleTextAttributes = textAttributes
        labelCardNumber.translatesAutoresizingMaskIntoConstraints = false
        labelCardNumber.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        labelCardNumber.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(clearCardNumber)))
        labelCardNumber.isUserInteractionEnabled = true
        labelCardNumber.textColor = .white
        view.addSubview(labelCardNumber)
        labelCardDate.translatesAutoresizingMaskIntoConstraints = false
        labelCardDate.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        labelCardDate.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(clearCardDate)))
        labelCardDate.isUserInteractionEnabled = true
        labelCardDate.textColor = .white
        view.addSubview(labelCardDate)
        
        labelCardCVV.translatesAutoresizingMaskIntoConstraints = false
        labelCardCVV.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        labelCardCVV.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(clearCardCVV)))
        labelCardCVV.isUserInteractionEnabled = true
        labelCardCVV.textColor = .white
        view.addSubview(labelCardCVV)
        
        labelHintTop.translatesAutoresizingMaskIntoConstraints = false
        labelHintTop.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        labelHintTop.text = hintTopText
        labelHintTop.numberOfLines = 0
        labelHintTop.textAlignment = .center
        labelHintTop.textColor = .white
        view.addSubview(labelHintTop)
        
        labelHintBottom.translatesAutoresizingMaskIntoConstraints = false
        labelHintBottom.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        labelHintBottom.text = hintBottomText
        labelHintBottom.numberOfLines = 0
        labelHintBottom.textAlignment = .center
        labelHintBottom.textColor = .white
        view.addSubview(labelHintBottom)
        
        buttonComplete.translatesAutoresizingMaskIntoConstraints = false
        buttonComplete.setTitle(buttonConfirmTitle, for: .normal)
        buttonComplete.backgroundColor = buttonConfirmBackgroundColor
        buttonComplete.layer.cornerRadius = 10
        buttonComplete.layer.masksToBounds = true
        buttonComplete.addTarget(self, action: #selector(scanCompleted), for: .touchUpInside)
        view.addSubview(buttonComplete)
        buttonComplete.heightAnchor.constraint(equalToConstant: 50).isActive = true
        buttonComplete.widthAnchor.constraint(equalToConstant: 100).isActive = true
        buttonComplete.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor).isActive = true
                
        flashButton.translatesAutoresizingMaskIntoConstraints = false
        flashButton.setBackgroundImage(UIImage(systemName: "bolt.fill"), for: .normal)
        flashButton.addTarget(self, action: #selector(self.flash), for: .primaryActionTriggered)
        flashButton.tintColor = .white
        view.addSubview(flashButton)
        NSLayoutConstraint.activate([
            flashButton.heightAnchor.constraint(equalToConstant: 40),
            flashButton.widthAnchor.constraint(equalToConstant: 40)
        ])
    }
    public override func viewDidAppear(_ animated: Bool) {
        setupCaptureSession()
        DispatchQueue.global().async {
            self.captureSession.startRunning()
        }
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
//        previewLayer.frame = view.bounds
        if let connection = self.previewLayer.connection {
            let currentDevice = UIDevice.current
            let orientation: UIDeviceOrientation = currentDevice.orientation
            let previewLayerConnection: AVCaptureConnection = connection
            
            if previewLayerConnection.isVideoOrientationSupported {
                switch orientation {
                case .portrait: self.updatePreviewLayer(layer: previewLayerConnection, orientation: .portrait)
                case .landscapeRight: self.updatePreviewLayer(layer: previewLayerConnection, orientation: .landscapeLeft)
                case .landscapeLeft: self.updatePreviewLayer(layer: previewLayerConnection, orientation: .landscapeRight)
                case .portraitUpsideDown: self.updatePreviewLayer(layer: previewLayerConnection, orientation: .portraitUpsideDown)
                default: self.updatePreviewLayer(layer: previewLayerConnection, orientation: .portrait)
                }
            }
        }
    }
    
    // MARK: - Add Views

    private func setupCaptureSession() {
        addCameraInput()
        addPreviewLayer()
        addVideoOutput()
        addGuideView()
    }

    private func addCameraInput() {
        guard let device = device else { return }
        let cameraInput = try! AVCaptureDeviceInput(device: device)
        captureSession.addInput(cameraInput)
    }

    private func addPreviewLayer() {
        view.layer.addSublayer(previewLayer)
    }
    private func updatePreviewLayer(layer: AVCaptureConnection, orientation: AVCaptureVideoOrientation) {
        layer.videoOrientation = orientation
        self.previewLayer.frame = view.safeAreaLayoutGuide.layoutFrame
    }
    public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        // Only change the current orientation if the new one is landscape or
        // portrait. You can't really do anything about flat or unknown.
        let deviceOrientation = UIDevice.current.orientation
        if deviceOrientation.isPortrait || deviceOrientation.isLandscape {
            currentOrientation = deviceOrientation
        }
        
        // Handle device orientation in the preview layer.
        if let videoPreviewLayerConnection = previewLayer.connection {
            if let newVideoOrientation = AVCaptureVideoOrientation(deviceOrientation: deviceOrientation) {
                videoPreviewLayerConnection.videoOrientation = newVideoOrientation
            }
        }
        viewGuide.removeFromSuperview()
        self.addGuideView()
    }
    private func addVideoOutput() {
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as NSString: NSNumber(value: kCVPixelFormatType_32BGRA)] as [String: Any]
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "my.image.handling.queue"))
        captureSession.addOutput(videoOutput)
        guard let connection = captureSession.connections.first,
            connection.isVideoOrientationSupported else {
            return
        }
        connection.automaticallyAdjustsVideoMirroring = true
        
        let orientation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation
        if let newVideoOrientation = AVCaptureVideoOrientation(interfaceOrientation: orientation!) {
            connection.videoOrientation = newVideoOrientation
        } else if orientation!.isLandscape && orientation == .landscapeLeft {
            connection.videoOrientation = .landscapeLeft
        } else if orientation!.isLandscape && orientation == .landscapeRight {
            connection.videoOrientation = .landscapeRight
        } else {
            connection.videoOrientation = .portrait
        }
    }

    private func addGuideView() {
        let screenWidth = self.view.window?.windowScene?.interfaceOrientation == .portrait ? UIScreen.main.bounds.width : UIScreen.main.bounds.height
        let screenHeigth = UIDevice.current.orientation == .portrait ? UIScreen.main.bounds.height : UIScreen.main.bounds.width
        let widht = screenWidth - (screenWidth * 0.2) // 414 - 414 *0.2 */ 331.2
        let height =  widht - (widht * 0.45) // 331.2 - 331.2 * 0.45 // */ 228.0
        let viewX = (UIScreen.main.bounds.width / 2) - (widht / 2)
        let viewY = (UIScreen.main.bounds.height / 2) - (height / 2) - 50
        print("^ positions:", viewX, "screenWidth:", screenWidth, "width:", widht)
        print("^ positions:", viewY, "ScreenHeigth:", screenHeigth, "heigth:", height)
        viewGuide = PartialTransparentView(rectsArray: [CGRect(x: viewX, y: viewY, width: widht, height: height)])

        view.addSubview(viewGuide)
        viewGuide.translatesAutoresizingMaskIntoConstraints = false
        viewGuide.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 0).isActive = true
        viewGuide.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: 0).isActive = true
        viewGuide.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0).isActive = true
        viewGuide.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 0).isActive = true
        view.bringSubviewToFront(viewGuide)

        let labelCardNumberX = viewX + 20
        let labelCardNumberY = viewY + 50
        
        view.bringSubviewToFront(labelCardNumber)
        let labelCardDateX = viewX + 20
        let labelCardDateY = viewY + 90
        view.bringSubviewToFront(labelCardDate)
               
        let labelCardCVVX = (viewX + widht) - 75
        let labelCardCVVY = viewY + 50
        view.bringSubviewToFront(labelCardCVV)
//        let labelHintTopY = viewY - 40

        view.bringSubviewToFront(labelHintTop)
        view.bringSubviewToFront(labelHintBottom)
        view.bringSubviewToFront(buttonComplete)
        view.bringSubviewToFront(flashButton)
        flashButtonVertical = [
            flashButton.bottomAnchor.constraint(equalTo: buttonComplete.topAnchor, constant:  -45),
            flashButton.centerXAnchor.constraint(equalTo: buttonComplete.centerXAnchor),
            labelHintBottom.bottomAnchor.constraint(equalTo: flashButton.topAnchor, constant: -30),
            labelHintTop.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: viewY - 20),
            buttonComplete.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -70),
            labelCardNumber.leftAnchor.constraint(equalTo: view.leftAnchor, constant: labelCardNumberX),
            labelCardNumber.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: labelCardNumberY),
            labelCardCVV.leftAnchor.constraint(equalTo: view.leftAnchor, constant: labelCardCVVX),
            labelCardCVV.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: labelCardNumberY),
            labelCardDate.leftAnchor.constraint(equalTo: view.leftAnchor, constant: labelCardDateX),
            labelCardDate.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: labelCardDateY),
            labelHintTop.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            labelHintBottom.centerXAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.centerXAnchor)
        ]
        flashButtonHorizontal = [
            flashButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            flashButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -45),
            labelHintBottom.bottomAnchor.constraint(equalTo: buttonComplete.topAnchor, constant: -10),
            labelHintTop.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            buttonComplete.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            labelCardNumber.leftAnchor.constraint(equalTo: view.leftAnchor, constant: labelCardNumberX),
            labelCardNumber.topAnchor.constraint(equalTo: view.topAnchor, constant: labelCardNumberY),
            labelCardCVV.leftAnchor.constraint(equalTo: view.leftAnchor, constant: labelCardCVVX),
            labelCardCVV.topAnchor.constraint(equalTo: view.topAnchor, constant: labelCardCVVY),
            labelCardDate.leftAnchor.constraint(equalTo: view.leftAnchor, constant: labelCardDateX),
            labelCardDate.topAnchor.constraint(equalTo: view.topAnchor, constant: labelCardDateY),
            labelHintTop.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            labelHintBottom.centerXAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.centerXAnchor)
        ]
        if self.view.window?.windowScene?.interfaceOrientation == .portrait {
            NSLayoutConstraint.deactivate(flashButtonHorizontal)
            NSLayoutConstraint.activate(flashButtonVertical)
        } else {
            NSLayoutConstraint.deactivate(flashButtonVertical)
            NSLayoutConstraint.activate(flashButtonHorizontal)
        }
        view.backgroundColor = .black
        view.layoutIfNeeded()
    }
    @objc public func flash() {
        guard let device else {return}
        if device.hasTorch {
            do {
                try device.lockForConfiguration()
                device.torchMode = device.isTorchActive ? .off : .on
                device.unlockForConfiguration()
                let imageName = device.isTorchActive ? "bolt.fill" : "bolt.slash.fill"
                self.flashButton.setBackgroundImage(UIImage(systemName: imageName), for: .normal)
            } catch {
                print("^ Torch could not be used")
            }
        } else {
            print("^ Torch is not available")
        }
    }

    // MARK: - Clear on touch

    @objc func clearCardNumber() {
        labelCardNumber.text = ""
        creditCardNumber = nil
    }

    @objc func clearCardDate() {
        labelCardDate.text = ""
        creditCardDate = nil
    }

    @objc func clearCardCVV() {
        labelCardCVV.text = ""
        creditCardCVV = nil
    }

    // MARK: - Completed process

    @objc func close() {
        stop()
        dismiss(animated: true, completion: nil)
    }
    
    @objc func scanCompleted() {
        resultsHandler(creditCardNumber, creditCardDate, creditCardCVV)
        close()
    }

    private func stop() {
        captureSession.stopRunning()
    }

    // MARK: - Payment detection

    private func handleObservedPaymentCard(in frame: CVImageBuffer) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.extractPaymentCardData(frame: frame)
        }
    }

    private func extractPaymentCardData(frame: CVImageBuffer) {
        let ciImage = CIImage(cvImageBuffer: frame)
//        let widht = UIScreen.main.bounds.width - (UIScreen.main.bounds.width * 0.2)
//        let height = widht - (widht * 0.45)
//        let viewX = (UIScreen.main.bounds.width / 2) - (widht / 2)
//        let viewY = (UIScreen.main.bounds.height / 2) - (height / 2) - 100 + height

        let resizeFilter = CIFilter(name: "CILanczosScaleTransform")!

        // Desired output size
//        let targetSize = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)

//        // Compute scale and corrective aspect ratio
//        let scale = targetSize.height / ciImage.extent.height
//        let aspectRatio = targetSize.width / (ciImage.extent.width * scale)

        // Apply resizing
        resizeFilter.setValue(ciImage, forKey: kCIInputImageKey)
        resizeFilter.setValue(1, forKey: kCIInputScaleKey)
//        resizeFilter.setValue(aspectRatio, forKey: kCIInputAspectRatioKey)
        let outputImage = resizeFilter.outputImage

        let croppedImage =  outputImage! //outputImage!.cropped(to: CGRect(x: viewX, y: viewY, width: widht, height: height))

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false

        let stillImageRequestHandler = VNImageRequestHandler(ciImage: croppedImage, options: [:])
        try? stillImageRequestHandler.perform([request])

        guard let texts = request.results, texts.count > 0 else {
            // no text detected
            return
        }

        let arrayLines = texts.flatMap({ $0.topCandidates(20).map({ $0.string }) })

        for line in arrayLines {
//            print("Trying to parse: \(line)")

            let trimmed = line.replacingOccurrences(of: " ", with: "")

            if creditCardNumber == nil &&
                trimmed.count >= 15 &&
                trimmed.count <= 16 &&
                trimmed.isOnlyNumbers {
                creditCardNumber = line
                DispatchQueue.main.async {
                    self.labelCardNumber.text = line
                    self.tapticFeedback()
                }
                continue
            }

            if creditCardCVV == nil &&
                trimmed.count == 3 &&
                trimmed.isOnlyNumbers {
                creditCardCVV = line
                DispatchQueue.main.async {
                    self.labelCardCVV.text = line
                    self.tapticFeedback()
                }
                continue
            }

            if creditCardDate == nil &&
                trimmed.count >= 5 && // 12/20
                trimmed.count <= 7 && // 12/2020
                trimmed.isDate {
                
                creditCardDate = line
                DispatchQueue.main.async {
                    self.labelCardDate.text = line
                    self.tapticFeedback()
                }
                continue
            }

            // Not used yet
            if creditCardName == nil &&
                trimmed.count > 10 &&
                line.contains(" ") &&
                trimmed.isOnlyAlpha {
                
                creditCardName = line
                continue
            }
        }
    }

    private func tapticFeedback() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CardScanner: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let frame = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("^ p unable to get image from sample buffer")
            return
        }

        handleObservedPaymentCard(in: frame)
    }
}

// MARK: - Extensions

private extension String {
    var isOnlyAlpha: Bool {
        return !isEmpty && range(of: "[^a-zA-Z]", options: .regularExpression) == nil
    }

    var isOnlyNumbers: Bool {
        return !isEmpty && range(of: "[^0-9]", options: .regularExpression) == nil
    }

    // Date Pattern MM/YY or MM/YYYY
    var isDate: Bool {
        let arrayDate = components(separatedBy: "/")
        if arrayDate.count == 2 {
            let currentYear = Calendar.current.component(.year, from: Date())
            if let month = Int(arrayDate[0]), let year = Int(arrayDate[1]) {
                if month > 12 || month < 1 {
                    return false
                }
                if year < (currentYear - 2000 + 20) && year >= (currentYear - 2000) { // Between current year and 20 years ahead
                    return true
                }
                if year >= currentYear && year < (currentYear + 20) { // Between current year and 20 years ahead
                    return true
                }
            }
        }
        return false
    }
}

// MARK: - Class PartialTransparentView

class PartialTransparentView: UIView {
    var rectsArray: [CGRect]?

    convenience init(rectsArray: [CGRect]) {
        self.init()

        self.rectsArray = rectsArray

        backgroundColor = UIColor.black.withAlphaComponent(0.6)
        isOpaque = false
    }

    override func draw(_ rect: CGRect) {
        backgroundColor?.setFill()
        UIRectFill(rect)

        guard let rectsArray = rectsArray else {
            return
        }

        for holeRect in rectsArray {
            let path = UIBezierPath(roundedRect: holeRect, cornerRadius: 10)

            let holeRectIntersection = rect.intersection(holeRect)

            UIRectFill(holeRectIntersection)

            UIColor.clear.setFill()
            UIGraphicsGetCurrentContext()?.setBlendMode(CGBlendMode.copy)
            path.fill()
        }
    }
}
extension AVCaptureVideoOrientation {
    init?(deviceOrientation: UIDeviceOrientation) {
        switch deviceOrientation {
        case .portrait: self = .portrait
        case .portraitUpsideDown: self = .portraitUpsideDown
        case .landscapeLeft: self = .landscapeRight
        case .landscapeRight: self = .landscapeLeft
        default: return nil
        }
    }
    init?(interfaceOrientation: UIInterfaceOrientation) {
        switch interfaceOrientation {
        case .portrait: self = .portrait
        case .portraitUpsideDown: self = .portraitUpsideDown
        case .landscapeLeft: self = .landscapeRight
        case .landscapeRight: self = .landscapeLeft
        default: return nil
        }
    }
}
