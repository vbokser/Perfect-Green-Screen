//1. Color Selection Implementation

// Add these properties to your view controller
private var selectedKeyColor: UIColor?
private var keyColorTolerance: CGFloat = 0.3 // Adjust based on testing
private var backgroundImage: UIImage?

// Setup tap gesture in viewDidLoad
func setupTapGesture() {
    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleColorTap(_:)))
    processedView.isUserInteractionEnabled = true
    processedView.addGestureRecognizer(tapGesture)
}

@objc func handleColorTap(_ gesture: UITapGestureRecognizer) {
    let location = gesture.location(in: processedView)
    
    // Get the color at the tapped location
    if let tappedImage = processedView.image,
       let cgImage = tappedImage.cgImage,
       let provider = cgImage.dataProvider,
       let data = provider.data {
        
        let pixelData = CFDataGetBytePtr(data)
        let bytesPerRow = cgImage.bytesPerRow
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        
        let pixelIndex = Int(location.y) * bytesPerRow + Int(location.x) * bytesPerPixel
        
        // Get RGB components
        let r = CGFloat(pixelData?[pixelIndex] ?? 0) / 255.0
        let g = CGFloat(pixelData?[pixelIndex + 1] ?? 0) / 255.0
        let b = CGFloat(pixelData?[pixelIndex + 2] ?? 0) / 255.0
        
        selectedKeyColor = UIColor(red: r, green: g, blue: b, alpha: 1.0)
        
        // Visual feedback
        showColorPickedIndicator(at: location, color: selectedKeyColor!)
    }
}

//2. Implement the Keying Algorithm

func processChromaKey(sourceImage: UIImage, keyColor: UIColor, backgroundImage: UIImage?) -> UIImage? {
    guard let sourceCGImage = sourceImage.cgImage,
          let backgroundCGImage = backgroundImage?.cgImage else { return sourceImage }
    
    // Create CIImage from the input
    let sourceCI = CIImage(cgImage: sourceCGImage)
    let backgroundCI = CIImage(cgImage: backgroundCGImage)
    
    // Resize background to match source dimensions
    let scaleX = CGFloat(sourceCGImage.width) / backgroundCI.extent.width
    let scaleY = CGFloat(sourceCGImage.height) / backgroundCI.extent.height
    let scaledBackground = backgroundCI.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
    
    // Get key color components
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    keyColor.getRed(&r, green: &g, blue: &b, alpha: &a)
    
    // Create chroma key filter
    let chromaKeyFilter = CIFilter(name: "CIColorCube")!
    
    // Create color cube data
    let dimension = 64 // Cube dimension
    let cubeDataSize = dimension * dimension * dimension * 4 * MemoryLayout<Float>.size
    let cubeData = UnsafeMutablePointer<Float>.allocate(capacity: cubeDataSize)
    defer { cubeData.deallocate() }
    
    // Fill color cube with transformation data
    var offset = 0
    let keyR = Float(r)
    let keyG = Float(g)
    let keyB = Float(b)
    let tolerance = Float(keyColorTolerance)
    
    for z in 0..<dimension {
        let blue = Float(z) / Float(dimension-1)
        for y in 0..<dimension {
            let green = Float(y) / Float(dimension-1)
            for x in 0..<dimension {
                let red = Float(x) / Float(dimension-1)
                
                // Calculate color distance
                let dr = red - keyR
                let dg = green - keyG
                let db = blue - keyB
                let distance = sqrt(dr*dr + dg*dg + db*db)
                
                // Calculate alpha based on distance
                var alpha: Float = 1.0
                if distance < tolerance {
                    alpha = 0.0
                } else if distance < tolerance * 1.5 {
                    alpha = (distance - tolerance) / (tolerance * 0.5)
                }
                
                // Set RGBA values
                cubeData[offset] = red
                cubeData[offset+1] = green
                cubeData[offset+2] = blue
                cubeData[offset+3] = alpha
                
                offset += 4
            }
        }
    }
    
    // Create color cube
    let data = Data(bytes: cubeData, count: cubeDataSize)
    chromaKeyFilter.setValue(dimension, forKey: "inputCubeDimension")
    chromaKeyFilter.setValue(data, forKey: "inputCubeData")
    chromaKeyFilter.setValue(sourceCI, forKey: "inputImage")
    
    guard let maskedForeground = chromaKeyFilter.outputImage else { return sourceImage }
    
    // Blend foreground and background
    let compositeFilter = CIFilter(name: "CISourceOverCompositing")!
    compositeFilter.setValue(maskedForeground, forKey: "inputImage")
    compositeFilter.setValue(scaledBackground, forKey: "inputBackgroundImage")
    
    guard let compositeImage = compositeFilter.outputImage else { return sourceImage }
    
    // Convert back to UIImage
    let context = CIContext()
    guard let cgImage = context.createCGImage(compositeImage, from: compositeImage.extent) else {
        return sourceImage
    }
    
    return UIImage(cgImage: cgImage)
}

//3. Add Background Image Selection
@IBAction func selectBackgroundImage(_ sender: UIButton) {
    let imagePicker = UIImagePickerController()
    imagePicker.delegate = self
    imagePicker.sourceType = .photoLibrary
    imagePicker.allowsEditing = false
    present(imagePicker, animated: true)
}

// MARK: - UIImagePickerControllerDelegate
extension PGSViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[.originalImage] as? UIImage {
            backgroundImage = image
            // Update UI to show selected background
            updateBackgroundThumbnail(image)
        }
        picker.dismiss(animated: true)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

//4. Update the Camera Processing to Apply the Chroma Key

func cameraManager(_ manager: CameraManager, didUpdatePixelBuffer buffer: CVPixelBuffer) {
    // Convert buffer to UIImage
    let sourceImage = imageProcessor.convertPixelBufferToUIImage(buffer)
    
    if let keyColor = selectedKeyColor, let background = backgroundImage {
        // Apply chroma key if we have both selected color and background
        if let processedImage = processChromaKey(sourceImage: sourceImage, keyColor: keyColor, backgroundImage: background) {
            DispatchQueue.main.async { [weak self] in
                self?.processedView.image = processedImage
            }
        }
    } else {
        // Original processing if not keying
        if let processedImage = imageProcessor.processBanding(pixelBuffer: buffer, numberOfBands: self.numberOfBands) {
            DispatchQueue.main.async { [weak self] in
                self?.processedView.image = processedImage
            }
        }
    }
    
    // Update histogram data
    _ = imageProcessor.updateHistogram(from: buffer)
    doUpdateCharts = true
}

/*
5. Add UI Elements to the Storyboard
You'll need to add:
A button to select background images
A view to show the selected background thumbnail
Instructions for the user to tap the screen to select the key color
Possibly a slider to adjust tolerance
This implementation provides a solid foundation for chroma keying functionality. In a production app, you might want to:
Add more advanced keying algorithms for better edge detection
Implement color spillage reduction
Add options for color selection refinement
Optimize performance using Metal for real-time processing
For the most accurate results, you may need to fine-tune the tolerance values and potentially implement more sophisticated keying algorithms based on user testing.
*/