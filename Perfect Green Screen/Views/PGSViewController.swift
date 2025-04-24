import UIKit
import AVFoundation
import DGCharts

class PGSViewController: UIViewController, CameraManagerDelegate {
    
    // UI Outlets
    @IBOutlet weak var barChartView: BarChartView!
    @IBOutlet weak var bandsSlider: UISlider!
    @IBOutlet weak var bandsTextField: UITextField!
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var processedView: UIImageView!
    @IBOutlet weak var exposureLockButton: UIButton!
    @IBOutlet weak var focusLockButton: UIButton!
    
    // Module managers
    private let cameraManager = CameraManager()
    private let imageProcessor = ImageProcessor()
    private lazy var chartManager = ChartManager(chartView: barChartView)
    private let settingsManager = SettingsManager.shared
    
    // State
    private var numberOfBands: Int = 10 // default value
    private var updateChartTimer: Timer?
    private var doUpdateCharts: Bool = false
    
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
        
        // Start chart update timer
        setupTimers()
        
        // Print camera details for debugging
        cameraManager.printCameraDetails()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Configure view background colors
        cameraView.backgroundColor = UIColor.clear
        processedView.backgroundColor = UIColor.clear
        
        // Set up camera and preview layer
        cameraManager.setupCamera(with: .vga640x480)
        let previewLayer = cameraManager.createPreviewLayer(for: cameraView)
        cameraView.layer.addSublayer(previewLayer)
        
        // Configure UI based on settings
        updateHistogramVisibility()
        setupBandsSlider()
        
        // Start the camera
        cameraManager.startCamera()
    }
    
    // MARK: - UI Setup
    
    private func setupUIElements() {
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
        // Create timer for chart updates
        updateChartTimer = Timer.scheduledTimer(
            timeInterval: 0.75,
            target: self,
            selector: #selector(updateChart),
            userInfo: nil,
            repeats: true
        )
    }
    
    // MARK: - CameraManagerDelegate
    
    func cameraManager(_ manager: CameraManager, didReceiveFrame image: UIImage?) {
        // Not using the raw frame - we're using the processed one
    }
    
    func cameraManager(_ manager: CameraManager, didUpdatePixelBuffer buffer: CVPixelBuffer) {
        // Process the image with banding effect
        if let processedImage = imageProcessor.processBanding(pixelBuffer: buffer, numberOfBands: self.numberOfBands) {
            DispatchQueue.main.async { [weak self] in
                self?.processedView.image = processedImage
            }
        }
        
        // Update histogram data
        _ = imageProcessor.updateHistogram(from: buffer)
        doUpdateCharts = true
    }
    
    // MARK: - Chart Updates
    
    @objc private func updateChart() {
        if !doUpdateCharts {
            return
        }
        
        // Get histogram percentages and update chart
        let percentages = imageProcessor.getHistogramPercentages()
        chartManager.updateChart(with: percentages)
        
        doUpdateCharts = false
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
        numberOfBands = currentBands
    }
    
    // MARK: - UI Actions
    
    @objc func finishedEditing(_ sender: UITapGestureRecognizer) {
        view.endEditing(true)
    }
    
    @IBAction func viewChangeClicked(_ sender: UISegmentedControl) {
        cameraView.isHidden = sender.selectedSegmentIndex != 0
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
        let validBands = min(selectedBands, maxBands)
        
        // Ensure the slider value matches the valid bands
        if Float(validBands) != sender.value {
            sender.value = Float(validBands)
        }
        
        // Update settings and UI
        settingsManager.currentNumberOfBands = validBands
        numberOfBands = validBands
        bandsTextField.text = "\(validBands)"
        
        // Save the valid bands to user defaults
        UserDefaults.standard.set(validBands, forKey: CURRENT_NUMBER_OF_BANDS_STRING)
        
        print("Number of bands = \(numberOfBands)")
    }
    
    @IBAction func focusButtonClicked(_ sender: UIButton) {
        if cameraManager.toggleFocusLock() {
            updateFocusLockUI()
        }
    }
    
    @IBAction func lockButtonClicked(_ sender: UIButton) {
        if cameraManager.toggleExposureLock() {
            updateExposureLockUI()
        }
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
} 
