import UIKit
import MessageUI

class SettingsViewController: UIViewController {
    
    // UI Outlets
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var enableHistogram: UISegmentedControl!
    @IBOutlet weak var histogramSegmentedControl: UISegmentedControl!
    @IBOutlet weak var maxBandsLabel: UILabel!
    @IBOutlet weak var maxBandsSlider: UISlider!
    @IBOutlet weak var emailButton: UIButton!
    
    // Settings manager
    private let settingsManager = SettingsManager.shared
    
    // Constants
    private let minBandsValue = 2
    private let maxBandsValue = 40
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set rounded corners for email button
        emailButton.layer.cornerRadius = 10.0
        
        // Set rounded corners for back button
        backButton.layer.cornerRadius = 10.0
        
        // Setup tap gesture for dismissing keyboard
        let tap = UITapGestureRecognizer(target: self, action: #selector(finishedEditing(_:)))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        
        // Load settings from the settings manager
        updateUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Make sure UI reflects current settings
        updateUI()
    }
    
    private func updateUI() {
        // Update histogram segmented control - handle both outlet names
        let isVisible = settingsManager.isHistogramVisible
        histogramSegmentedControl?.selectedSegmentIndex = isVisible ? 0 : 1
        enableHistogram?.selectedSegmentIndex = isVisible ? 0 : 1
        
        // Update max bands slider and label
        let maxBands = settingsManager.currentMaxBands
        maxBandsSlider.value = Float(maxBands)
        maxBandsSlider.minimumValue = Float(minBandsValue)
        maxBandsSlider.maximumValue = Float(maxBandsValue)
        maxBandsLabel.text = "\(maxBands)"
    }
    
    // MARK: - Actions
    
    @IBAction func histogramSegmentChanged(_ sender: UISegmentedControl) {
        // Update settings manager which will post a notification
        let isVisible = sender.selectedSegmentIndex == 0
        settingsManager.isHistogramVisible = isVisible
    }
    
    @IBAction func maxBandsSliderChanged(_ sender: UISlider) {
        // Ensure value is within allowed range
        let maxBands = Int(max(min(sender.value, Float(maxBandsValue)), Float(minBandsValue)))
        
        // Update settings manager which will post a notification
        settingsManager.currentMaxBands = maxBands
        
        // Update label
        maxBandsLabel.text = "\(maxBands)"
        
        // Ensure slider value matches the clamped value
        sender.value = Float(maxBands)
    }
    
    @IBAction func emailButtonClicked(_ sender: UIButton) {
        sendEmail()
    }
    
    @IBAction func dismissVC(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func enableHistogramChanged(_ sender: UISegmentedControl) {
        // Update settings manager which will post a notification
        let isVisible = sender.selectedSegmentIndex == 0
        settingsManager.isHistogramVisible = isVisible
    }
    
    @objc func finishedEditing(_ sender: UITapGestureRecognizer) {
        view.endEditing(true)
    }
}

// MARK: - Email Support
extension SettingsViewController: MFMailComposeViewControllerDelegate {
    func sendEmail() {
        if MFMailComposeViewController.canSendMail() {
            let mail = MFMailComposeViewController()
            mail.mailComposeDelegate = self
            mail.setToRecipients(["support@indiefilmgear.com"])
            mail.setSubject("Support Question")
            mail.setMessageBody("<p>Hello Support,</p>", isHTML: true)
            
            present(mail, animated: true)
        } else {
            // Show failure alert
            let alertView = UIAlertController(
                title: "Mail Error",
                message: "Please setup your mail client on the device first in order to send emails",
                preferredStyle: .alert
            )
            let cancelAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
            alertView.addAction(cancelAction)
            present(alertView, animated: true, completion: nil)
        }
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }
} 
