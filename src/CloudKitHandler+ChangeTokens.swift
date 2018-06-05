//
//  CloudKitHandler+ChangeTokens.swift
//  Lychee
//
//  Created by Ryan McGrath on 5/5/18.
//  Copyright © 2018 Ryan McGrath. All rights reserved.
//

/**
 *  This extension handles converting and archiving CKServerChangeToken(s) as necessary.
 *  Store them (securely) in NSUserDefaults as the easiest way, ensures extensions can grab
 *  them as well.
 */
extension CloudKitHandler {
    public var changeToken: CKServerChangeToken? {
        get {
            if(backingPreviousChangeToken == nil) {
                guard let defaults: UserDefaults = UserDefaults(suiteName: RYMC_APP_GROUP_ID) else { return nil }
                guard let data: Data = defaults.data(forKey: RYMC_CK_PREVIOUS_SERVER_CHANGE_TOKEN) else { return nil }
                let unarchiver: NSKeyedUnarchiver = NSKeyedUnarchiver(forReadingWith: data)
                unarchiver.requiresSecureCoding = true
                backingPreviousChangeToken = CKServerChangeToken(coder: unarchiver)
            }
            
            return backingPreviousChangeToken
        }

        set(value) {
            backingPreviousChangeToken = value
            guard let value = value else { return }
            guard let defaults: UserDefaults = UserDefaults(suiteName: RYMC_APP_GROUP_ID) else { return }

            let data: NSMutableData = NSMutableData()
            let archiver: NSKeyedArchiver = NSKeyedArchiver(forWritingWith: data)
            archiver.requiresSecureCoding = true
            value.encode(with: archiver)
            archiver.finishEncoding()
            defaults.setValue(data, forKey: RYMC_CK_PREVIOUS_SERVER_CHANGE_TOKEN)
            // defaults.synchronize() -- not necessary in 99% of cases.
        }
    }
}
