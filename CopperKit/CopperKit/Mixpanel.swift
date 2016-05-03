//
//  Mixpanel.swift
//
//
//  Impoorted/modified by Doug Williams on 9/23/2015.
//  Copyright (c) 2015 Sam Soffes. All rights reserved.
//

import Foundation

#if os(iOS)
    import UIKit
    #elseif os(watchOS)
    import WatchKit
    #elseif os(OSX)
    import AppKit
#endif

public typealias MixPanelCompletionHandler = (success: Bool) -> ()
public protocol MixPanelAPI {
    func sendToMixPanelToken(token:String, event:String, properties:NSDictionary, completion:MixPanelCompletionHandler?)
}

public let MixPanelToken = "943eccdb772bb0c2b288e5ae9daa84f1"

/// Simple wrapper for Mixpanel. All requests are sent to the network in the background. If there is no Internet connection, it will silently fail.
public struct Mixpanel: MixPanelAPI {
    
    public mutating func associateToUser(userId: String) {
        self.distinctId = userId
    }
    
    private var distinctId: String?

    // MARK: - Types
    
    public typealias Completion = (success: Bool) -> ()
    
    // MARK: - Properties
    
    /// Easily disable tracking when desired.
    public var enabled: Bool = true
    
    private var token: String
    private var URLSession: NSURLSession
    private let endpoint = "https://api.mixpanel.com/track/"
    
    private var deviceModel: String? {
        var size : Int = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](count: Int(size), repeatedValue: 0)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        return String.fromCString(machine)
    }
    
    private var defaultProperties: [String: AnyObject] {
        var properties: [String: AnyObject] = [
            "$manufacturer": "Apple"
        ]
        
        if let info = NSBundle.mainBundle().infoDictionary {
            if let version = info["CFBundleVersion"] as? String {
                properties["$app_version"] = version
            }
            
            if let shortVersion = info["CFBundleShortVersionString"] as? String {
                properties["$app_release"] = shortVersion
            }
        }
        
        if let deviceModel = deviceModel {
            properties["$model"] = deviceModel
        }
        
        #if os(iOS)
            properties["mp_lib"] = "iphone"
            
            let device = UIDevice.currentDevice()
            properties["$os"] = device.systemName
            properties["$os_version"] = device.systemVersion
            
            let size = UIScreen.mainScreen().bounds.size
            properties["$screen_width"] = UInt(size.width)
            properties["$screen_height"] = UInt(size.height)
            
            #elseif os(watchOS)
            properties["mp_lib"] = "applewatch"
            
            let device = WKInterfaceDevice.currentDevice()
            properties["$os"] = device.systemName
            properties["$os_version"] = device.systemVersion
            
            properties["$screen_width"] = UInt(device.screenBounds.size.width)
            properties["$screen_height"] = UInt(device.screenBounds.size.height)
            #elseif os(OSX)
            properties["mp_lib"] = "mac"
            
            let processInfo = NSProcessInfo()
            properties["$os"] = "Mac OS X"
            properties["$os_version"] = processInfo.operatingSystemVersionString
            
            if let size = NSScreen.mainScreen()?.frame.size {
                properties["$screen_width"] = UInt(size.width)
                properties["$screen_height"] = UInt(size.height)
            }
        #endif
        
        return properties
    }
    
    // MARK: - Initializers
    public init(token: String) {
        self.token = token
        self.URLSession = NSURLSession.sharedSession()
    }
    
    // MARK: - Tracking
    
    public mutating func identify(identifier: String?) {
        distinctId = identifier
    }
    
    public func track(event: String, parameters: [String: AnyObject]? = nil, time: NSDate = NSDate(), completion: MixPanelCompletionHandler? = nil) {
        if !enabled {
            completion?(success: false)
            return
        }
        
        var properties = defaultProperties
        
        if let parameters = parameters {
            for (key, value) in parameters {
                properties[key] = value
            }
        }

        properties["time"] = time.timeIntervalSince1970
        
        if let distinctId = distinctId {
            properties["distinct_id"] = distinctId
        }
        self.sendToMixPanelToken(token, event: event, properties: properties, completion: completion)
    }
    public func sendToMixPanelToken(token:String, event:String, properties:NSDictionary, completion:MixPanelCompletionHandler?){
        let finalProperties = NSMutableDictionary(dictionary: properties)
        finalProperties["token"] = token
        let payload = [
            "event": event,
            "properties": finalProperties
        ]
        do {
            let json = try NSJSONSerialization.dataWithJSONObject(payload, options: [])
            let base64 = json.base64EncodedStringWithOptions([]).stringByReplacingOccurrencesOfString("\n", withString: "")
            if let url = NSURL(string: "\(endpoint)?data=\(base64)&ip=1") {
                CopperNetworkActivityRegistry.sharedRegistry.activityBegan()
                URLSession.dataTaskWithRequest(NSURLRequest(URL: url), completionHandler: { _, res, error in
                    CopperNetworkActivityRegistry.sharedRegistry.activityEnded()
                    if error != nil {
                        completion?(success: false)
                        return
                    }
                    
                    guard let response = res as? NSHTTPURLResponse else {
                        completion?(success: false)
                        return
                    }
                    
                    completion?(success: response.statusCode == 200)
                }).resume()
                return
            }
        } catch {
            // Do nothing
        }
        
        completion?(success: false)
    }
}