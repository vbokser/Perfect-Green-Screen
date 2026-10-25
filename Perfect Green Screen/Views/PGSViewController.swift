import UIKit
import AVFoundation
import DGCharts

class PGSViewController: UIViewController, CameraManagerDelegate {
    
    // UI Outlets
    @IBOutlet weak var barChartView: BarChartView!
    @IBOutlet weak var bandsSlider: UISlider!
    @IBOutlet weak var bandsTextField: UITextField!
    @IBOutlet weak var cameraView: CameraPreviewView!
    @IBOutlet weak var processedView: UIImageView!
    @IBOutlet weak var exposureLockButton: UIButton!
    @IBOutlet weak var focusLockButton: UIButton!
    @IBOutlet weak var enableHistogram: UISegmentedControl!
    
    // Module managers
    private let cameraManager = CameraManager()
    private let imageProcessor = ImageProcessor()
    private lazy var chartManager = ChartManager(chartView: barChartView)
    private let settingsManager = SettingsManager.shared
    
    // State
    private var numberOfBands: Int = 10 // default value
    private var updateChartTimer: Timer?
    // Frames arrive on a background queue; publish only complete histogram snapshots.
    private let frameLock = NSLock()
    private var pendingHistogram: [Double]?
    private var isCameraViewVisible = false
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up camera manager delegate
        cameraManager.delegate = self
        
        // Configure UI elements
        setupUIElements()
        
        // Update bands from settings
        numberOfBands = settingsManager.currentNumberOfBands
        
        // Add notification observers
        setupNotificationObservers()
        
        _ = cameraManager.createPreviewLayer(for: cameraView)
        NotificationCenter.default.addObserver(self, selector: #selector(resumeCamera), name: UIScene.didActivateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(pauseCamera), name: UIScene.didEnterBackgroundNotification, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Configure view background colors
        cameraView.backgroundColor = UIColor.clear
        processedView.backgroundColor = UIColor.clear
        
        // Configure UI based on settings
        updateHistogramVisibility()
        setupBandsSlider()
        
        isCameraViewVisible = true
        setupTimers()
        resumeCamera()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isCameraViewVisible = false
        updateChartTimer?.invalidate()
        updateChartTimer = nil
        pauseCamera()
    }

    @objc private func resumeCamera() {
        guard isCameraViewVisible else { return }
        cameraManager.startCamera { [weak self] result in
            guard let self = self, self.isCameraViewVisible else { return }
            switch result {
            case .success:
                self.cameraManager.updatePreviewOrientation()
            case .failure(let error):
                guard self.presentedViewController == nil else { return }
                let alert = UIAlertController(title: "Camera Unavailable", message: error.localizedDescription, preferredStyle: .alert)
                if case .permissionDenied = error {
                    alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    })
                }
                alert.addAction(UIAlertAction(title: "OK", style: .cancel))
                self.present(alert, animated: true)
            }
        }
    }

    @objc private func pauseCamera() {
        cameraManager.stopCamera()
    }
    
    // MARK: - UI Setup
    
    private func setupUIElements() {
        cameraView.clipsToBounds = true
        processedView.clipsToBounds = true
        processedView.contentMode = .scaleAspectFit
        processedView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        processedView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        // Setup tap gesture for dismissing keyboard
        let tap = UITapGestureRecognizer(target: self, action: #selector(finishedEditing(_:)))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    
    private func setupNotificationObservers() {
        // Add observer for histogram visibility changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(histogramVisibilityChanged),
            name: NSNotification.Name("HistogramVisibilityChanged"),
            object: nil
        )
        
        // Add observer for max bands value changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(maxBandsValueChanged),
            name: NSNotification.Name("MaxBandsValueChanged"),
            object: nil
        )
    }
    
    private func setupTimers() {
        updateChartTimer?.invalidate()
        updateChartTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            self?.updateChart()
        }
    }

    // MARK: - CameraManagerDelegate

    func cameraManager(_ manager: CameraManager, didUpdatePixelBuffer buffer: CVPixelBuffer) {
        frameLock.lock()
        let bands = numberOfBands
        frameLock.unlock()

        let processedImage = imageProcessor.processBanding(pixelBuffer: buffer, numberOfBands: bands)
        _ = imageProcessor.updateHistogram(from: buffer)
        let histogram = imageProcessor.getHistogramPercentages()
        frameLock.lock()
        pendingHistogram = histogram
        frameLock.unlock()

        DispatchQueue.main.async { [weak self] in
            self?.processedView.image = processedImage
        }
    }

    // MARK: - Chart Updates
    
    @objc private func updateChart() {
        frameLock.lock()
        let histogram = pendingHistogram
        pendingHistogram = nil
        frameLock.unlock()
        if let histogram = histogram { chartManager.updateChart(with: histogram) }
    }

    // MARK: - Settings Updates
    
    @objc private func histogramVisibilityChanged() {
        updateHistogramVisibility()
    }
    
    @objc private func maxBandsValueChanged() {
        setupBandsSlider()
    }
    
    private func updateHistogramVisibility() {
        let isVisible = settingsManager.isHistogramVisible
        chartManager.setChartVisible(isVisible)
    }
    
    private func setupBandsSlider() {
        // Get current settings
        let maxBands = settingsManager.currentMaxBands
        let currentBands = settingsManager.currentNumberOfBands
        
        // Update UI
        bandsSlider.maximumValue = Float(maxBands)
        bandsSlider.value = Float(currentBands)
        bandsTextField.text = "\(currentBands)"
        
        // Update the processing value
        frameLock.lock()
        numberOfBands = currentBands
        frameLock.unlock()
    }
    
    // MARK: - UI Actions
    
    @objc func finishedEditing(_ sender: UITapGestureRecognizer) {
        view.endEditing(true)
    }
    
    @IBAction func viewChangeClicked(_ sender: UISegmentedControl) {
        UIView.performWithoutAnimation {
            cameraView.isHidden = sender.selectedSegmentIndex != 0
            view.layoutIfNeeded()
        }
    }
    
    @IBAction func bandsSliderChanged(_ sender: UISlider) {
        // Get the maximum bands value from settings
        let maxBands = settingsManager.currentMaxBands
        
        // Update the slider's maximum value to match settings
        if sender.maximumValue != Float(maxBands) {
            sender.maximumValue = Float(maxBands)
        }
        
        // Get selected value from slider and clamp it
        let selectedBands = Int(sender.value)
        let validBands = settingsManager.checkBandsRange(numBands: selectedBands)
        
        // Ensure the slider value matches the valid bands
        if Float(validBands) != sender.value {
            sender.value = Float(validBands)
        }
        
        // Update settings and UI
        settingsManager.currentNumberOfBands = validBands
        frameLock.lock()
        numberOfBands = validBands
        frameLock.unlock()
        bandsTextField.text = "\(validBands)"
        
        // Save the valid bands to user defaults
        UserDefaults.standard.set(validBands, forKey: CURRENT_NUMBER_OF_BANDS_STRING)
        
        print("Number of bands = \(numberOfBands)")
    }
    
    @IBAction func focusButtonClicked(_ sender: UIButton) {
        cameraManager.toggleFocusLock { [weak self] in self?.updateFocusLockUI() }
    }
    
    @IBAction func lockButtonClicked(_ sender: UIButton) {
        cameraManager.toggleExposureLock { [weak self] in self?.updateExposureLockUI() }
    }
    
    @IBAction func enableHistogramSegmentedControl(_ sender: UISegmentedControl) {
        // Update settings manager which will post a notification
        let isVisible = sender.selectedSegmentIndex == 0
        settingsManager.isHistogramVisible = isVisible
    }
    
    // MARK: - UI Updates
    
    private func updateFocusLockUI() {
        let imageName = cameraManager.isFocusLocked ? "focus_lock_icon_1920_closed" : "focus_lock_icon_1920_open"
        if let image = UIImage(named: imageName) {
            focusLockButton.setImage(image, for: .normal)
        }
    }
    
    private func updateExposureLockUI() {
        let imageName = cameraManager.isExposureLocked ? "exposure_lock_icon_1920_closed" : "exposure_lock_icon_1920_open"
        if let image = UIImage(named: imageName) {
            exposureLockButton.setImage(image, for: .normal)
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        updateChartTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    private func updateUI() {
        // Update histogram segmented control
        let isVisible = settingsManager.isHistogramVisible
        enableHistogram?.selectedSegmentIndex = isVisible ? 0 : 1
        
        // Update max bands slider and label
        let maxBands = settingsManager.currentMaxBands
        bandsSlider.maximumValue = Float(maxBands)
        bandsSlider.value = Float(maxBands)
        bandsTextField.text = "\(maxBands)"
    }
} 
