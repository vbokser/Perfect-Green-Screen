import UIKit
import Accelerate

class ImageProcessor {
    // Histogram data
    private(set) var histogramData = Array<Int>(repeating: 0, count: 256)
    private(set) var totalPixelCount: Int = 0
    
    // MARK: - Image Processing
    
    func processBanding(pixelBuffer: CVPixelBuffer, numberOfBands: Int) -> UIImage? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let bandSize = 256 / numberOfBands
        
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        // Create output buffer for the processed image
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        )
        
        guard let context = context else { return nil }
        
        // Get pointers to input and output data
        let inputData = CVPixelBufferGetBaseAddress(pixelBuffer)!.assumingMemoryBound(to: UInt8.self)
        let outputData = context.data!.assumingMemoryBound(to: UInt8.self)
        
        // Process pixels - apply grayscale and banding
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = y * bytesPerRow + x * 4
                
                // Get RGB components (BGRA format in buffer)
                let blue = Float(inputData[pixelIndex])
                let green = Float(inputData[pixelIndex + 1])
                let red = Float(inputData[pixelIndex + 2])
                
                // Convert to grayscale
                let gray = 0.3 * red + 0.59 * green + 0.11 * blue
                
                // Apply banding
                let band = Int(gray) / bandSize
                let bandedValue = UInt8(band * bandSize)
                
                // Write grayscale to all three RGB channels
                outputData[pixelIndex] = bandedValue     // B
                outputData[pixelIndex + 1] = bandedValue // G
                outputData[pixelIndex + 2] = bandedValue // R
                outputData[pixelIndex + 3] = 255         // A
            }
        }
        
        // Create image
        guard let cgImage = context.makeImage() else { return nil }
        return UIImage(cgImage: cgImage)
    }
    
    // MARK: - Histogram Generation
    
    func updateHistogram(from pixelBuffer: CVPixelBuffer) -> [Int] {
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0))) }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)!
        let byteBuffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        // Update pixel count for percentage calculations
        totalPixelCount = width * height
        
        // Reset histogram data
        for i in 0..<256 {
            histogramData[i] = 0
        }
        
        // Sample fewer pixels for performance - maybe every 4th pixel
        for j in stride(from: 0, to: height, by: 4) {
            for i in stride(from: 0, to: width, by: 4) {
                let index = (j * bytesPerRow) + (i * 4)
                
                let b = byteBuffer[index]
                let g = byteBuffer[index+1]
                let r = byteBuffer[index+2]
                
                let red: Float = 0.3 * Float(r)
                let blue: Float = 0.11 * Float(b)
                let green: Float = 0.59 * Float(g)
                let linearIntensity = Int(red + green + blue)
                
                if linearIntensity >= 0 && linearIntensity < 256 {
                    histogramData[linearIntensity] += 1
                }
            }
        }
        
        return histogramData
    }
    
    // Get histogram data as percentages
    func getHistogramPercentages() -> [Double] {
        guard totalPixelCount > 0 else { return Array(repeating: 0, count: 256) }
        
        return histogramData.map { Double($0) / Double(totalPixelCount) * 100.0 }
    }
} 