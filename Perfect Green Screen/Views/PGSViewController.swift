//
//  ViewController.swift
//  Perfect Green Screen
//
//  Created by Vitaly Bokser on 3/30/19.
//  Copyright © 2019 Vitaly Bokser. All rights reserved.
//

import UIKit
import AVFoundation
import DGCharts
import Accelerate

class PGSViewController: UIViewController, CameraManagerDelegate {
    
    @IBOutlet weak var barChartView: BarChartView!
    @IBOutlet weak var bandsSlider: UISlider!
    @IBOutlet weak var bandsTextField: UITextField!
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var processedView: UIImageView!
    @IBOutlet weak var exposureLockButton: UIButton!
    @IBOutlet weak var focusLockButton: UIButton!
    
    // Our new modules
    private let cameraManager = CameraManager()
    private let imageProcessor = ImageProcessor()
    
    // Camera & processing state
    var numberOfBands: Int = 10 //default value
    
    // Histogram chart data
    var doUpdateCharts: Bool = false
    var barChartValues = [BarChartDataEntry]()
    var chartDataSet: BarChartDataSet?
    var chartData: BarChartData?
    
    // Timers
    var timer = Timer()
    var histogramTimer = Timer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize with default values
        self.numberOfBands = 10
        
        // Set up histogram chart view
        setupHistogramChart()
        
        // Configure timers
        scheduledTimerWithTimeInterval()

        // Setup tap gesture for dismissing keyboard
        let tap = UITapGestureRecognizer(target: self, action: #selector(finishedEditing(_:)))
        tap.cancelsTouchesInView = false
        self.view.addGestureRecognizer(tap)
        
        // Set up camera manager delegate
        cameraManager.delegate = self
        
        // Add observer for histogram visibility changes
        NotificationCenter.default.addObserver(self, 
                                             selector: #selector(histogramVisibilityChanged), 
                                             name: NSNotification.Name("HistogramVisibilityChanged"), 
                                             object: nil)
                                             
        // Add observer for max bands value changes
        NotificationCenter.default.addObserver(self, 
                                             selector: #selector(maxBandsValueChanged), 
                                             name: NSNotification.Name("MaxBandsValueChanged"), 
                                             object: nil)
        
        // Print camera details to console (for development)
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
        setVisibleHistogram()
        setupSliderForBands()
        
        // Start the camera
        cameraManager.startCamera()
    }
    
    func setupHistogramChart() {
        // Initialize empty histogram data for chart
        self.barChartValues = (0..<256).map { (i) -> BarChartDataEntry in
            return BarChartDataEntry(x: Double(i), y: 0)
        }
        
        self.chartDataSet = BarChartDataSet(entries: self.barChartValues, label: "Histogram")
        self.chartDataSet?.drawValuesEnabled = false
        self.chartDataSet?.colors = [NSUIColor.white]
        self.chartData = BarChartData(dataSet: self.chartDataSet!)
        
        guard barChartView != nil else {
            print("Error: barChartView is nil - check storyboard module settings")
            return
        }
        
        // Apply chart data
        self.barChartView.data = self.chartData
        
        // Configure chart appearance
        self.barChartView.xAxis.labelTextColor = .white
        self.barChartView.xAxis.drawLabelsEnabled = false
        self.barChartView.xAxis.labelPosition = .bottom
        self.barChartView.xAxis.axisMinimum = -5
        self.barChartView.xAxis.axisMaximum = 260

        self.barChartView.drawGridBackgroundEnabled = false
        self.barChartView.drawBordersEnabled = true
        self.barChartView.borderColor = .white
        
        self.barChartView.gridBackgroundColor = .clear
        self.barChartView.backgroundColor = .clear
        self.barChartView.leftAxis.gridColor = .clear
        self.barChartView.rightAxis.gridColor = .clear

        self.barChartView.leftAxis.drawLabelsEnabled = false
        self.barChartView.leftAxis.drawAxisLineEnabled = false
        self.barChartView.leftAxis.axisLineWidth = 0
        self.barChartView.leftAxis.labelTextColor = .white

        self.barChartView.rightAxis.drawLabelsEnabled = false
        self.barChartView.rightAxis.drawAxisLineEnabled = false
        self.barChartView.rightAxis.axisLineWidth = 0
        self.barChartView.autoScaleMinMaxEnabled = true
        self.barChartView.legend.enabled = false
    }
    
    func scheduledTimerWithTimeInterval(){
        timer = Timer.scheduledTimer(timeInterval: 0.75, target: self, selector: #selector(self.updateChart), userInfo: nil, repeats: true)
    }
    
    @objc func updateChart() {
        if self.doUpdateCharts == false {
            return
        }
        
        // Get histogram data as percentages
        let percentages = imageProcessor.getHistogramPercentages()
        
        // Update chart data entries
        for counter in 0..<256 {
            self.barChartValues[counter].x = Double(counter)
            self.barChartValues[counter].y = percentages[counter]
        }

        // Create new dataset and update chart
        let newDataSet = BarChartDataSet(entries: self.barChartValues, label: "Histogram")
        newDataSet.drawValuesEnabled = false
        newDataSet.colors = [NSUIColor.white]
        
        let newChartData = BarChartData(dataSet: newDataSet)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let barChartView = self.barChartView else { return }
            
            barChartView.data = newChartData
            barChartView.notifyDataSetChanged()
            self.chartDataSet = newDataSet
            self.chartData = newChartData
            self.doUpdateCharts = false
        }
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
        self.doUpdateCharts = true
    }
    
    // MARK: - UI Actions
    
    @objc func finishedEditing(_ sender: UITapGestureRecognizer) {
        self.view.endEditing(true)
    }
    
    @IBAction func viewChangeClicked(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
            self.cameraView.isHidden = false
        } else {
            self.cameraView.isHidden = true
        }
    }
    
    @IBAction func bandsSliderChanged(_ sender: UISlider) {
        // Get the current max bands value and ensure we respect it
        let maxBandsValue = UserDefaults.standard.integer(forKey: CURRENT_NUMBER_OF_MAX_BANDS_STRING)
        
        // Ensure slider max value is updated
        bandsSlider.maximumValue = Float(maxBandsValue)
        
        // Get selected value (clamped to max)
        let currentNumberOfBands = min(Int(bandsSlider.value), maxBandsValue)
        self.numberOfBands = checkBandsRange(numBands: currentNumberOfBands)
        bandsTextField.text = "\(self.numberOfBands)"
        print("number of bands = \(self.numberOfBands)")
        
        // Update user defaults
        UserDefaults.standard.set(self.numberOfBands, forKey: CURRENT_NUMBER_OF_BANDS_STRING)
    }
    
    func checkBandsRange(numBands: Int) -> Int {
        return numBands
    }
    
    @IBAction func focusButtonClicked(_ sender: UIButton) {
        if cameraManager.toggleFocusLock() {
            if cameraManager.isFocusLocked {
                if let image = UIImage(named: "focus_lock_icon_1920_closed") { //locked
                    focusLockButton.setImage(image, for: .normal)
                }
            } else {
                if let image = UIImage(named: "focus_lock_icon_1920_open") { //unlocked
                    focusLockButton.setImage(image, for: .normal)
                }
            }
        }
    }
    
    @IBAction func lockButtonClicked(_ sender: UIButton) {
        if cameraManager.toggleExposureLock() {
            if cameraManager.isExposureLocked {
                if let image = UIImage(named: "exposure_lock_icon_1920_closed") { //locked
                    exposureLockButton.setImage(image, for: .normal)
                }
            } else {
                if let image = UIImage(named: "exposure_lock_icon_1920_open") { //unlocked
                    exposureLockButton.setImage(image, for: .normal)
                }
            }
        }
    }
    
    @objc func histogramVisibilityChanged() {
        setVisibleHistogram()
    }
    
    @objc func maxBandsValueChanged() {
        setupSliderForBands()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Settings Management
extension PGSViewController {
    func userDefaultsExist(key: String) -> Bool {
        return UserDefaults.standard.object(forKey: key) != nil
    }

    func setVisibleHistogram() {
        //if it doesnt exist set a default value
        if !userDefaultsExist(key: DEFAULT_HISTOGRAM_VISIBLE_STRING) {
            UserDefaults.standard.set(true, forKey: DEFAULT_HISTOGRAM_VISIBLE_STRING)
        }
        
        let defaults = UserDefaults.standard
        let isHistogramVisible = defaults.bool(forKey: DEFAULT_HISTOGRAM_VISIBLE_STRING)
        self.barChartView.isHidden = !isHistogramVisible
    }
    
    func setupSliderForBands() {
        //1. if it doesnt exist set a default value
        if !userDefaultsExist(key: CURRENT_NUMBER_OF_MAX_BANDS_STRING) {
            UserDefaults.standard.set(DEFAULT_MAX_BANDS_VALUE_INT, forKey: CURRENT_NUMBER_OF_MAX_BANDS_STRING)
            let numOfCurrentBands = Int(DEFAULT_MAX_BANDS_VALUE_INT/2)
            UserDefaults.standard.set(numOfCurrentBands, forKey: CURRENT_NUMBER_OF_BANDS_STRING)
        }

        //2. get the current user defaults for max bands and current bands
        var numberOfMaxBands = UserDefaults.standard.integer(forKey: CURRENT_NUMBER_OF_MAX_BANDS_STRING)
        var numberOfCurrentbands = UserDefaults.standard.integer(forKey: CURRENT_NUMBER_OF_BANDS_STRING)
        
        //3. make sure current num bands less than max number of bands
        if numberOfMaxBands < DEFAULT_MAX_BANDS_VALUE_INT {
            numberOfMaxBands = DEFAULT_MAX_BANDS_VALUE_INT
            numberOfCurrentbands = Int(numberOfMaxBands/2)
            
            UserDefaults.standard.set(numberOfMaxBands, forKey: CURRENT_NUMBER_OF_MAX_BANDS_STRING)
            UserDefaults.standard.set(numberOfCurrentbands, forKey: CURRENT_NUMBER_OF_BANDS_STRING)
        }
        else if numberOfCurrentbands > numberOfMaxBands {
            numberOfCurrentbands = Int(numberOfMaxBands/2)
            UserDefaults.standard.set(numberOfCurrentbands, forKey: CURRENT_NUMBER_OF_BANDS_STRING)
        }

        //4. setup all onscreen fields
        self.bandsTextField.text = "\(numberOfCurrentbands)"
        self.bandsSlider.value = Float(numberOfCurrentbands)
        self.bandsSlider.maximumValue = Float(numberOfMaxBands)
        
        // Update the number of bands
        self.numberOfBands = numberOfCurrentbands
    }
}



