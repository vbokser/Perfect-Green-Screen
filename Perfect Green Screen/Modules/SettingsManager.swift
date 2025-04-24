import Foundation

// Constants for UserDefaults keys
let DEFAULT_HISTOGRAM_VISIBLE_STRING = "DEFAULT_HISTOGRAM_VISIBLE_STRING"
let CURRENT_NUMBER_OF_BANDS_STRING = "CURRENT_NUMBER_OF_BANDS_STRINGs"
let CURRENT_NUMBER_OF_MAX_BANDS_STRING = "CURRENT_NUMBER_OF_MAX_BANDS_STRINGs"
let DEFAULT_HISTOGRAM_BANDS_VISIBLE_STRING = "DEFAULT_HISTOGRAM_BANDS_VISIBLE_STRING"
let DEFAULT_MAX_BANDS_VALUE_INT = 20
let DEFAULT_NUMBER_OF_MIN_BANDS_INT = 2
let DEFAULT_NUMBER_OF_MAX_BANDS_INT = 50

class SettingsManager {
    
    // MARK: - Shared instance
    static let shared = SettingsManager()
    
    // MARK: - Settings Properties
    
    var isHistogramVisible: Bool {
        get {
            if !keyExists(DEFAULT_HISTOGRAM_VISIBLE_STRING) {
                UserDefaults.standard.set(true, forKey: DEFAULT_HISTOGRAM_VISIBLE_STRING)
            }
            return UserDefaults.standard.bool(forKey: DEFAULT_HISTOGRAM_VISIBLE_STRING)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: DEFAULT_HISTOGRAM_VISIBLE_STRING)
            NotificationCenter.default.post(name: NSNotification.Name("HistogramVisibilityChanged"), object: nil)
        }
    }
    
    var currentNumberOfBands: Int {
        get {
            ensureDefaultsExist()
            return UserDefaults.standard.integer(forKey: CURRENT_NUMBER_OF_BANDS_STRING)
        }
        set {
            let maxBands = currentMaxBands
            let validValue = min(newValue, maxBands)
            UserDefaults.standard.set(validValue, forKey: CURRENT_NUMBER_OF_BANDS_STRING)
        }
    }
    
    var currentMaxBands: Int {
        get {
            ensureDefaultsExist()
            return UserDefaults.standard.integer(forKey: CURRENT_NUMBER_OF_MAX_BANDS_STRING)
        }
        set {
            // Ensure the value is within the allowed range
            let validValue = min(max(newValue, DEFAULT_NUMBER_OF_MIN_BANDS_INT), DEFAULT_NUMBER_OF_MAX_BANDS_INT)
            UserDefaults.standard.set(validValue, forKey: CURRENT_NUMBER_OF_MAX_BANDS_STRING)
            
            // If current bands exceeds new max, adjust it
            if currentNumberOfBands > validValue {
                currentNumberOfBands = validValue
            }
            
            NotificationCenter.default.post(name: NSNotification.Name("MaxBandsValueChanged"), object: nil)
        }
    }
    
    // MARK: - Private Methods
    
    private func ensureDefaultsExist() {
        if !keyExists(CURRENT_NUMBER_OF_MAX_BANDS_STRING) {
            UserDefaults.standard.set(DEFAULT_MAX_BANDS_VALUE_INT, forKey: CURRENT_NUMBER_OF_MAX_BANDS_STRING)
            
            let defaultNumberOfBands = DEFAULT_MAX_BANDS_VALUE_INT / 2
            UserDefaults.standard.set(defaultNumberOfBands, forKey: CURRENT_NUMBER_OF_BANDS_STRING)
        }
    }
    
    private func keyExists(_ key: String) -> Bool {
        return UserDefaults.standard.object(forKey: key) != nil
    }
    
    // MARK: - Validation Methods
    
    func checkBandsRange(numBands: Int) -> Int {
        let maxBands = currentMaxBands
        return min(max(numBands, DEFAULT_NUMBER_OF_MIN_BANDS_INT), maxBands)
    }
} 