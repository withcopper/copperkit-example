//
//  C29Application
//  Copper
//
//  Created by Doug Williams on 3/7/16.
//  Copyright © 2016 Copper Technologies, Inc. All rights reserved.
//

import Foundation

internal let C29ApplicationLinkReceivedNotification = "C29ApplicationLinkReceivedNotification"

public typealias C29ApplicationUserInfoCompletionHandler = ((result: C29UserInfoResult<C29UserInfo, NSError>)->())

public enum C29UserInfoResult<T, U> {
    case UserCancelled
    case Success(T)
    case Failure(U)
}

public protocol C29ApplicationDelegate {
    func didFinishWithResult(result: C29UserInfoResult<C29UserInfo, NSError>)
}

internal protocol C29UserInfoViewControllerDelegate: class {
    func openURLReceived(notification: NSNotification, withViewController: UIViewController)
    func trackEvent(event: C29Application.TrackingEvent)
    func finish(userInfo: C29UserInfo?, error: NSError?)
}

public class C29Application: NSObject {
    
    // Our singleton
    public static let sharedInstance = C29Application()
    
    public enum TrackingEvent: String {
        case LoginStarted = "C29Application - 1. Login Started"
        case LoginCancelled = "C29Application - 1a. Login Cancelled"
        case LoginSuccessful = "C29Application - 2. Login Verification Successful"
        case DialogSafariPageLoadComplete = "C29Application - 3a. Dialog Safari Page Load Complete"
        case DialogWebKitPageLoadComplete = "C29Application  - 3b. Dialog WebKit Page Load Complete"
        case DialogRedirect = "C29Application - 4. Dialog redirect"
        case ContinueComplete = "C29Application - 4. Continue was successful"
        case ContinueError = "C29Application - 4a. Continue errored"
        case ContinueCancelled = "C29Application - 4b. Continue was cancelled"
    }
    
    private enum QueryItems: String {
        case ClientId = "client_id"
        case Scope = "scope"
        case ApplicationType = "application_type"
        case Token = "token"
        case PhoneNumber = "phone_number"
    }
    
    private let CopperKitApplicationType = "copperkit9"
    private static let LoginHostName = "login" // expected custom URL scheme like cu<applicationId>://login?
    
    private var coordinator: C29UserInfoCoordinator? {
        didSet {
            self.mixpanel.identify(coordinator?.sessionId)
        }
    }
    private var _applicationId: String?
    
    public var id: String? {
        get {
            return _applicationId
        }
    }
    
    private var trackableParameters: [String:AnyObject] {
        get {
            return ["applicationId":(self._applicationId ?? "null"),
                    "authenticated": self.authenticated]
        }
    }
    
    public var authenticated: Bool {
        get {
            return self.jwt != nil && self.userId != nil && self.verificationResult != nil && self.phoneNumber != C29Application.DefaultPhoneNumber
        }
    }
    
    // MARK: Instance variables
    private let networkAPI = CopperNetworkAPI()
    
    public var verificationResult: C29VerificationResult?
    internal var jwt: String? {
        return verificationResult?.token
    }
    internal var userId: String? {
        return verificationResult?.userId
    }
    
    // MARK: Optional Config Variables
    public var scopes: [C29Scope]? = C29Scope.DefaultScopes // defaults
    
    // MARK: Private internal variables
    private var mixpanel = Mixpanel(token: MixPanelToken)
    private var completion: C29ApplicationUserInfoCompletionHandler?
    static let DefaultPhoneNumber = "You"
    public var phoneNumber: String = DefaultPhoneNumber
    
    // MARK: View Controllers and UI elements
    private var presentingViewController: UIViewController?
    private var authenticationAlert: C29AuthenticationAlertController!
    private var userInfoViewController: UIViewController?
    
    // MARK: Optional test and debug
    public var debug: Bool = false {
        didSet {
            if debug {
                if C29LoggerLevel.rawValue > C29LogLevel.Debug.rawValue {
                    C29LoggerLevel = .Debug
                }
            } else {
                if C29LoggerLevel.rawValue < C29LogLevel.Info.rawValue {
                    C29LoggerLevel = .Info
                }
            }
        }
    }
    // when true, we will use the fallback WKWebKit view instead of the SFSafariViewController -- helpful for testing && debugging
    public var degrade = false
    public var baseURL: String = "https://open.withcopper.com"
    
    public var delegate: C29ApplicationDelegate?
    
    override init() {
        super.init()
        self.networkAPI.delegate = self
        authenticationAlert = C29AuthenticationAlertController(networkAPI: networkAPI)
        self.debug = false
    }
    
    public func configureForApplication(applicationId: String) {
        C29Log(.Debug, "C29Application setting application id to \(applicationId)")
        _applicationId = applicationId
        coordinator = C29UserInfoCoordinator(application: self)
    }
    
    public func login(withViewController viewController: UIViewController, phoneNumber: String! = nil, completion: C29ApplicationUserInfoCompletionHandler) {
        C29Log(.Debug, "C29Application login with applicationId \(_applicationId ?? "null") and scopes \(C29Scope.getCommaDelinatedString(fromScopes: scopes) ?? "no scopes")")
        // Housekeeping:
        guard guaranteeConfigured() else {
            C29Log(.Error, Error.ApplicationIdNotSet.reason)
            completion(result: .Failure(Error.ApplicationIdNotSet.nserror))
            return
        }
        
        // Store our instance variables
        self.presentingViewController = viewController
        if let phoneNumber = phoneNumber {
            self.phoneNumber = phoneNumber
        }
        self.completion = completion
        
        // On with the request:
        self.showAuthenticationAlert(withViewController: viewController, completion: {
            // Give the alertViewController animations time to finish
            C29Utils.delay(0.5) {
                if self.authenticated {
                    // 0. check if we even need any scopes
                    guard self.scopes != nil else {
                        // note: self.phoneNumber and self.verificationResult is guaranteed by authenticated
                        self.coordinator?.fromVerificationResult(self.verificationResult!, phoneNumber: self.phoneNumber)
                        self.applicationDidFinish(self.coordinator?.userInfo, error: nil)
                        return
                    }
                    // 1. check and see if we already have these records locally
                    if let userInfo = self.coordinator?.userInfo,
                        let records = userInfo.getRecords(forScopes: self.scopes) {
                        C29Log(.Debug, "C29Application open() All \(records.count) requested records locally available.")
                        self.delegate?.didFinishWithResult(.Success(userInfo))
                        completion(result: .Success(userInfo))
                        return
                    // 2. always fall back to the full web dialog
                    } else {
                        self.displayCopperWeb(withViewController: self.authenticationAlert.alertController)
                        return
                    }
                }
            }
        })
    }
    
    private func showAuthenticationAlert(withViewController viewController:UIViewController, completion: (()->())! = nil) {
        // TODO check for our cookie!
        authenticationAlert = C29AuthenticationAlertController(networkAPI: networkAPI)
        authenticationAlert.delegate = self
        authenticationAlert.prettyPrintPhoneNumber = CopperPhoneRecord(isoNumber: self.phoneNumber, verified: true).displayString
        let state: C29AuthenticationAlertController.State = authenticated ? .Login : .PhoneNumber
        authenticationAlert.setState(state)
        authenticationAlert.displayWithViewController(viewController, completion: completion)
        self.trackEvent(.LoginStarted)
    }
    
    private func displayCopperWeb(withViewController viewController: UIViewController) {
        guard let u =  NSURL(string: "\(baseURL)/\(C29APIPath.OauthDialog.rawValue)") else {
            C29Log(.Error, "C29Application baseURL is invalid '\(baseURL)/\(C29APIPath.OauthDialog.rawValue)'")
            self.completion?(result: .Failure(Error.InvalidConfiguration.nserror))
            return
        }
        // let's create our URL to make the call
        let urlComponents = NSURLComponents(URL: u, resolvingAgainstBaseURL: true)
        var queryItems = [NSURLQueryItem]()
        let queryClientId = NSURLQueryItem(name: QueryItems.ClientId.rawValue, value: self._applicationId)
        queryItems.append(queryClientId)
        let queryApplicationType = NSURLQueryItem(name: QueryItems.ApplicationType.rawValue, value: CopperKitApplicationType)
        queryItems.append(queryApplicationType)
        let queryScope = NSURLQueryItem(name: QueryItems.Scope.rawValue, value: C29Scope.getCommaDelinatedString(fromScopes: scopes))
        queryItems.append(queryScope)
        if phoneNumber != C29Application.DefaultPhoneNumber {
            let queryPhoneNumber = NSURLQueryItem(name: QueryItems.PhoneNumber.rawValue, value: phoneNumber)
            queryItems.append(queryPhoneNumber)
        }
        urlComponents?.queryItems = queryItems
        guard let url = urlComponents?.URL else {
            C29Log(.Error, "Unable to create the Copper Web url")
            return
        }
        // Display the appropriate view controller
        if #available(iOS 9.0, *) {
            displayCopperWebSFSafariViewController(viewController, url: url)
        } else {
            displayCopperWebWKWebKitController(viewController, url: url)
        }
    }
    
    @available(iOS 9.0, *)
    private func displayCopperWebSFSafariViewController(presentingViewController: UIViewController, url: NSURL) {
        // degrade means we want to use the webkit version forcably
        guard degrade == false else {
            displayCopperWebWKWebKitController(presentingViewController, url: url)
            return
        }
        let c29vc = C29UserInfoSafariViewController(URL: url)
        c29vc.c29delegate = self
        c29vc.modalTransitionStyle = UIModalTransitionStyle.CoverVertical
        presentingViewController.presentViewController(c29vc, animated: true, completion: {
            self.userInfoViewController = c29vc
        })
    }
    
    private func displayCopperWebWKWebKitController(presentingViewController: UIViewController, url: NSURL) {
        let webKitViewController = WebKitViewController.webKitViewController()
        webKitViewController.c29delegate = self
        presentingViewController.presentViewController(webKitViewController, animated: true, completion: {
            self.userInfoViewController = webKitViewController
            var headers = [String:String]()
            if let token = self.verificationResult?.token {
                headers.updateValue("Bearer \(token)", forKey: "Authorization")
            }
            webKitViewController.loadWebview(url, headers: headers)
        })
    }
    
    private func copperWebFinishedWithError(error: NSError) {
        // TODO we should inspect and react to this error
        // though it's not clear when we would get here at the moment
        C29Log(.Error, "C29Application copperWebFinishedWithError \(error)")
    }
    
    public func closeSession() {
        self.phoneNumber = C29Application.DefaultPhoneNumber
        self.verificationResult = nil
        coordinator = C29UserInfoCoordinator(application: self)
    }
    
    public func getPermittedScopes() -> [C29Scope]? {
        guard let scopes = coordinator?.userInfo?.getPermittedScopes() else {
            return nil
        }
        return scopes
    }
    
    private func applicationDidFinish(userInfo: C29UserInfo?, error: NSError?) {
        if let userInfo = userInfo {
            self.authenticationAlert.close()
            self.delegate?.didFinishWithResult(.Success(userInfo))
            self.completion?(result: .Success(userInfo))
            self.trackEvent(.ContinueComplete)
        } else if let error = error {
            self.authenticationAlert.setState(.PhoneNumber)
            self.delegate?.didFinishWithResult(.Failure(error))
            self.completion?(result: .Failure(error))
            self.trackEvent(.ContinueError)
        } else {
            // user cancelled when both are nil
            self.authenticationAlert.cancel()
            self.delegate?.didFinishWithResult(.UserCancelled)
            self.completion?(result: .UserCancelled)
            self.trackEvent(.ContinueCancelled)
        }
    }
    
    public func openURL(url: NSURL, sourceApplication: String?) -> Bool {
        C29Log(.Debug, "Beginning attemptLogin for url '\(url)' and sourceApplication '\(sourceApplication ?? "null")'")
        // ensure we're coming from the right URL
        guard let customURL = getCustomURLScheme() else {
            C29Log(.Error, Error.ApplicationIdNotSet.reason)
            return false
        }
        // curently we ignore sourceApplication which is likely Safari or a WebKit controller
        guard url.scheme.uppercaseString == customURL.uppercaseString else {
            C29Log(.Debug, "Url Scheme '\(url.scheme)' does not match the expected value of '\(customURL)')")
            return false
        }
        guard url.host == C29Application.LoginHostName else {
            C29Log(.Debug, "Url Host '\(url.host)' does not match the expected value of '\(C29Application.LoginHostName)')")
            return false
        }
        // ok -- dispatch the login if we get past the guantlet
        NSNotificationCenter.defaultCenter().postNotificationName(C29ApplicationLinkReceivedNotification, object: url)
        return true
    }
    
    private func getCustomURLScheme() -> String? {
        // our custom URL scheme is the concatination of "cu" + "application ID"
        guard let id = self.id else {
            return nil
        }
        return "cu\(id)"
    }
    
    private func guaranteeConfigured() -> Bool {
        guard let _ = _applicationId else {
            return false
        }
        return true
    }
}

extension C29Application: C29UserInfoViewControllerDelegate {
    internal func openURLReceived(notification: NSNotification, withViewController viewController: UIViewController) {
        C29Log(.Debug, "C29Application openURLReceived with notification \(notification)")
        self.trackEvent(.DialogRedirect)
        // we parse the returned URL from the notification
        guard let url = notification.object as? NSURL else {
            finish(nil, error: Error.LoginError.nserror)
            return
        }
        C29Log(.Debug, "openURLReceived with URL: \(url)")
        coordinator?.getUserInfo(withResponseURL: url, application: self, callback: { userInfo, error in
            self.finish(userInfo, error: error)
        })
    }
    internal func trackEvent(event: C29Application.TrackingEvent) {
        self.mixpanel.track(event.rawValue, parameters: self.trackableParameters)
    }
    internal func finish(userInfo: C29UserInfo?, error: NSError?) {
        if let error = error {
            self.copperWebFinishedWithError(error)
        }
        self.userInfoViewController?.dismissViewControllerAnimated(true, completion: nil)
        self.userInfoViewController = nil
        // check if the user hit Done (Cancel)
        if userInfo == nil && error == nil {
            self.closeSession()
            self.authenticationAlert.setState(.PhoneNumber)
        } else {
            applicationDidFinish(userInfo, error: error)
        }
    }
}

extension C29Application: C29AuthenticationAlertControllerDelegate {
    public func authenticationDidFinishWithVerificationResult(result: C29VerificationResult, phoneNumber: String) {
        self.verificationResult = result
        self.phoneNumber = phoneNumber
        self.trackEvent(.LoginSuccessful)
        if scopes != nil {
            self.displayCopperWeb(withViewController: authenticationAlert.alertController)
        } else {
            coordinator?.fromVerificationResult(result, phoneNumber: phoneNumber)
            applicationDidFinish(coordinator?.userInfo, error: nil)
        }
    }
    public func authenticationDidFinishUserCancelled() {
        applicationDidFinish(nil, error: nil)
        self.trackEvent(.LoginCancelled)
    }
}

extension C29Application: CopperNetworkAPIDelegate {
    @objc public func authTokenForAPI(api: CopperNetworkAPI) -> String? {
        return self.jwt
    }
    @objc public func userIdentifierForLoggingErrorsInAPI(api: CopperNetworkAPI) -> AnyObject? {
        return self.userId
    }
    @objc public func networkAPI(api: CopperNetworkAPI, recordAnalyticsEvent event: String, withParameters parameters: [String : AnyObject]) {
        C29LogWithRemote(.Error, error: Error.HTTPError.nserror, infoDict: parameters)
    }
    @objc public func networkAPI(api: CopperNetworkAPI, attemptLoginWithCallback callback: (success: Bool, error: NSError?) -> ()) {
        C29LogWithRemote(.Error, error: Error.AuthError.nserror, infoDict: nil)
        callback(success: false, error: Error.AuthError.nserror)
        // If we get here, it likely means our access token was invalid or expired
        // TODO we should use it to get a refresh token
    }
    @objc public func beganRequestInNetworkAPI(api: CopperNetworkAPI) {
        CopperNetworkActivityRegistry.sharedRegistry.activityBegan()
    }
    @objc public func endedRequestInNetworkAPI(api: CopperNetworkAPI) {
        CopperNetworkActivityRegistry.sharedRegistry.activityEnded()
    }
}

extension C29Application {
    public enum Error: Int {
        case HTTPError = 900
        case LoginError = 1
        case ApplicationIdNotSet = 2
        case InvalidConfiguration = 3
        case AuthError = 5
        
        public var reason: String {
            switch self {
            case .HTTPError:
                return "There was an unexpected HTTP response"
            case .LoginError:
                return "There was a problem logging in."
            case .ApplicationIdNotSet:
                return "Copper Application Id is not set. You must call C29Application.configure(withApplicationId: \"<appId>\"), where <appId> is your application's ID found on Copperworks @ withcopper.com/apps"
            case .InvalidConfiguration:
                return "The C29Application class is not configured properly. Set debug=true for full error reports."
            case .AuthError:
                return "The API returned an auth error -- jwt is potentially expired -- TODO implement better handling in the network delegate"
            }
        }
        public var description: String {
            switch self {
            case .LoginError:
                return "There is not url as expected."
            default:
                return self.reason
            }
        }
        var nserror: NSError {
            return NSError(domain: self.domain, code: self.rawValue, userInfo: [NSLocalizedFailureReasonErrorKey: self.reason])
        }
        var domain: String {
            return "\(NSBundle.mainBundle().bundleIdentifier!).C29Application"
        }
    }
}