import XCTest
import AVFoundation
@testable import Perfect_Green_Screen

@MainActor
final class LaunchAndProcessingTests: XCTestCase {
    private let settingKeys = [CURRENT_NUMBER_OF_BANDS_STRING, CURRENT_NUMBER_OF_MAX_BANDS_STRING]
    private var savedSettings: [String: Any] = [:]

    override func setUp() {
        super.setUp()
        for key in settingKeys {
            savedSettings[key] = UserDefaults.standard.object(forKey: key)
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    override func tearDown() {
        for key in settingKeys {
            if let value = savedSettings[key] {
                UserDefaults.standard.set(value, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        savedSettings.removeAll()
        super.tearDown()
    }

    func testSceneConfigurationResolvesDelegateAndMainStoryboard() throws {
        let manifest = try XCTUnwrap(Bundle.main.infoDictionary?["UIApplicationSceneManifest"] as? [String: Any])
        let configurations = try XCTUnwrap(manifest["UISceneConfigurations"] as? [String: Any])
        let scenes = try XCTUnwrap(configurations["UIWindowSceneSessionRoleApplication"] as? [[String: Any]])
        let scene = try XCTUnwrap(scenes.first)
        let delegateName = try XCTUnwrap(scene["UISceneDelegateClassName"] as? String)
        XCTAssertNotNil(NSClassFromString(delegateName))
        XCTAssertEqual(scene["UISceneStoryboardFile"] as? String, "Main")
    }

    func testMainStoryboardLoadsChartAndCameraOutlets() throws {
        let controller = try XCTUnwrap(UIStoryboard(name: "Main", bundle: .main).instantiateInitialViewController() as? PGSViewController)
        controller.loadViewIfNeeded()
        XCTAssertNotNil(controller.barChartView)
        XCTAssertNotNil(controller.cameraView)
        XCTAssertNotNil(controller.processedView)
        XCTAssertNotNil(controller.bandsSlider)
    }

    func testPreviewCanBeCreatedWithoutCameraConnectionAndReused() {
        let manager = CameraManager()
        let view = CameraPreviewView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        let layer = manager.createPreviewLayer(for: view)
        manager.updatePreviewOrientation()
        XCTAssertTrue(manager.createPreviewLayer(for: view) === layer)
        view.bounds.size = CGSize(width: 640, height: 480)
        manager.updatePreviewOrientation()
        XCTAssertEqual(layer.bounds, view.bounds)
    }

    func testMissingBandSettingIsRepairedWhenMaximumExists() {
        UserDefaults.standard.set(20, forKey: CURRENT_NUMBER_OF_MAX_BANDS_STRING)
        XCTAssertEqual(SettingsManager.shared.currentNumberOfBands, 10)
    }

    func testInvalidPersistedBandsAreClampedAndCannotBecomeZero() {
        UserDefaults.standard.set(0, forKey: CURRENT_NUMBER_OF_MAX_BANDS_STRING)
        UserDefaults.standard.set(0, forKey: CURRENT_NUMBER_OF_BANDS_STRING)
        XCTAssertEqual(SettingsManager.shared.currentMaxBands, 2)
        XCTAssertEqual(SettingsManager.shared.currentNumberOfBands, 2)
        SettingsManager.shared.currentMaxBands = 20
        SettingsManager.shared.currentNumberOfBands = -10
        XCTAssertEqual(SettingsManager.shared.currentNumberOfBands, 2)
        SettingsManager.shared.currentNumberOfBands = 999
        XCTAssertEqual(SettingsManager.shared.currentNumberOfBands, 20)
    }

    func testBandingHandlesInvalidCountsAndPaddedRows() throws {
        let buffer = try whitePixelBuffer(width: 7, height: 5)
        let processor = ImageProcessor()
        for bands in [-10, 0, 1, 2, 256, 257, Int.max] {
            let image = try XCTUnwrap(processor.processBanding(pixelBuffer: buffer, numberOfBands: bands))
            XCTAssertEqual(image.size, CGSize(width: 7, height: 5))
            let data = try XCTUnwrap(image.cgImage?.dataProvider?.data)
            let bytes = try XCTUnwrap(CFDataGetBytePtr(data))
            XCTAssertEqual(bytes[0], bands <= 2 ? 128 : 255)
            XCTAssertEqual(bytes[0], bytes[1])
            XCTAssertEqual(bytes[1], bytes[2])
            XCTAssertEqual(bytes[3], 255)
        }
    }

    func testHistogramPercentagesUseActualSampleCount() throws {
        let buffer = try whitePixelBuffer(width: 7, height: 5)
        let processor = ImageProcessor()
        let histogram = processor.updateHistogram(from: buffer)
        XCTAssertEqual(histogram.reduce(0, +), 4)
        XCTAssertEqual(processor.totalPixelCount, 4)
        XCTAssertEqual(processor.getHistogramPercentages().reduce(0, +), 100, accuracy: 0.0001)
    }

    func testSwitchingViewModesRestoresSplitAndPreviewBounds() throws {
        let controller = try XCTUnwrap(UIStoryboard(name: "Main", bundle: .main).instantiateInitialViewController() as? PGSViewController)
        controller.loadViewIfNeeded()
        let image = UIGraphicsImageRenderer(size: CGSize(width: 640, height: 480)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 640, height: 480))
        }
        controller.processedView.image = image
        let toggle = UISegmentedControl(items: ["Both Views", "Band View"])
        for size in [CGSize(width: 932, height: 430), CGSize(width: 844, height: 390)] {
            controller.view.frame = CGRect(origin: .zero, size: size)
            controller.view.layoutIfNeeded()
            let splitFrame = controller.processedView.frame
            for _ in 0..<5 {
                toggle.selectedSegmentIndex = 1
                controller.viewChangeClicked(toggle)
                controller.view.layoutIfNeeded()
                XCTAssertEqual(controller.processedView.bounds.width, size.width, accuracy: 1)
                toggle.selectedSegmentIndex = 0
                controller.viewChangeClicked(toggle)
                controller.view.layoutIfNeeded()
                XCTAssertEqual(controller.cameraView.bounds.width, controller.processedView.bounds.width, accuracy: 1)
                XCTAssertLessThanOrEqual(controller.cameraView.frame.maxX, controller.processedView.frame.minX)
                XCTAssertEqual(controller.processedView.frame, splitFrame)
                let preview = controller.cameraView.previewLayer
                XCTAssertEqual(preview.bounds, controller.cameraView.bounds)
            }
        }
    }

    func testInfoFooterShowsTheBuiltVersionNumberAndTimestamp() throws {
        let version = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
        let build = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
        let timestamp = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "PGSBuildTimestamp") as? String)
        XCTAssertNotNil(Int(build))
        XCTAssertNotNil(ISO8601DateFormatter().date(from: timestamp))
        let url = try XCTUnwrap(Bundle.main.url(forResource: "instructions", withExtension: "html", subdirectory: "html"))
        let source = try String(contentsOf: url, encoding: .utf8)
        let html = InfoViewController.renderInstructionsHTML(source)
        XCTAssertTrue(html.contains("Version \(version) (Build \(build))"))
        XCTAssertTrue(html.contains("Build timestamp:"))
        XCTAssertFalse(html.contains("Unavailable"))
        XCTAssertFalse(html.contains("__BUILD_TIMESTAMP__"))
        let footer = try XCTUnwrap(html.range(of: "id=\"build-information\""))
        let bodyEnd = try XCTUnwrap(html.range(of: "</body>"))
        XCTAssertLessThan(footer.lowerBound, bodyEnd.lowerBound)
    }

    private func whitePixelBuffer(width: Int, height: Int) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        XCTAssertEqual(CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, nil, &buffer), kCVReturnSuccess)
        let result = try XCTUnwrap(buffer)
        CVPixelBufferLockBaseAddress(result, [])
        defer { CVPixelBufferUnlockBaseAddress(result, []) }
        let base = try XCTUnwrap(CVPixelBufferGetBaseAddress(result))
        memset(base, 255, CVPixelBufferGetBytesPerRow(result) * height)
        return result
    }
}
