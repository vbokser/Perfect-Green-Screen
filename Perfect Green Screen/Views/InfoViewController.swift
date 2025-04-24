//
//  SettingsViewController.swift
//  Perfect Greenscreen
//
//  Created by Vitaly Bokser on 3/26/19.
//  Copyright © 2019 Vitaly Bokser. All rights reserved.
//

import UIKit
import WebKit

class InfoViewController: UIViewController {

    
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var webView: WKWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        backButton.layer.cornerRadius = 10
        loadWebView()
    }
    
    func loadWebView() {
        // Adding webView content
        do {
            guard let filePath = Bundle.main.path(forResource: "html/instructions", ofType: "html")
                else {
                    // File Error
                    print ("File reading error")
                    return
            }
            
            let contents =  try String(contentsOfFile: filePath, encoding: .utf8)
            let baseUrl = URL(fileURLWithPath: filePath)
            webView.loadHTMLString(contents as String, baseURL: baseUrl)
        }
        catch {
            print ("File HTML error")
        }
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    
    @IBAction func dismissVC(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }

}
