//
//  CloudKitHandler+Realm.swift
//  Lychee
//
//  Created by Ryan McGrath on 5/12/18.
//  Copyright © 2018 Ryan McGrath. All rights reserved.
//

private var messagesNotificationToken: RLMNotificationToken?

extension CloudKitHandler {
    func startMonitoringDatabase() {
        messagesNotificationToken = ChatMessage.allObjects().addNotificationBlock { [unowned self] (results: RLMResults?, change: RLMCollectionChange?, err: Error?) in
            
        }
    }
    
    func endMonitoringDatabase() {
        messagesNotificationToken?.invalidate()
    }
}
