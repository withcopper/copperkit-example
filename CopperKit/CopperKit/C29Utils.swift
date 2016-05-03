//
//  C29Utils
//  Copper
//
//  Created by Doug Williams on 10/21/15.
//  Copyright © 2015 Copper Technologies, Inc. All rights reserved.
//

import Foundation
import CoreTelephony

public typealias C29SuccessCallback = (success: Bool)->()

public class C29Utils {

    // Generate a random GUID
    public class func getGUID() -> String {
        return NSUUID().UUIDString.stringByReplacingOccurrencesOfString("-", withString: "", options: NSStringCompareOptions.LiteralSearch, range: nil)
    }
    
    // Get the ISO country code (e.g. "US") for the device
    internal  class func getPhoneCountryCode(asNumber: Bool = false) -> String? {
        // this is an optional import so let's test for it before committing to it below
        guard objc_getClass("CTTelephonyNetworkInfo") != nil else {
            return nil
        }
        let networkInfo: CTTelephonyNetworkInfo = CTTelephonyNetworkInfo()
        if let carrier : CTCarrier = networkInfo.subscriberCellularProvider {
            return carrier.isoCountryCode!.uppercaseString
        }
        return String?()
    }
    
    internal static var CopperURLs: [String] = ["withcopper.com", "open.withcopper.com", "open-staging.withcopper.com", "api-staging.withcopper.com", "www-staging.withcopper.com", "download.withcopper.com"]

}