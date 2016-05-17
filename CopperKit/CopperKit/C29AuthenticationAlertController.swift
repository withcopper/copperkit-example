//
//  C29AuthenticationAlertController
//  Copper
//
//  Created by Doug Williams on 4/17/15.
//  Copyright (c) 2015 Doug Williams. All rights reserved.
//

import UIKit
import AudioToolbox

protocol C29AuthenticationAlertControllerCellDelegate {
    func countryCodeDidBecomeFirstResponder()
    func didUpdateCountryCode(code: String)
    func didUpdatePhoneNumber(phoneNumber: String)
    func didUpdateDigitsEntry(digits: String)
    func sendButtonWasPressed()
}

public protocol C29AuthenticationAlertControllerDelegate {
    func authenticationDidFinishWithVerificationResult(verificationResult: C29VerificationResult, phoneNumber: String)
    func authenticationDidFinishUserCancelled()
}

public class C29AuthenticationAlertController: NSObject, CopperAlertControllerDatasource {
    
    
    let MaxPhoneNumberLength = 20
    var MaxDigitsLength = 6
    
    let transitioningDelegate = ModalCardTransitioningDelegate()
    let alertController = CopperAlertViewController.alertViewController()
    var backgroundTapView: UIView!
    
    var delegate: C29AuthenticationAlertControllerDelegate?
    
    var verificationCode: C29VerificationCode?
    let secret = C29Utils.getGUID()
    var networkAPI: CopperNetworkAPI!

    var countryCode = C29AuthenticationAlertController.DefaultCountryCode.countryCode
    var countryCodePrefix = C29AuthenticationAlertController.DefaultCountryCode.prefix
    var phoneNumber = ""
    var prettyPrintPhoneNumber = "You"
    var toPhoneNumber: String {
        return "\(countryCodePrefix)\(phoneNumber)"
    }

    var digitsEntry = ""
    
    static var DefaultCountryCode: (countryCode: String, prefix: String) {
        // attempt to use the person's phone number and local country code
        if let countryCode = C29Utils.getPhoneCountryCode(),
            let prefix = CopperPhoneRecord.getPrefixForCountryCode(countryCode) {
            return (countryCode, "+\(prefix)")
        }
        return ("US", "+1")
    }
    
    enum State: Int {
        case Init = 0
        case PhoneNumber = 1
        case Verification = 2
        case Login = 3
        case Cancelled = 4
    }
    
    var state: State = .Init {
        didSet {
            guard state != oldValue else { return }
            switch self.state {
            case .PhoneNumber:
                alert.title = "Sign in"
                alert.message = "We use your mobile number and a text message to protect your account."
                alert.removeAllActions()
                alert.addAction(cancelAction!)
                alert.addAction(nextAction!)
                self.cancelAction?.enabled = true
                self.phoneNumberSent = false
                self.digitsEntrySent = false
            case .Verification:
                alert.title = "Verify your number"
                alert.message = "We sent \(prettyPrintPhoneNumber) a text.\nWhat is your 👉code👈?"
                alert.removeAllActions()
                alert.addAction(wrongNumberAction!)
                alert.addAction(resendCodeAction!)
                self.resetDigitsEntry()
                self.resendCodeAction?.enabled = true
                self.wrongNumberAction?.enabled = true
                self.phoneNumberSent = true
                self.digitsEntrySent = false
            case .Login:
                self.resetDigitsEntry()
                alert.title = prettyPrintPhoneNumber
                alert.message = "Logged in"
                alert.removeAllActions()
                alert.image = C29ImageAssets.LoginCheckbox.image
                titleCell?.titleTextColor = UIColor.copper_primaryGreen()
                self.phoneNumberSent = true
                self.digitsEntrySent = true
            case .Cancelled:
                alert.title = "Cancelled"
                alert.message = nil
                alert.removeAllActions()
                alert.image = C29ImageAssets.LoginCancelled.image
                titleCell?.titleTextColor = UIColor.copper_secondaryRed()
                self.phoneNumberSent = true
                self.digitsEntrySent = true
            default:
                break // no op
            }
            messageCell?.messageTextColor = CopperAlertMessageCell.DefaultTextColor
            self.numberPadCell?.numberPadUpdateDeleteButtonStatus()
            self.resetIdentifiers()
        }
    }
    
    var alert = C29Alert()
    var wrongNumberAction: C29AlertAction?
    var resendCodeAction: C29AlertAction?
    var cancelAction: C29AlertAction?
    var nextAction: C29AlertAction?
    
    var phoneNumberSent = false {
        didSet {
            self.updateNextButtonStatus()
            self.numberPadDeleteShouldBeEnabled()
        }
    }
    
    var digitsEntrySent = false {
        didSet {
            self.numberPadDeleteShouldBeEnabled()
        }
    }
    
    var phoneEntryCell: CopperAlertPhoneNumberEntryCell? {
        return self.alertController.alertTableViewManager?.phoneEntryCell
    }
    
    var digitsEntryCell: CopperAlertDigitEntryCell? {
        return self.alertController.alertTableViewManager?.digitEntryCell
    }

    var numberPadCell: CopperAlertNumberPadCell? {
        return self.alertController.alertTableViewManager?.numberPadCell
    }
    
    var titleCell: CopperAlertTitleCell? {
        return self.alertController.alertTableViewManager?.titleCell
    }
    
    var messageCell: CopperAlertMessageCell? {
        return self.alertController.alertTableViewManager?.messageCell
    }
    
    var imageCell: CopperAlertImageCell? {
        return self.alertController.alertTableViewManager?.imageCell
    }
    
    var viewLoaded = false
    
    // MARK: C29AlertControllerDatasource -- tells the UI what cells to draw!
    
    internal var identifiers = [CopperAlertTableRowConfig]()
    
    // end C29AlertControllerDatasource
    
    init(networkAPI: CopperNetworkAPI) {
        super.init()
        self.backgroundTapView = UIView()
        self.wrongNumberAction = C29AlertAction(title: "Wrong number", format: .Inline, closeAfterAction: false, handler: {
            self.resetDigitsEntry()
            self.didUpdatePhoneNumber(self.phoneNumber)
            self.setState(.PhoneNumber)
        })
        wrongNumberAction!.repeatable = true
        self.resendCodeAction = C29AlertAction(title: "Resend code", format: .Inline, closeAfterAction: false, handler: {
            self.alert.message = "We texted a new code"
            self.messageCell?.messageTextColor = CopperAlertMessageCell.DefaultTextColor
            self.resetDigitsEntry()
            self.startRegistration(to: self.toPhoneNumber, secret: self.secret)
        })
        resendCodeAction!.repeatable = true
        self.cancelAction = C29AlertAction(title: "Go back", format: .Inline, closeAfterAction: false, handler: {
            self.nextAction?.enabled = false
            self.cancelAction?.enabled = false
            self.delegate?.authenticationDidFinishUserCancelled()
        })
        cancelAction!.repeatable = true
        self.nextAction = C29AlertAction(title: "Next", format: .Default, style: .Green, closeAfterAction: false, handler: {
            self.nextAction?.enabled = false
            self.startRegistration(to: self.toPhoneNumber, secret: self.secret)
        })
        nextAction!.repeatable = true
        updateNextButtonStatus()
        self.alertController.alert = alert
        alertController.delegate = self
        alertController.dataSource = self
        alertController.closeOnTap = false
        self.networkAPI = networkAPI
    }
    
    func setState(state: State) {
        self.state = state
        if viewLoaded {
            // onInit and alertController hasn't been fully initialized yet, prevents the runtime error
            self.alertController.reload(true)
        }
    }
    
    private func resetIdentifiers() {
        var i = [CopperAlertTableRowConfig]()
        switch self.state {
        case .PhoneNumber:
            i.append(CopperAlertTableRowConfig(cellIdentifier: .TitleCell))
            i.append(CopperAlertTableRowConfig(cellIdentifier: .MessageCell))
            i.append(CopperAlertTableRowConfig(cellIdentifier: .PhoneNumberEntryCell))
            i.append(CopperAlertTableRowConfig(cellIdentifier: .NumberPadCell))
            i.append(CopperAlertTableRowConfig(cellIdentifier: .TwoButtonCell, action: cancelAction!, action2: nextAction!))
        case .Verification:
            i.append(CopperAlertTableRowConfig(cellIdentifier: .TitleCell))
            i.append(CopperAlertTableRowConfig(cellIdentifier: .MessageCell))
            i.append(CopperAlertTableRowConfig(cellIdentifier: .TwoButtonCell, action: wrongNumberAction!, action2: resendCodeAction!))
            i.append(CopperAlertTableRowConfig(cellIdentifier: .DigitEntryCell))
            i.append(CopperAlertTableRowConfig(cellIdentifier: .NumberPadCell))
        case .Login:
            i.append(CopperAlertTableRowConfig(cellIdentifier: .TitleCell))
            i.append(CopperAlertTableRowConfig(cellIdentifier: .MessageCell))
            i.append(CopperAlertTableRowConfig(cellIdentifier: .ImageCell))
        case .Cancelled:
            i.append(CopperAlertTableRowConfig(cellIdentifier: .TitleCell))
            i.append(CopperAlertTableRowConfig(cellIdentifier: .ImageCell))
        default:
            break
        }
        self.identifiers = i
    }

    func displayWithViewController(viewController: UIViewController, completion: (()->())! = nil) {
        alertController.transitioningDelegate = transitioningDelegate
        viewController.presentViewController(alertController, animated: true, completion: {
            completion?()
        })
    }
    
    func cancel() {
        self.setState(.Cancelled)
        C29Utils.delay(C29Utils.animationDuration*2) {
            self.close()
        }
    }
    
    func close() {
        self.alertController.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func updateNextButtonStatus() {
        let enable = phoneNumber.characters.count >= 5
        if nextAction?.enabled != enable {
            nextAction?.enabled = enable
        }
    }
    
    // MARK: Control Display Management
    
    func resetPhoneNumberEntry() {
        didUpdatePhoneNumber("")
    }

    func resetDigitsEntry() {
        didUpdateDigitsEntry("")
    }
    
    // MARK: Background Tap View Management
    
    private func configureBackgroundTapView() {
        backgroundTapView.frame = self.alertController.view.bounds
        let backgroundTapGesture = UITapGestureRecognizer(target: self, action: #selector(C29AuthenticationAlertController.didTapBackgroundTapView(_:)))
        backgroundTapView.addGestureRecognizer(backgroundTapGesture)
        backgroundTapView.hidden = true // this is toggled when the countryCode picker shows up
        self.alertController.view.addSubview(backgroundTapView)
    }

    func didTapBackgroundTapView(sender: AnyObject) {
        self.phoneEntryCell?.countryCodeControl.resignFirstResponder()
        self.backgroundTapView.hidden = true
    }
    
    // MARK: Primary State Machine Handlers
    
    // step 1: swap our phone number for a verification code
    func startRegistration(to phoneNumber:String, secret: String) {
        self.alertController.indicate = true
        let url = NSURL(string: "\(networkAPI.URL)/\(C29APIPath.Users.rawValue)/\(C29APIPath.Verify.rawValue)")!
        let params: [String:String] = ["to" : phoneNumber, "secret" : secret]
        let request = CopperNetworkAPIRequest(method: .DIALOG_VERIFY,
                                              httpMethod: .POST,
                                              url: url,
                                              authentication: false,
                                              params: params,
                                              callback: { (result: C29APIResult) in
                                                self.alertController.indicate = false
                                                switch result {
                                                case let .Error(error):
                                                    self.handleVerificationFailure(withError: error)
                                                case let .Success(_, dataDict):
                                                    guard let dataDict = dataDict else {
                                                        self.handleVerificationFailure(withError: Error.UnknownError.nserror)
                                                        return
                                                    }
                                                    guard let verificationCode = C29VerificationCode.fromDictionary(dataDict) else {
                                                        self.handleVerificationFailure(withError: Error.UnknownError.nserror)
                                                        return
                                                    }
                                                    self.verificationCode = verificationCode
                                                    self.prettyPrintPhoneNumber = CopperPhoneRecord(isoNumber: self.toPhoneNumber, verified: true).displayString
                                                    self.setState(.Verification)
                                                    self.resetDigitsEntry()
                                                }
        })
        networkAPI.makeHTTPRequest(request)
    }
    
    // step 2: trade our digits + code for a user reg (hopefully)
    func attemptVerification(digits: String) {
        // ensure we have all the prereqs
        guard let verificationCode = self.verificationCode else {
            // restart the process if we don't have a verificationCode
            self.setState(.PhoneNumber)
            return
        }
        // ok, let's make the call
        self.alertController.indicate = true
        let url = NSURL(string: "\(networkAPI.URL)/\(C29APIPath.Users.rawValue)/\(C29APIPath.Verify.rawValue)/\(verificationCode.code)")!
        let params: [String:String] = ["digits" : digits]
        let request = CopperNetworkAPIRequest(method: .DIALOG_VERIFY_CODE,
                                              httpMethod: .POST,
                                              url: url,
                                              authentication: false,
                                              params: params,
                                              callback: { (result: C29APIResult) in
                                                self.alertController.indicate = false
                                                C29VerificationResult.fromAPIResult(result, callback: { (verificationResult: C29VerificationResult?, error: NSError?) in
                                                    if let error = error {
                                                        self.handleVerificationFailure(withError: error)
                                                        return
                                                    }
                                                    if let verificationResult = verificationResult {
                                                        C29Log(.Debug, "CoppperKitAlertController attemptVerification with digits \(digits) successful")
                                                        verificationResult.secret = self.secret
                                                        self.handleVerificationSuccess(withVerificationResult: verificationResult)
                                                    } else {
                                                        self.handleVerificationFailure(withError: Error.UnknownError.nserror)
                                                    }
                                                })
        })
        networkAPI.makeHTTPRequest(request)
    }
    
    func handleVerificationSuccess(withVerificationResult result: C29VerificationResult) {
        digitsEntrySent = true
        C29Log(.Debug, "Registration Success: Setting up account \(result.userId) with jwt \(result.token).")
        self.digitsEntryCell?.setSuccess()
        // delay for some animations
        C29Utils.delay(1.0) {
            self.delegate?.authenticationDidFinishWithVerificationResult(result, phoneNumber: self.toPhoneNumber)
            C29Utils.delay(C29Utils.animationDuration) {
                // we want to hide this behind the web view, hence the delay to allow the animation to finish
                self.setState(.Login)
                
            }
        }
    }

    func handleVerificationFailure(withError error: NSError?) {
        guard let error = error else {
            C29Log(.Error, "There was a problem with the verification flow without an NSError")
            // If we are here without an NSError, there is nothing for us to inspect, nor do... so best guess is to send the person back to the start...
//            alertController.V29_displayError("There was a problem with no information", message: "Try again from the start.", error: Error.UnknownError.nserror)
            resetPhoneNumberEntry()
            self.setState(.PhoneNumber)
            return
        }
        
        AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
        var errorReason: String?
        if !Reachability.isConnectedToNetwork() {
            errorReason = Error.NetworkConnectionFailure.description
            didUpdatePhoneNumber(self.phoneNumber)
        } else {
            switch state {
            case .PhoneNumber:
                errorReason = Error.InvalidPhoneNumber.description
                self.resetPhoneNumberEntry()
            case .Verification:
                var delay = 3.0
                switch error.code {
                case C29VerificationError.DialogCodeExpired.rawValue:
                    errorReason = Error.CodeExpired.description
                    C29Utils.delay(delay) {
                        self.setState(.PhoneNumber)
                    }
                case C29VerificationError.DialogCodeLocked.rawValue:
                    errorReason = Error.CodeLocked.description
                    C29Utils.delay(delay) {
                        self.setState(.PhoneNumber)
                    }
                case C29VerificationError.DialogCodeInvalid.rawValue:
                    errorReason = Error.CodeInvalid.description
                    delay = 1.0
                default:
                    errorReason = Error.UnknownError.description
                    C29Utils.delay(delay) {
                        self.setState(.PhoneNumber)
                    }
                }
                // Update the UI
                self.resetDigitsEntry()
                self.digitsEntryCell?.setIncorrect()
                C29Utils.delay(delay) {
                    // don't reset if the user has been typing already
                    if self.digitsEntry == "" {
                        self.resetDigitsEntry()
                    }
                }
            default:
                break
            }
        }
        if let errorReason = errorReason {
            alert.message = errorReason
            messageCell?.messageTextColor = UIColor.copper_RegistrationViewErrorTextColor()
        }
        alertController.reload(true) // TODO more graceful animation
    }

}

extension C29AuthenticationAlertController: CopperAlertViewControllerDelegate {
    public func viewDidLoadFinished() {
        // no op
        configureBackgroundTapView()
        self.alertController.alertTableViewManager?.numberPadCell?.numberPadDelegate = self as CopperAlertNumberPadCellDelegate
        self.alertController.alertTableViewManager?.phoneEntryCell?.alertCellDelegate = self
        self.alertController.alertTableViewManager?.numberPadCell?.numberPadHeightConstraint.constant = (self.alertController.view.frame.height / 2)
        self.alertController.reload(true)
        self.viewLoaded = true
    }
    public func viewDidAppearFinished() {
        // no op
    }
}

extension C29AuthenticationAlertController: C29AuthenticationAlertControllerCellDelegate {
    func countryCodeDidBecomeFirstResponder() {
        self.backgroundTapView.hidden = false
    }
    func didUpdateCountryCode(countryCode: String) {
        guard let prefix = CopperPhoneRecord.getPrefixForCountryCode(countryCode) else {
            let pickerError = Error.CountrtCodePickerPrefixNotFound
            C29LogWithRemote(.Error, error: pickerError.nserror, infoDict: ["affected country code": "\(countryCode)"])
            return
        }
        self.countryCode = countryCode
        self.countryCodePrefix = "+\(prefix)"
        C29Log(.Debug, "C29AuthenticationAlertController didUpdateCountryCode to \"\(countryCode) with prefix \(countryCodePrefix) toPhoneNumber \(toPhoneNumber)\"")
        self.phoneEntryCell?.setCountryCodeToPrefix(countryCodePrefix)
    }
    func didUpdatePhoneNumber(phoneNumber: String) {
        // ensure we're not at our phone number limit
        if self.phoneNumber.characters.count > MaxPhoneNumberLength {
            C29Log(.Debug, "C29AuthenticationAlertController didUpdatePhoneNumber to \"\(phoneNumber) is already at the maximum lenght of \(MaxPhoneNumberLength)")
            return
        }
        // otherwise, move forward
        self.phoneNumber = phoneNumber
        C29Log(.Debug, "C29AuthenticationAlertController didUpdatePhoneNumber to \"\(phoneNumber) with toPhoneNumber \(toPhoneNumber)\"")
        self.phoneEntryCell?.setPhoneNumber(phoneNumber)
        updateNextButtonStatus()
        self.numberPadCell?.numberPadUpdateDeleteButtonStatus()
    }
    func didUpdateDigitsEntry(digits: String) {
        guard !digitsEntrySent else { return }
        if self.digitsEntry.characters.count > MaxDigitsLength {
            C29Log(.Debug, "C29AuthenticationAlertController didUpdateDigitsEntry to \"\(digits) but digitsEntry is already at the maximum lenght of \(MaxPhoneNumberLength)")
            return
        }
        digitsEntry = digits
        C29Log(.Debug, "C29AuthenticationAlertController didUpdateDigitsEntry to \"\(digits)\"")
        self.digitsEntryCell?.setDigitsEntry(digits)
        self.numberPadCell?.numberPadUpdateDeleteButtonStatus()
    }
}

extension C29AuthenticationAlertController: CopperAlertNumberPadCellDelegate {
    func numberPadDeleteWasPressed() {
        switch self.state {
        case .PhoneNumber:
            if phoneNumber.characters.count > 0 {
                didUpdatePhoneNumber(phoneNumber.substringToIndex(phoneNumber.endIndex.predecessor()))
            }
        case .Verification:
            if digitsEntry.characters.count > 0 {
                didUpdateDigitsEntry(digitsEntry.substringToIndex(digitsEntry.endIndex.predecessor()))
            }
        default:
            break // we should never be here
    }
    }
    func numberPadWasPressed(key: CopperNumberPadKey) {
        switch self.state {
        case .PhoneNumber:
            self.didUpdatePhoneNumber(phoneNumber+"\(key.rawValue)")
        case .Verification:
            self.didUpdateDigitsEntry(digitsEntry+"\(key.rawValue)")
            if digitsEntry.characters.count == MaxDigitsLength {
                attemptVerification(digitsEntry)
            }
        default:
            return
        }
    }
    func numberPadDeleteShouldBeEnabled() -> Bool {
        switch state {
        case .PhoneNumber:
            return  phoneNumber.characters.count > 0 && !phoneNumberSent
        case .Verification:
            return  digitsEntry.characters.count > 0 && !digitsEntrySent
        default:
            return false
        }
    }
    func sendButtonWasPressed() {
        self.startRegistration(to: toPhoneNumber, secret: self.secret)
    }
}

extension C29AuthenticationAlertController {
    enum Error: Int {
        case UnknownError = 1
        case CodeExpired = 2
        case CodeLocked = 3
        case CodeInvalid = 4
        case CountrtCodePickerPrefixNotFound = 5
        case InvalidPhoneNumber = 6
        case NetworkConnectionFailure = 7
        
        var reason: String {
            switch self {
            case .UnknownError:
                return "We're having problems"
            case .CodeExpired:
                return "The code expired"
            case .CodeLocked:
                return "The code is locked"
            case .CodeInvalid:
                return "The code is incorrect"
            case .CountrtCodePickerPrefixNotFound:
                return "County Code Prefix Not Found"
            case .InvalidPhoneNumber:
                return "Invalid phone number"
            case .NetworkConnectionFailure:
                return "The network connection is down."
            }
        }
        var description: String {
            switch self {
            case .UnknownError:
                return "Something is weird and we need you to start over. We’ve notified our humans of this stunning embarrassment."
            case .CodeExpired:
                return "Your code expired. Let's try again."
            case .CodeLocked:
                return "Too many tries. We need to start over."
            case .CodeInvalid:
                return "Wrong code. Try again. 🤔"
            case .CountrtCodePickerPrefixNotFound:
                return "We weren't able to find a country code in our database for this Country. We've let our human programmers know of this stunning embarassment."
            case .InvalidPhoneNumber:
                return "We were not able to text that number."
            case .NetworkConnectionFailure:
                return "📡 Your network connection is down or too weak. Try again when you have better service. "
                //default:
                //  return self.reason
            }
        }
        var nserror: NSError {
            return NSError(domain: self.domain, code: self.rawValue, userInfo: [NSLocalizedFailureReasonErrorKey: self.reason])
        }
        var domain: String {
            return "\(NSBundle.mainBundle().bundleIdentifier!).C29AuthenticationAlertController"
        }
    }
}
    
