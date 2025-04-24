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
            guard let filePath = Bundle.main.path(forResource: "html/instructions", ofType: "html") ??
                                 Bundle.main.path(forResource: "instructions", ofType: "html")
            else {
                // File Error
                print("File not found: instructions.html")
                
                // Display error message in the webview
                let errorHTML = """
                <html>
                <body style="font-family: -apple-system, sans-serif; color: #333; text-align: center; padding: 20px;">
                    <h2>Error Loading Instructions</h2>
                    <p>The instructions file could not be found.</p>
                </body>
                </html>
                """
                webView.loadHTMLString(errorHTML, baseURL: nil)
                return
            }
            
            let contents = try String(contentsOfFile: filePath, encoding: .utf8)
            let baseUrl = URL(fileURLWithPath: filePath)
            webView.loadHTMLString(contents, baseURL: baseUrl)
        }
        catch {
            print("File HTML error: \(error.localizedDescription)")
            
            // Display error message in the webview
            let errorHTML = """
            <html>
            <body style="font-family: -apple-system, sans-serif; color: #333; text-align: center; padding: 20px;">
                <h2>Error Loading Instructions</h2>
                <p>There was a problem loading the instructions: \(error.localizedDescription)</p>
            </body>
            </html>
            """
            webView.loadHTMLString(errorHTML, baseURL: nil)
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
