import UIKit
import AVFoundation
import Vision

final class ViewController: UIViewController {
    private lazy var layersView: LayersView = {
        return LayersView(frame: self.view.frame)
    }()
    private lazy var modeLabel: UILabel = {
        let label = UILabel()
        label.textColor = .blue
        label.text = self.mode.description
        return label
    }()
    private lazy var resetButton: UIButton = {
        let button = UIButton()
        button.setTitle("Reset", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(colorLiteralRed: 0, green: 0, blue: 1, alpha: 0.5)
        button.addTarget(self, action: #selector(resetButtonTouched), for: .touchUpInside)
        return button
    }()
    private lazy var switchDetectionModeButton: UIButton = {
        let button = UIButton()
        button.setTitle("Switch Mode", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(colorLiteralRed: 0, green: 0, blue: 1, alpha: 0.5)
        button.addTarget(self, action: #selector(switchDetectionModeButtonTouched), for: .touchUpInside)
        return button
    }()
    private lazy var verticalStackView: UIStackView = {
        let view  = UIStackView(arrangedSubviews: [self.modeLabel, self.resetButton, self.switchDetectionModeButton])
        view.axis = .vertical
        view.alignment = .fill
        view.distribution = .fill
        view.spacing = 8
        view.backgroundColor = .clear
        return view
    }()
    
    private lazy var device: AVCaptureDevice? = {
        let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        return device
    }()
    private lazy var deviceInput: AVCaptureDeviceInput? = {
        guard let device = self.device else { return nil }
        do {
            return try AVCaptureDeviceInput(device: device)
        } catch {
            print("Failed to initialize AVCaptureDeviceInput." ); return nil
        }
    }()
    private lazy var videoDataOutput: AVCaptureVideoDataOutput = {
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.setSampleBufferDelegate(self, queue: self.sampleBufferQueue)
        return videoDataOutput
    }()
    private lazy var session: AVCaptureSession? = {
        guard let deviceInput = self.deviceInput else { return nil }
        let session = AVCaptureSession()
        session.addInput(deviceInput)
        session.addOutput(self.videoDataOutput)
        return session
    }()
    private lazy var videoPreviewLayer: AVCaptureVideoPreviewLayer? = {
        guard let session = self.session else { return nil }
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.frame = self.view.frame
        layer.connection?.videoOrientation = .portrait
        layer.videoGravity = .resizeAspect
        return layer
    }()
    private lazy var sampleBufferQueue: DispatchQueue = {
        return DispatchQueue(label: "sample.queue")
    }()
    
    private lazy var detectRectanglesRequest: VNDetectRectanglesRequest = {
        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 5
        return request
    }()
    private lazy var detectFacesRequest: VNDetectFaceRectanglesRequest = {
        let request = VNDetectFaceRectanglesRequest()
        return request
    }()
    private lazy var sequenceRequestHandler: VNSequenceRequestHandler = {
        return VNSequenceRequestHandler()
    }()
    
    private var mode: DetectionMode = .faces {
        didSet {
            reset()
            modeLabel.text = mode.description
        }
    }
    
    private var observations = [UUID: VNDetectedObjectObservation]()
    private let confidenceThreshold: VNConfidence = 0.3
    private let orientation: Int32 = 4
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setup()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { [weak self] granted in
                guard let strongSelf = self else { return }
                guard granted else { print("You need to authorize camera access in this app."); return }
                DispatchQueue.main.async {
                    strongSelf.setup()
                }
            })
        default:
            print("You need to authorize camera access in this app."); break
        }
    }
    
    private func setup() {
        guard let session = session else { print("Failed to prepare session."); return }
        guard let videoPreviewLayer = videoPreviewLayer else { print("Failed to prepare videoPreviewLayer."); return }
        
        view.layer.addSublayer(videoPreviewLayer)
        view.addSubview(layersView)
        view.addSubview(verticalStackView)
        verticalStackView.frame = CGRect(x: 240, y: 300, width: 140, height: 120)
        
        session.startRunning()
    }
    
    @objc func resetButtonTouched() {
        reset()
    }
    
    @objc func switchDetectionModeButtonTouched() {
        switchDetectionMode()
    }
    
    private func reset() {
        layersView.reset()
        observations.removeAll()
    }
    
    private func switchDetectionMode() {
        switch mode {
        case .rectangles: mode = .faces
        case .faces: mode = .rectangles
        }
        observations.removeAll()
    }
}

// MARK: AVCaptureVideoDataOutputSampleBufferDelegate
extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let cvImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        guard !observations.isEmpty else {
            detectObjects(in: cvImageBuffer); return
        }
        
        trackObjects(in: cvImageBuffer)
    }
    
    private func detectObjects(in imageBuffer: CVImageBuffer) {
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: imageBuffer, orientation: orientation, options: [:])
        let request: VNRequest
        do {
            switch mode {
            case .rectangles: request = detectRectanglesRequest
            case .faces: request = detectFacesRequest
            }
            try requestHandler.perform([request])
        } catch {
            print(error); return
        }
        guard let results = request.results else { return }
        
        let observations = results as! [VNDetectedObjectObservation]
        print("mode: \(mode), number of detected observations: \(observations.count)")
        
        observations
            .filter { $0.confidence > self.confidenceThreshold }
            .forEach { self.observations[$0.uuid] = $0 }
    }
    
    private func trackObjects(in imageBuffer: CVImageBuffer) {
        let requests = observations.map { observation -> VNTrackObjectRequest in
            let request = VNTrackObjectRequest(detectedObjectObservation: observation.1, completionHandler: handleTrackingCompletion)
            request.trackingLevel = .accurate
            return request
        }
        do {
            try sequenceRequestHandler.perform(requests, on: imageBuffer, orientation: orientation)
        } catch {
            print(error)
        }
    }
    
    private func handleTrackingCompletion(_ request: VNRequest, error: Error?) {
        if let error = error { print(error); return }
        guard let results = request.results else { return }
        print("num of results: \(results.count)")
        
        guard let observation = (results
            .flatMap { $0 as? VNDetectedObjectObservation }
            .first) else {
                print("Observation could not be found."); return
        }
        
        DispatchQueue.main.async {
            self.updateLayers(with: observation)
        }
    }
    
    private func updateLayers(with observation: VNDetectedObjectObservation) {
        guard observation.confidence > confidenceThreshold else { return }
        guard observations[observation.uuid] != nil else { return }
        
        observations[observation.uuid] = observation
        let boundingBox = observation.boundingBox
        let rect = videoPreviewLayer!.layerRectConverted(fromMetadataOutputRect: boundingBox)
        let observationArea = ObservationArea(uuid: observation.uuid, bounds: rect)
        layersView.update(with: [observationArea])
    }
}

