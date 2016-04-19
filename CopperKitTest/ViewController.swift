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
    // Signed In view IB Variables
    @IBOutlet weak var signedInView: UIView!
    @IBOutlet weak var signoutButton: UIButton!
    @IBOutlet weak var avatarImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var phoneLabel: UILabel!
    @IBOutlet weak var userIdLabel: UILabel!
    // Reference to our CopperKit singleton
    var copper: C29Application?
    
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
        copper!.configureForApplication("56FC63513259B250EC174C72B35697EB7C38B7B0")
        // Optionally, decide what information we want from the user, defaults to C29Scope.DefaultScopes = [C29Scope.Name, C29Scope.Avatar, C29Scope.Phone]
        copper!.scopes = [C29Scope.Name, C29Scope.Avatar, C29Scope.Email, C29Scope.Phone]
        // OK, let's make our call
        copper!.open(withViewController: self, completion: { (result: C29UserInfoResult) in
            switch result {
            case let .Failure(error):
                print("Bummer: \(error)")
            case .UserCancelled:
                print("The user cancelled.")
            case let .Success(userInfo):
                self.setupViewWithUserInfo(userInfo)
            }
        })
    }

    @IBAction func signoutButtonPressed(sender: AnyObject) {
        copper?.closeSession()
        resetView()
    }
    
    func setupViewWithUserInfo(userInfo: C29UserInfo) {
        self.avatarImageView.image = userInfo.avatar
        self.nameLabel.text = userInfo.fullName
        self.emailLabel.text = userInfo.emailAddress
        self.phoneLabel.text = userInfo.phoneNumber
        self.userIdLabel.text = userInfo.userId
        // flip our signout state
        self.signedInView.hidden = false
        self.signedOutView.hidden = true
    }
    
    func resetView() {
        self.avatarImageView.image = nil
        self.nameLabel.text = ""
        self.emailLabel.text = ""
        self.phoneLabel.text = ""
        self.userIdLabel.text = ""
        // flip our state
        self.signedInView.hidden = true
        self.signedOutView.hidden = false
    }
}

