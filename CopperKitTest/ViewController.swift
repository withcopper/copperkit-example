//
//  ViewController.swift
//  CopperKitTest
//
//  Created by Doug Williams on 3/15/16.
//  Copyright © 2016 Copper Technologies, Inc. All rights reserved.
//

import UIKit
import CopperKit

@available(iOS 9.0, *)
class ViewController: UIViewController {
    
    // Signed Out view IB Variables
    @IBOutlet weak var signedOutView: UIView!
    @IBOutlet weak var signinButton: UIButton!
    @IBOutlet weak var optionsButton: UIButton!
    @IBOutlet weak var versionLabel: UILabel!
    // Signed In view IB Variables
    @IBOutlet weak var signedInView: UIView!
    @IBOutlet weak var signoutButton: UIButton!
    @IBOutlet weak var avatarImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var phoneLabel: UILabel!
    @IBOutlet weak var userIdLabel: UILabel!
    
    static let DefaultScopes: [C29Scope] = [.Name, .Picture, .Email, .Phone] // note: C29Scope.DefaultScopes = [C29Scope.Name, C29Scope.Picture, C29Scope.Phone]
    
    // Reference to our CopperKit singleton
    var copper: C29Application?
    // Instance variable holding our desired scopes to allow changes, see showOptionsMenu()
    var desiredScopes: [C29Scope]? = ViewController.DefaultScopes
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.signedInView.setNeedsLayout()
        // reset our UI elements to the Signed Out state
        resetView()
    }
    
    @IBAction func signinButtonPressed(sender: AnyObject) {
        // get a reference to our CopperKit application instance
        copper = C29Application.sharedInstance
        // Required: configure it with our app's token
        copper!.configureForApplication("55F1DD04F89379E9F9394259994155A27C658591")
        // Optionally, decide what information we want from the user
        copper!.scopes = desiredScopes
        // OK, let's make our call
        copper!.login(withViewController: self, completion: { (result: C29UserInfoResult) in
            switch result {
            case let .Success(userInfo):
                self.setupViewWithUserInfo(userInfo)
            case .UserCancelled:
                    print("The user cancelled.")
            case let .Failure(error):
                print("Bummer: \(error)")
            }
        })
    }
    
    func setupViewWithUserInfo(userInfo: C29UserInfo) {
        self.avatarImageView.image = userInfo.picture // userInfo.pictureURL is available, too
        self.nameLabel.text = userInfo.fullName
        self.emailLabel.text = userInfo.emailAddress
        self.phoneLabel.text = userInfo.phoneNumber
        self.userIdLabel.text = userInfo.userId
        // flip our signout state
        self.signedInView.hidden = false
        self.signedOutView.hidden = true
    }
    
    func resetView() {
        // set our version string
        self.versionLabel.text = "CopperKit Version \(CopperKitVersion)"
        // reset our signed in state
        self.avatarImageView.image = nil
        self.nameLabel.text = ""
        self.emailLabel.text = ""
        self.phoneLabel.text = ""
        self.userIdLabel.text = ""
        // flip our state to the signed out state
        self.signedInView.hidden = true
        self.signedOutView.hidden = false
    }
    
    @IBAction func signoutButtonPressed(sender: AnyObject) {
        copper?.closeSession()
        resetView()
    }
    
    @IBAction func showOptionsMenu() {
        let alertController = UIAlertController(title: "Which Scopes?", message: nil, preferredStyle: .ActionSheet)
        let defaultScopesAction = UIAlertAction(title: "Default scopes", style: .Default) { (action) in
            self.desiredScopes = ViewController.DefaultScopes 
        }
        alertController.addAction(defaultScopesAction)
        let verificationOnlyAction = UIAlertAction(title: "Verification only", style: .Default) { (action) in
            self.desiredScopes = nil
        }
        alertController.addAction(verificationOnlyAction)
        self.presentViewController(alertController, animated: true) {
            // no op
        }
    }

}

