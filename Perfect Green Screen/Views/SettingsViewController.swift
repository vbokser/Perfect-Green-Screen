//
//  SettingsViewController.swift
//  Perfect Green Screen
//
//  Created by Vitaly Bokser on 4/1/19.
//  Copyright © 2019 Vitaly Bokser. All rights reserved.
//

import UIKit
import MessageUI

class SettingsViewController: UIViewController {

    let bandsTextFieldTag = 10
//    let defaultBandsValue = "20"
//    let defaultBandsValueInt = 20
//    let maxBandsValueInt = 20

    @IBOutlet weak var maxBandsLabel: UILabel!
    @IBOutlet weak var maxBandsSlider: UISlider!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var emailButton: UIButton!
    @IBOutlet weak var enableHistogram: UISegmentedControl!
//    @IBOutlet weak var maxBandsTextfield: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        //set rounded button
        emailButton.layer.cornerRadius = 10.0

        //add tap gesture to screen
        let tap = UITapGestureRecognizer(target: self, action: #selector(finishedEditing(_:)))
        tap.cancelsTouchesInView = false
        self.view.addGestureRecognizer(tap)
        
        setHistogramSwitch()
        setSliderValueForBands()
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

    @IBAction func emailButtonClicked(_ sender: UIButton) {
        sendEmail()
    }
    
    @objc func finishedEditing(_ sender: UITapGestureRecognizer)
    {
        self.view.endEditing(true)
//        print("value in textfield is = \(maxBandsTextfield.text ?? "")")

    }
    
    @IBAction func dismissVC(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func enableHistogramSegmentedControl(_ sender: UISegmentedControl) {
        var isHistogramVisible = false
        if sender.selectedSegmentIndex == 0 {
            isHistogramVisible = true
        }
        UserDefaults.standard.set(isHistogramVisible, forKey: DEFAULT_HISTOGRAM_VISIBLE_STRING)
        
        // Post notification so current view controller can update immediately
        NotificationCenter.default.post(name: NSNotification.Name("HistogramVisibilityChanged"), object: nil)
    }
    
    func setHistogramSwitch() {
        let defaults = UserDefaults.standard
        let isHistogramVisible = defaults.bool(forKey: DEFAULT_HISTOGRAM_VISIBLE_STRING)
        if isHistogramVisible {
            self.enableHistogram.selectedSegmentIndex = 0 //on
        }
        else {
            self.enableHistogram.selectedSegmentIndex = 1 //off
        }
    }
    
    func setSliderValueForBands() {
        let defaults = UserDefaults.standard
        var numberOfCurrentMaxBands = defaults.integer(forKey: CURRENT_NUMBER_OF_MAX_BANDS_STRING)

        if numberOfCurrentMaxBands < DEFAULT_NUMBER_OF_MIN_BANDS_INT || numberOfCurrentMaxBands > DEFAULT_NUMBER_OF_MAX_BANDS_INT {
            numberOfCurrentMaxBands = DEFAULT_MAX_BANDS_VALUE_INT //20
            
            defaults.set(numberOfCurrentMaxBands, forKey: CURRENT_NUMBER_OF_BANDS_STRING)
        }
        
        self.maxBandsLabel.text = "\(numberOfCurrentMaxBands)"
        self.maxBandsSlider.value = Float(numberOfCurrentMaxBands)
        self.maxBandsSlider.minimumValue = Float(DEFAULT_NUMBER_OF_MIN_BANDS_INT)
        self.maxBandsSlider.maximumValue = Float(DEFAULT_NUMBER_OF_MAX_BANDS_INT)
    }
    
    @IBAction func maxBandsSliderChanged(_ slider: UISlider) {
        let currentNumberOfBands = Int(slider.value)
        self.maxBandsLabel.text = "\(currentNumberOfBands)"
        print(currentNumberOfBands)
        UserDefaults.standard.set(currentNumberOfBands, forKey: CURRENT_NUMBER_OF_MAX_BANDS_STRING)
        
        // Post notification so main screen can update its max bands value
        NotificationCenter.default.post(name: NSNotification.Name("MaxBandsValueChanged"), object: nil)
    }
    
}

//extension SettingsViewController: UITextFieldDelegate {
//    func textFieldDidEndEditing(_ textField: UITextField) {
//        if (textField.tag == bandsTextFieldTag) {
//            print("value in textfield is = \(maxBandsTextfield.text ?? defaultBandsValue)")
//            guard let bandsIntValue: Int = Int(maxBandsTextfield.text ?? defaultBandsValue)
//                else {
//                print("bandsIntValue is bad")
//                maxBandsTextfield.text = defaultBandsValue
//                UserDefaults.standard.set(defaultBandsValueInt, forKey: USERDEFAULTS_MAX_BANDS)
//                return
//            }
//
//            if ( (bandsIntValue >= 3) && (bandsIntValue <= maxBandsValueInt)) { //&& (bandsIntValue < defaultBandsValue)) {
//                UserDefaults.standard.set(bandsIntValue, forKey: USERDEFAULTS_MAX_BANDS)
//            }
//            else {
//                maxBandsTextfield.text = defaultBandsValue
//                UserDefaults.standard.set(defaultBandsValueInt, forKey: USERDEFAULTS_MAX_BANDS)
//            }
//        }
//    }
//}

extension SettingsViewController: MFMailComposeViewControllerDelegate {
    func sendEmail() {
        if MFMailComposeViewController.canSendMail() {
            let mail = MFMailComposeViewController()
            mail.mailComposeDelegate = self
            mail.setToRecipients(["support@indiefilmgear.com"])
            mail.setSubject("Support Question")
            mail.setMessageBody("<p>Hello Support Peeps,</p>", isHTML: true)
            
            present(mail, animated: true)
        } else {
            // show failure alert
            print("failure to launch email console")
            let alertView = UIAlertController(title: "Mail Error", message: "Please setup your mail client on the device first in order to send emails", preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: "ok", style: .cancel, handler: nil)
            alertView.addAction(cancelAction)
            self.present(alertView, animated: true, completion: nil)
        }
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }
}
