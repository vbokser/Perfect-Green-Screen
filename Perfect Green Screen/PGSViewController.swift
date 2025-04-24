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

class PGSViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    @IBOutlet weak var barChartView: BarChartView!
    @IBOutlet weak var bandsSlider: UISlider!
    @IBOutlet weak var bandsTextField: UITextField!
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var processedView: UIImageView!
    @IBOutlet weak var exposureLockButton: UIButton!
    @IBOutlet weak var focusLockButton: UIButton!
    
    var captureSession: AVCaptureSession!
    var cameraDevice: AVCaptureDevice?
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    var numberOfBands: Int = 10 //default value
    
    var percentHistogramData = [Double]()
    var histogramData = [Int]()
    var newHistogramData = Array<Int>(repeating: 0, count: 256)
    var x_values = [Int]()
    var counter: Int = 0
    var getHistogramData: Bool = false
    var doUpdateCharts: Bool = false
    var barChartValues = [BarChartDataEntry]()
    var chartDataSet:BarChartDataSet?
    var chartData:BarChartData?
    
    var timer = Timer()
    var histogramTimer = Timer()
    var total_pixel_count: Double = 0
    let numberValueslsInByte = 256

    var isFocusLocked: Bool = false
    var isExposureLocked: Bool = false

    var bandSize = 0
    var pixelValues = [Int]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let width = 640
        let height = 480
        self.numberOfBands = 10
        self.total_pixel_count = Double(width * height) //assume this well get a mor eaccurate later
        //setupBandSize()

        //set all data to zero we want 256 values for 1 byte
        histogramData = Array<Int>(repeating: 0, count: numberValueslsInByte)
        x_values = Array<Int>(repeating: 0, count: numberValueslsInByte)
        
        self.barChartValues = (0..<256).map { (i) -> BarChartDataEntry in
            return BarChartDataEntry(x: Double(i), y: Double(histogramData[i]))
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
//        self.barChartView.leftAxis.axisMinimum = 0.0
//        self.barChartView.leftAxis.axisMaximum = 100.0

        self.barChartView.rightAxis.drawLabelsEnabled = false
        self.barChartView.rightAxis.drawAxisLineEnabled = false
        self.barChartView.rightAxis.axisLineWidth = 0
        self.barChartView.autoScaleMinMaxEnabled = true
//        self.barChartView.chartYMin = 0.0
//        self.barChartView.chartYMax = 100.0
//        self.barChartView.chartXMin = 0
//        self.barChartView.chartXMax = 255
        self.barChartView.legend.enabled = false
        
        
        //hide bar chart
        self.barChartView.isHidden = false
        
        self.doUpdateCharts = false
        self.getHistogramData = true
        scheduledTimerWithTimeInterval()

        let tap = UITapGestureRecognizer(target: self, action: #selector(finishedEditing(_:)))
        tap.cancelsTouchesInView = false
        self.view.addGestureRecognizer(tap)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        cameraView.backgroundColor = UIColor.clear
        processedView.backgroundColor = UIColor.clear
        
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = AVCaptureSession.Preset.vga640x480  //hd1280x720
        
        setVisibleHistogram() //enable of diable the histogram based on user defaults
        setupSliderForBands()
        
        let videoDeviceDiscovery = AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .unspecified)
        
        for camera in videoDeviceDiscovery.devices as [AVCaptureDevice] {
            if camera.position == .back {
                cameraDevice = camera
            }
            if cameraDevice == nil {
                print("Could not find back camera.")
            }
        }
        
        if cameraDevice == nil {
            print("Found No Camera")
            return
        }
        
        do {
            let videoDeviceInput = try AVCaptureDeviceInput(device: cameraDevice!)
            if captureSession.canAddInput(videoDeviceInput) {
                captureSession.addInput(videoDeviceInput)
            }
        } catch {
            print("Could not add camera as input: \(error)")
            return
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer.init(session: captureSession)
        
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspect
        previewLayer.frame = cameraView.bounds
        
        if (previewLayer.connection?.isVideoOrientationSupported)! {
            previewLayer.connection?.videoOrientation = .landscapeRight
        }
        cameraView.layer.addSublayer(previewLayer)
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable as! String: Int(kCVPixelFormatType_32BGRA)]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        
        let videoOutputQueue = DispatchQueue(label: "VideoQueue")
        videoOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        } else {
            print("Could not add video data as output.")
        }
        
        DispatchQueue.global(qos: .userInitiated).async { //[weak self] in
            //self.captureSession.startRunning()
            self.captureSession.startRunning()
        }

    }
    func scheduledTimerWithTimeInterval(){
        // Scheduling timer to Call the function "updateCounting" with the interval of 1 seconds
        timer = Timer.scheduledTimer(timeInterval: 0.75, target: self, selector: #selector(self.updateChart), userInfo: nil, repeats: true)
        histogramTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.updateHistogramData), userInfo: nil, repeats: true)
    }
    
    @objc func updateHistogramData() {
        self.getHistogramData = true
    }
    
    @objc func updateChart()
    {
        if self.doUpdateCharts == false {
            return
        }
                
        processHistogramData()
        
        for counter in 0..<256 {
            self.barChartValues[counter].x = Double(counter)
            self.barChartValues[counter].y = (Double(newHistogramData[counter])/self.total_pixel_count) * 100.0
        }

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
    
    func processHistogramData() {
//        var percentHistogramData = [Double]()
        //percentHistogramData = Array<Double>(repeating: 0.0, count: numberValueslsInByte)
        
        var totalPixels: Int = 0
        totalPixels = 0
        for counter in 0..<numberValueslsInByte {
            totalPixels = newHistogramData[counter] + totalPixels
        }
//        print("total pixels = \(totalPixels)")
        
//        for counter in 0..<numberValueslsInByte {
//            percentHistogramData[counter] = Double(histogramData[counter]) / self.total_pixel_count
//        }
    }
    
    
    func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

        if !self.getHistogramData { //need this to sync data up so histogram is not fucked
            return
        }

        let start = CFAbsoluteTimeGetCurrent()

        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        
        CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
        
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        let bitsPerComponent = 8
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        
        let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)!
        let byteBuffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        
//        self.getHistogramData = true
        if self.getHistogramData { //every 15 frames approx
            for i in 0..<numberValueslsInByte {
                histogramData[i] = 0
            }
//            histogramData = Array<Int>(repeating: 0, count: numberValueslsInByte)
        }
        
        self.total_pixel_count = Double(height * width)
        
        for j in 0..<height {
            for i in 0..<width {
                let index = (j * width + i) * 4
                
                let b = byteBuffer[index]
                let g = byteBuffer[index+1]
                let r = byteBuffer[index+2]
                //let a = byteBuffer[index+3]
                
//                let bwpixel = (b + g + r) / 3
                let red: Float = 0.3 * Float(r)
                let blue: Float = 0.11 * Float(b)
                let green: Float = 0.59 * Float(g)
                let linearIntensityD: Float = red + green + blue //(0.3 * r) + (0.59 * g) + (0.11 * b)
                var linearIntensity = Int(linearIntensityD)
                
                if self.getHistogramData {
                    if (linearIntensity < 0 || linearIntensity > 255) {
                        print("linear intensity is incorrect = \(linearIntensity)")
                    }
                    else {
                        histogramData[linearIntensity] = histogramData[linearIntensity] + 1
                    }
                }

                linearIntensity = getIntensity(intensity: linearIntensity)
                
                byteBuffer[index] = UInt8(linearIntensity)
                byteBuffer[index+1] = UInt8(linearIntensity)
                byteBuffer[index+2] = UInt8(linearIntensity)
                
//                if r > UInt8(128) && g < UInt8(128) {
//                    byteBuffer[index] = UInt8(255)
//                    byteBuffer[index+1] = UInt8(0)
//                    byteBuffer[index+2] = UInt8(0)
//                } else {
//                    byteBuffer[index] = g
//                    byteBuffer[index+1] = r
//                    byteBuffer[index+2] = b
//                }
            }
        }
        
        if (self.doUpdateCharts == false) {
            for i in 0..<numberValueslsInByte {
                self.newHistogramData[i] = histogramData[i]
                histogramData[i] = 0
            }
            self.doUpdateCharts = true
        }
        self.getHistogramData = false
//        if(self.timingSetter) {
//            self.timingSetter = false
//        }
//        if self.getHistogramData { //dont get more histogram data until timer hits
//            self.getHistogramData = false
//            timer = Timer.scheduledTimer(timeInterval: 0.25, target: self, selector: #selector(self.updateChart), userInfo: nil, repeats: false)
//        }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        let newContext = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo)
        if let context = newContext {
            let cameraFrame = context.makeImage()
            DispatchQueue.main.async {
                self.processedView.clipsToBounds = true
                self.processedView.contentMode = .scaleAspectFit
                self.processedView.image = UIImage(cgImage: cameraFrame!)
            }
        }
        
        CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
        
//        let diff = CFAbsoluteTimeGetCurrent() - start
//        print("Took \(diff) seconds")
    }
    
    func getIntensity(intensity: Int) -> Int {
        bandSize = Int(255 / self.numberOfBands)
//        pixelValues.removeAll()

        //var counter = 0
        let numBandsForPixels = self.numberOfBands - 1
        let pixelBandSize = Int(255 / numBandsForPixels)
//        for i in 0..<numBandsForPixels {
//            pixelValues.append(i * pixelBandSize)
//            //counter += 1
//            //print("pixel value index \(i) and value = \(pixelValues[i])")
//        }
//        pixelValues.append(255) //final value
        //print("pixel value final value = \(pixelValues[self.numberOfBands-1])")

//        if (pixelValues.count != self.numberOfBands) {
//            setupBandSize()
//        }
        
        //print("Number of bands = \(self.numberOfBands)")
        for i in 0..<self.numberOfBands {
//            if (i+1 == self.numberOfBands) {
//                return 255 //last band return max value
//            }
            if ( (intensity >= i * bandSize) && (intensity <= (i+1)*bandSize) ) {
                return i * pixelBandSize //pixelValues[i]
            }
        }
        
        return 255 // we are in the final band if we got this far so return max
    }

    func getIntensity_backup(intesity: Int) -> Int {
        let bandSize = Int(255 / self.numberOfBands)
        
        for i in 1...self.numberOfBands {
            let value = i * bandSize
            if value > intesity {
                if i == bandSize {
                    return 255
                }
                else {
                    return i * bandSize
                }
            }
        }
        return 255
    }

//    @IBAction func updatebuttonClicked(_ sender: UIButton) {
////        self.numberOfBands = Int(bandsTextField.text ?? "10")!
//
//        let bands = Int(bandsTextField.text!) ?? 10
//        self.numberOfBands = checkBandsRange(numBands: bands)
//        print("number of bands = \(self.numberOfBands)")
//    }
    
    func checkBandsRange(numBands: Int) -> Int {
        let bands = numBands
//        if (bands > DEFAULT_BANDS_MAX_VALUE_INT) {
//            bands = 20
//            bandsTextField.text = "20"
////            bandsSlider.value = 20
//        }
//        else if (bands < 2 ) {
//            bands = 2
//            bandsTextField.text = "2"
////            bandsSlider.value = 1
//        }
        return bands
    }
    
    @objc func finishedEditing(_ sender: UITapGestureRecognizer)
    {
        self.view.endEditing(true)
    }
    
    @IBAction func viewChangeClicked(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
            self.cameraView.isHidden = false
            self.previewLayer?.isHidden = false
        }
        else  {
            self.cameraView.isHidden = true
            self.previewLayer?.isHidden = false
        }
//        else {
//            self.cameraView.isHidden = false
//            self.previewLayer?.isHidden = true
//        }
    }
    
    @IBAction func bandsSliderChanged(_ sender: UISlider) {
        let currentNumberOfBands = Int(bandsSlider.value)
        self.numberOfBands = checkBandsRange(numBands: currentNumberOfBands)
        bandsTextField.text = "\(self.numberOfBands)"
        print("number of bands = \(self.numberOfBands)")
        
        //update user defaults
        UserDefaults.standard.set(self.numberOfBands, forKey: CURRENT_NUMBER_OF_BANDS_STRING)

        //setupBandSize()
    }
    
//    func setupBandSize() {
//        bandSize = Int(255 / self.numberOfBands)
//        pixelValues.removeAll()
//
//        //var counter = 0
//        let numBandsForPixels = self.numberOfBands - 1
//        let pixelBandSize = Int(255 / numBandsForPixels)
//        for i in 0..<numBandsForPixels {
//            pixelValues.append(i * pixelBandSize)
//            //counter += 1
//            //print("pixel value index \(i) and value = \(pixelValues[i])")
//        }
//        pixelValues.append(255) //final value
//    }

    @IBAction func focusButtonClicked(_ sender: UIButton) {
        print("focusButtonClicked")
        do {
            try cameraDevice?.lockForConfiguration()
        }
        catch {
            print("camera device did not lock for configuration of focus")
            return
        }
        
        isFocusLocked = !isFocusLocked
        
        if (isFocusLocked) {
            cameraDevice?.focusMode = AVCaptureDevice.FocusMode.locked
            
            if let image = UIImage(named: "focus_lock_icon_1920_closed") { //locked
                focusLockButton.setImage(image, for: .normal)
            }
        }
        else {
            cameraDevice?.focusMode = AVCaptureDevice.FocusMode.continuousAutoFocus
            
            if let image = UIImage(named: "focus_lock_icon_1920_open") { //unlocked
                focusLockButton.setImage(image, for: .normal)
            }
        }
        cameraDevice?.unlockForConfiguration()

    }
    
    @IBAction func lockButtonClicked(_ sender: UIButton) {
        //captureSession.beginConfiguration()
        do {
            try cameraDevice?.lockForConfiguration()
        }
        catch {
            print("camera device did not lock for configuration")
            return
        }
        
        isExposureLocked = !isExposureLocked
        
        if (isExposureLocked) {
            cameraDevice?.exposureMode = AVCaptureDevice.ExposureMode.locked

            if let image = UIImage(named: "exposure_lock_icon_1920_closed") { //locked
                exposureLockButton.setImage(image, for: .normal)
            }
        }
        else {
            cameraDevice?.exposureMode = AVCaptureDevice.ExposureMode.continuousAutoExposure

            if let image = UIImage(named: "exposure_lock_icon_1920_open") { //unlocked
                exposureLockButton.setImage(image, for: .normal)
            }
        }
        cameraDevice?.unlockForConfiguration()

        //captureSession.commitConfiguration()
    }
}

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
//        UserDefaults.standard.set(DEFAULT_NUMBER_OF_MAX_BANDS_INT, forKey: DEFAULT_NUMBER_OF_MAX_BANDS_STRING)
        
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
        
//        setupCurrentSliderBandsValue()
    }
    
//    func setupCurrentSliderBandsValue() {
//        var currentNumBands = 2
//
//        //check if key exists if not set default value
//        if !userDefaultsExist(key: CURRENT_NUMBER_OF_BANDS_STRING) {
//            //set in the middle
//            currentNumBands = Int(DEFAULT_MAX_NUMBER_OF_BANDS_INT / 2)
//            UserDefaults.standard.set(currentNumBands, forKey: CURRENT_NUMBER_OF_BANDS_STRING)
//        }
//
//        currentNumBands = UserDefaults.standard.integer(forKey: CURRENT_NUMBER_OF_BANDS_STRING)
//        let maxNumberOfBands = self.bandsSlider.maximumValue
//        if (currentNumBands <= Int(maxNumberOfBands)) {
//            self.bandsSlider.value = Float(currentNumBands)
//        }
//        else { //current value is greater than max value
//            self.bandsSlider.value = Float(maxNumberOfBands)
//            UserDefaults.standard.set(maxNumberOfBands, forKey: CURRENT_NUMBER_OF_BANDS_STRING)
//        }
//    }

}

