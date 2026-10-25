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
        DispatchQueue.global(qos: .userInitiated).async {
            guard let filePath = Bundle.main.path(forResource: "html/instructions", ofType: "html") ??
                                 Bundle.main.path(forResource: "instructions", ofType: "html") else {
                DispatchQueue.main.async {
                    let errorHTML = """
                    <html><body><h2>Error Loading Instructions</h2><p>The instructions file could not be found.</p></body></html>
                    """
                    self.webView.loadHTMLString(errorHTML, baseURL: nil)
                }
                return
            }

            do {
                let source = try String(contentsOfFile: filePath, encoding: .utf8)
                let contents = Self.renderInstructionsHTML(source)
                let baseUrl = URL(fileURLWithPath: filePath)
                DispatchQueue.main.async {
                    self.webView.loadHTMLString(contents, baseURL: baseUrl)
                }
            } catch {
                DispatchQueue.main.async {
                    let errorHTML = """
                    <html><body><h2>Error Loading Instructions</h2><p>Problem: \(error.localizedDescription)</p></body></html>
                    """
                    self.webView.loadHTMLString(errorHTML, baseURL: nil)
                }
            }
        }
    }

//    func loadWebView() {
//        // Adding webView content
//        do {
//            guard let filePath = Bundle.main.path(forResource: "html/instructions", ofType: "html") ??
//                                 Bundle.main.path(forResource: "instructions", ofType: "html")
//            else {
//                // File Error
//                print("File not found: instructions.html")
//                
//                // Display error message in the webview
//                let errorHTML = """
//                <html>
//                <body style="font-family: -apple-system, sans-serif; color: #333; text-align: center; padding: 20px;">
//                    <h2>Error Loading Instructions</h2>
//                    <p>The instructions file could not be found.</p>
//                </body>
//                </html>
//                """
//                webView.loadHTMLString(errorHTML, baseURL: nil)
//                return
//            }
//            
//            let contents = try String(contentsOfFile: filePath, encoding: .utf8)
//            let baseUrl = URL(fileURLWithPath: filePath)
//            webView.loadHTMLString(contents, baseURL: baseUrl)
//        }
//        catch {
//            print("File HTML error: \(error.localizedDescription)")
//            
//            // Display error message in the webview
//            let errorHTML = """
//            <html>
//            <body style="font-family: -apple-system, sans-serif; color: #333; text-align: center; padding: 20px;">
//                <h2>Error Loading Instructions</h2>
//                <p>There was a problem loading the instructions: \(error.localizedDescription)</p>
//            </body>
//            </html>
//            """
//            webView.loadHTMLString(errorHTML, baseURL: nil)
//        }
//    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    
    static func renderInstructionsHTML(_ source: String, bundle: Bundle = .main) -> String {
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unavailable"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unavailable"
        let timestamp = bundle.object(forInfoDictionaryKey: "PGSBuildTimestamp") as? String ?? ""
        let buildDate = ISO8601DateFormatter().date(from: timestamp)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .long
        let displayedTimestamp = buildDate.map { formatter.string(from: $0) } ?? "Unavailable"

        func escapeHTML(_ value: String) -> String {
            value.replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
                .replacingOccurrences(of: "\"", with: "&quot;")
        }

        return source.replacingOccurrences(of: "__APP_VERSION__", with: escapeHTML(version))
            .replacingOccurrences(of: "__BUILD_NUMBER__", with: escapeHTML(build))
            .replacingOccurrences(of: "__BUILD_TIMESTAMP__", with: escapeHTML(displayedTimestamp))
    }

    @IBAction func dismissVC(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }

}
