# iOS with Copper

## CopperKit for iOS - Getting Started

The CopperKit framework (download the latest)[https://….] allows your iOS app to register or authenticate a person with only a few lines of code. You configure CopperKit to ask the person to share specific information with your app, and with their approval we return that to your runtime. It saves you the development work required to build sign up, sign in, password recovery infrastructure and within your app.

Copper remembers a person’s information so that signups within your app can be a single tap, rather than the person reentering their information.  Plus users love how Copper uses their phone number for authentication so they never see a password. You can expect more people will sign up for your app rather than abandon it at this critical step with Copper.

You can use Copper in your iOS app in four steps:

1. Register your app for free on Copperworks
2. Add the CopperKit Framework to your Xcode Project
3. Update your app to accept incoming callbacks
4. Authenticate and access user information

We walk through each of these in detail below.


### Sample project
We reference code and screenshots from [this working CopperKit example project](https://github.com/withcopper/copperkit-sample) throughout this documentation.


## 1. Register your app for free on Copperworks

You will need to register your app for free on our developer site [Copperworks](https://withcopper.com/copperworks)

Configure the app's settings and branding as desired.

Leave this site open as you will need both your application's id and iOS URL Scheme within.

[_**TBD Screenshot of Copperworks**_]

## 2. Add CopperKit to your Xcode Project

Add CopperKit to your Xcode project, and configure it within the project settings.

#### A. Download the latest version of CopperKit 

* Swift 1.2: [https://…]

#### B. Import `CopperKit.framework` into your project

Drag `CopperKit.framework` into the Project Navigator for your Xcode project.

![Import CopperKit to Xcode](https://raw.githubusercontent.com/withcopper/copperkit-example/master/assets/copperkit-to-xcode.gif)

When prompted, ensure `Copy items if needed` is selected and your `target` is selected like so:

![Import copy settings](https://raw.githubusercontent.com/withcopper/copperkit-example/master/assets/copy-items-if-needed.png)

Your final directory structure should look similar to ours:

![Project directory structure after import](https://raw.githubusercontent.com/withcopper/copperkit-example/master/assets/project-directory-after-import.png)

Go to your Project's Settings and ensure that `CopperKit.framework` is included in:

  - General → Embedded Libraries
  - General → Linked Libraries and Frameworks
  - Build Phases → Link Binary with Libraries
  - Build Phases → Embed Frameworks

Here is how you do that:

![Project directory structure after import](https://raw.githubusercontent.com/withcopper/copperkit-example/master/assets/import-build-settings.gif)


## 3. Update your App Delegate to accept incoming callbacks

CopperKit uses a custom iOS URL scheme within your app to securely signal to your app when a user successfully completes a login.

### A. Create the custom URL scheme for your app

In your application’s `info.plist` file create a new entry for the Custom URL Scheme structured exactly like the example below. You may need to create new entries with the `+` button to create and format the tree as required.

The value of `URL identifier` should be something something custom and unique, like your application’s bundle id.

The value of `URL Schemes`, the Item 0 array should equal the iOS URL Scheme value copied from Copperworks in Step 1.

![Adding Custom URLs to the info.plist file](https://raw.githubusercontent.com/withcopper/copperkit-example/master/assets/infoplist-custom-url.png)

### B. Add the CopperKit import statement
Import CopperKit in your App Delegate

**Swift**

```
#import CopperKit
```

**Objective-C**

```
#import <CopperKit/CopperKit.h>
```

### C. Update your App Delegate’s `openURL` method to check for incoming Copper URLs
The `C29Application.openURL(url:sourceApplication:)` method will inspect an incoming `url` and `sourceApplication` value to determine if this is an incoming request from a Copper request.

This method will return `true` if it is, and signal the remainder of the authentication process to continue within your app.

**Swift**

```
func application(application: UIApplication, openURL url: NSURL, sourceApplication: String?, annotation: AnyObject) -> Bool {
	return C29Application.sharedInstance.openURL(url, sourceApplication: sourceApplication)
}
```

**Objective-C**

```
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
	return [[C29Application sharedInstance] openURL:url sourceApplication:sourceApplication];
}
```

## 4. Authenticate and access user information

The final step is to call `open(_ viewController:scopes:completion:)` function from a view controller at the appropriate time to prompt the user for his or her information.

### A. Add the CopperKit import statement

Import CopperKit in your calling view controller class

**Swift**

```
#import CopperKit
```

**Objective-C**

```
#import <CopperKit/CopperKit.h>
```

### B. Configure CopperKit and call open(_ viewController:scopes:completion:)
You can call the open method directly in your view controller's viewDidLoad method, in response to a user action such as a button press, or programmatically from within your app.

**Swift**

```
	// get a reference to our CopperKit application instance
    copper = C29Application.sharedInstance
    // TODO: configure this with your app id
    copper.configure(withApplicationId: "[YOUR_APPLICATION_ID]")
    // optionally request a non-default set of scopes like this:
    // let scopes = [C29Scope.Name, C29Scope.Avatar, C29Scope.Email, C29Scope.Phone]
    // make the call to ask the user =
    copper.open(withViewController: self, scopes: scopes, completion: { (userInfo: C29UserInfo?, error: NSError?) in
        // Look for an handle errors
        guard error == nil else {
            print("Bummer: \(error)")
            return
        }
        // Or for user cancellation, i.e. if userInfo is nil
        guard let userInfo = userInfo else {
            print("The user cancelled without continuing ...")
            return
        }
        // if we get here then the user completed successfully
        let userId = userInfo.userId
        let name = userInfo.fullName
     	
        // ... the rest is up to you
    })

```

**Objective-C**

```
    - (void)viewDidLoad {
      [super viewDidLoad];
    // TBD
    }
```

[TBD GIF of the login in action]

At this point your app should compile, and CopperKit should be fully functional within your app.

## C29Scope 
User Information available with CopperKit. 

A successful call to  `open(_ viewController:scopes:completion:)`  returns an instance of a `C29UserInfo`  object which holds the user data requested. You can customize the information requested by including the optional the `scopes`  parameter in this call. Below is the complete list of valid scopes. 

See the corresponding entries in [`C29UserInfo`](#c29userinfo) to understand what data is returned back with each scope.

### User Id

Copper always returns a application-unique User Id with a successful call to `open(_ viewController:scopes:completion:)` . Copper will always return the same User Id for the same application so that you can identify the same user across different sessions or devices. You do not need to specify this scope as this value is always returned. Copper will never return the same Id for a different user or the same user on a different application.

### Address

`C29Scope.Address`

### Avatar

`C29Scope.Avatar` 

### Email

`C29Scope.Email` 

### Name

`C29Scope.Name` 

### Phone

`C29Scope.Phone` 


### Username

`C29Scope.Username` 

### All

You can inspect C29Scope.All for a complete list available scopes.


# CopperKit Objects

## C29Application

### `closeSession()`
Calling this method will end the current session and clear any user information from the local C29Application instance. This will not delete or sign the user out of your application with the Copper network. Use this when you want to sign a user out locally, for example to allow another user to sign in, without revoking access to their account for a later date.

Declaration

```
func closeSession()
```

--

### `configure(_ applicationId:String) {`
Configure and initialize CopperKit with your application’s id. **You must call this before calling `open(_ viewController:scopes:completion:)`**.

Parameters

> `token: String` - your applications OAuth token from Copperworks

Declaration

```
func configure(withApplicationId applicationId: String)
```

--

### `getPermittedScopes()`
Get an array of the [`C29Scope`](#c29scope) items your app is permitted to access. You must have an active session for this to return 

Declaration

```
func getPermittedScopes() -> [C29Scope]?
```

Returned values

> `[C29Scope]?` : an array of permitted scopes. This will be `nil` if the session is not active, for example if you call this before `open(_ viewController:scopes:completion:)`.

--

### `open(_ viewController:scopes:completion:)`
Authenticate and request information from a user. This will use a local copy of the user’s information if present, relying on a network call if necessary. If the user’s session is active, and all requested information present on the device, the callback will return successfully without the modal appearing.

Parameters
> `viewController: UIViewController` - the view controller presenting the CopperKit modal
scopes: [[C29Scope](#c29scope)] - array of scopes to request from the user

> `completion: (userInfo: C29UserInfo?, error: NSError?)` - results callback with returned information or error
```

Declaration

```
func open(withViewController viewController: UIViewController, scopes: [C29Scope], completion: C29ApplicationUserInfoCompletionHandler)
```
 
Discussion on the completion callback

> After the user completes or dismisses the CopperKit modal, the complete block will execute returning the `userInfo:C29UserInfo?` object and/or the `error:NSError?` object. You should inspect these objects to determine what action the user took.
    
> When the user dismisses the modal, for example pressing 'Done' to close the modal, both objects will be equal to `nil`.
    
> `error: NSError?`
> You should inspect the error object. If it does not equal `nil` the there was an error, such as network connectivity, preventing the request from completing successfully. Your app should handle error cases gracefully for the person behind the screen. 

> `userInfo: C29UserInfo?`
> If userInfo does not equal `nil` then you can assume the call to open was successful and all information you requested is within. See the related documetation on the C29UserInfo object for more information on it's variables and methods.

--
 
### `openURL(url:sourceApplication)`
This method is used the App Delegate’s openURL method, in conjunction with our applications Custom URL Scheme to allow the CopperKit dialog.
 
Parameters

> `url: NSURL` — the url passed to the App Delegate
> `sourceApplication: String?` — the source applicatoin passed to the App Delegate
 
Declaration

```
func openURL(url: NSURL, sourceApplication: String?) -> Bool
```
 
Returned Values

> `Bool` indicating if the call was a response to an active call to `open(_ viewController:scopes:completion:)`.

--

### `sharedInstance: C29Application`
A singleton representing the root C29Application object for all CopperKit usage. Your app should hold a reference to this to make calls to methods such as `open(_ viewController:scopes:completion:)` .
 
Declaration

```
var sharedInstance: C29Application { get }
```

--

### `scopes: [C29Scope]`
Set or reset this variable before calling `open(_ viewController:scopes:completion:)` to configure the list of scopes that you would like to request with your call. 

The default value for this is equal to C29Scope.DefaultScopes



## C29UserInfo

A successful call to `open(_ viewController:scopes:completion:)` returns an instance of the `C29UserInfo` object containing the requested user information. Values for any scopes that were not requested will be nil.

### `isVerified(scope: C29Scope)`
Determine if Copper has verified that the scope's information has been verified, for example, phone numbers by text and emails by link.

Declaration

```
func isVerified(scope: C29Scope) -> Bool
```

Returned Values

> `Bool` returns true if the scope is permitted and it has been verified

--

### User Id
An application-unique userId will always be returned. This userId will be consistent across different sessions of the same user for your application.

```
var userId: String! { get }
```

### Address
A street address for the user. Requested with [`C29Scope.Address`](#c29scope).

```
var streetOne: String? { get }
```

```
var streetTwo: String? { get }
```

```
var city: String? { get }
```

```
var state: String? { get }
```

```
var zip: String? { get }
```

```
var country: String? { get }
```

### Avatar
An image selected by the user as his or her picture. `avatar` and `avatarURL` are guaranteed to be non-nil. Requested with [`C29Scope.Avatar`](#c29scope).

```
var avatar: UIImage? { get }
```

```
var avatarURL: NSURL? { get }   
```

### Email
Email address for the user. `emailAddress`  is guaranteed to be non-nil. Requested with [`C29Scope.Email`](#c29scope). 
    
```
var emailAddress: String? { get }
```

### Name
A name for the user. `firstName` and `lastName` are guaranteed to be non-nil. `fullName` 
is a convenience concatenation of `firstName`  and `lastName`, if present. `initials` will return the first and last name initials in uppercase letters, if present. Requested with [`C29Scope.Name`](#c29scope).

```
var firstName: String? { get }
```
```
var lastName: String? { get }
```
```
var fullName: String? { get } 
```
```
var initials: String? { get }
```

### Phone
A phone number for the user. `phoneNumber` is guaranteed to be non-nil when requested, and will be in E.164 format (e.g. +14158309190). Requested with [`C29Scope.Phone`](#c29scope). 

```
var phoneNumber: String? { get }
```
    
### Username
The username provided by the user. `username`  is guaranteed to be non-nil when requested. Requested with [`C29Scope.Username`](#c29scope).

```
var username: String? { get }
```