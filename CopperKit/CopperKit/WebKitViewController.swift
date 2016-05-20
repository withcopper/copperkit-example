//
//  WebKitViewController
//  Copper
//
//  Created by Doug Williams on 5/12/16.
//  Copyright (c) 2015 Doug Williams. All rights reserved.
//

import Foundation
import WebKit

public class WebKitViewController: UIViewController {
    
    class func webKitViewController() -> WebKitViewController {
        let controller = UIStoryboard(name: "WebKit", bundle: CopperKitBundle).instantiateInitialViewController() as! WebKitViewController
        return controller
    }
    
    @IBOutlet weak var webView: UIWebView!
    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var networkActivityIndicator: NetworkActivityIndicatorView!

    var c29delegate: C29UserInfoViewControllerDelegate?
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        self.modalPresentationStyle = .Custom
        headerView.backgroundColor = UIColor.copper_white()
        headerView.addBorder(edges: .Bottom, color: UIColor.copper_black().colorWithAlphaComponent(0.12), thickness: 1.0)
        webView.backgroundColor = UIColor.hexStringToUIColor("#F5F5F5")
        webView.opaque = false
        networkActivityIndicator.barColor = UIColor.self.copper_black92()
        webView.dataDetectorTypes = .None // prevents phone numbers and email addresses from automatically linking, limits to HTTP Links
        webView.delegate = self
        closeButton.tintColor = UIColor.self.copper_black92()
        closeButton.setImage(C29ImageAssets.IconClose.image, forState: .Normal)
        NSNotificationCenter.defaultCenter().addObserver(self,
                                                        selector: #selector(WebKitViewController.loginLinkReceived(_:)),
                                                            name: C29ApplicationLinkReceivedNotification,
                                                            object: nil)
    }
        
    func loginLinkReceived(notification: NSNotification) {
        c29delegate?.openURLReceived(notification, withViewController: self)
    }

    func loadWebview(url: NSURL, headers: [String:String]! = nil) {
        let request = NSMutableURLRequest(URL: url)
        if let headers = headers {
            for (header, value) in headers {
                request.setValue(value, forHTTPHeaderField: header)
            }
        }
        self.webView.loadRequest(request)
    }

    @IBAction func closeButtonPressed(sender: AnyObject) {
        self.c29delegate?.finish(nil, error: nil)
    }
}

extension WebKitViewController: UIWebViewDelegate {
    public func webViewDidStartLoad(webView: UIWebView) {
        networkActivityIndicator.networkActivityViewStarted = true
        self.c29delegate?.trackEvent(.DialogWebKitPageLoadComplete)
    }
    public func webViewDidFinishLoad(webView: UIWebView) {
        networkActivityIndicator.networkActivityViewStarted = false
    }
    public func didFailLoadWithError(webView: UIWebView) {
        networkActivityIndicator.networkActivityViewStarted = false
    }
}



extension WebKitViewController {
    enum Error: Int {
        case DocumentDidNotLoad = 0
        var reason: String {
            switch self {
            case .DocumentDidNotLoad:
                return "Document Did Not Load"
            }
        }
        var nserror: NSError {
            return NSError(domain: self.domain, code: self.rawValue, userInfo: [NSLocalizedFailureReasonErrorKey: self.reason])
        }
        var domain: String {
            return "\(NSBundle.mainBundle().bundleIdentifier!).WebKitViewController"
        }
    }
}