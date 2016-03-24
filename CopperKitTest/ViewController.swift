//
//  ViewController.swift
//  CopperKitTest
//
//  Created by Doug Williams on 3/15/16.
//  Copyright © 2016 Doug Williams. All rights reserved.
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
        // reset our UI elements to the Signed Out state
        resetView()
    }
    
    @IBAction func signinButtonPressed(sender: AnyObject) {
        // get a reference to our CopperKit application instance
        copper = C29Application.sharedInstance
        // configure it with our app's token
        copper!.configure(withOauthToken: "55F1DD04F89379E9F9394259994155A27C658591")
        // decide what information we want from the user
        let scopes = [C29Scope.Name, C29Scope.Avatar, C29Scope.Email, C29Scope.Phone]
        // make the call to ask the user =
        copper!.open(withViewController: self, scopes: scopes, completion: { (userInfo: C29UserInfo?, error: NSError?) in
            // check for errors
            guard error == nil else {
                print("Bummer: \(error)")
                return
            }
            // or user cancellation, if userInfo is nil
            guard let userInfo = userInfo else {
                print("The user cancelled without continuing...")
                return
            }
            // if we get here then the user completed successfully
            self.setupViewWithUserInfo(userInfo)
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

