//
//  CloudKitHandler+Subscriptions.swift
//  Lychee
//
//  Created by Ryan McGrath on 5/3/18.
//  Copyright © 2018 Ryan McGrath. All rights reserved.
//

extension CloudKitHandler {
    func fetchSubscriptionsOperation(_ scope: CKDatabaseScope, cancelIfExistsAlready: [Operation]) -> CKFetchSubscriptionsOperation {
        let operation: CKFetchSubscriptionsOperation = CKFetchSubscriptionsOperation.fetchAllSubscriptionsOperation()
        operation.qualityOfService = .userInitiated
        operation.database = container.database(with: scope)
        operation.fetchSubscriptionCompletionBlock = { (subscriptions: [String: CKSubscription]?, err: Error?) in
            switch self.errorHandler.resultType(with: err) {
                case .success:
                    guard let subscriptions = subscriptions else { return }
                    if(subscriptions[RYMC_CKSUBSCRIPTION_NAME] != nil) {
                        for operation: Operation in cancelIfExistsAlready {
                            operation.cancel()
                        }
                    }
                    return
                
                case .retry, .recoverableError(_, _):
                    self.stopAllOperations()
                    self.errorHandler.retryOperation(after: 30, block: {
                        self.configure()
                    })
                    return
                
                default:
                    return
            }
        }
        
        return operation;
    }
    
    func createSubscriptionOperation(_ scope: CKDatabaseScope) -> CKModifySubscriptionsOperation {
        let operation: CKModifySubscriptionsOperation = CKModifySubscriptionsOperation(subscriptionsToSave: [
            scope == .shared ? sharedDatabaseSubscription() : privateDatabaseSubscription()
        ], subscriptionIDsToDelete: [])
        operation.qualityOfService = .userInitiated
        operation.database = container.database(with: scope)
        operation.modifySubscriptionsCompletionBlock = { (subscriptions: [CKSubscription]?, _, err: Error?) in
            switch self.errorHandler.resultType(with: err) {
                case .retry, .recoverableError(_, _):
                    self.stopAllOperations()
                    self.errorHandler.retryOperation(after: 30, block: {
                        self.configure()
                    })
                    return
                
                default:
                    return
            }
        }
        
        return operation
    }
    
    private final func privateDatabaseSubscription() -> CKSubscription {
        let recordZone: CKRecordZone = defaultRecordZone()
        let subscription: CKRecordZoneSubscription = CKRecordZoneSubscription(zoneID: recordZone.zoneID, subscriptionID: RYMC_CKSUBSCRIPTION_NAME)
        subscription.notificationInfo = notificationInfo("private")
        return subscription
    }
    
    private final func sharedDatabaseSubscription() -> CKDatabaseSubscription {
        let subscription: CKDatabaseSubscription = CKDatabaseSubscription(subscriptionID: RYMC_CKSUBSCRIPTION_NAME)
        subscription.notificationInfo = notificationInfo("shared")
        subscription.notificationInfo?.desiredKeys = []
        return subscription
    }
    
    final func notificationInfo(_ category: String) -> CKNotificationInfo {
        let info: CKNotificationInfo = CKNotificationInfo()
        info.soundName = "default"
        info.shouldSendContentAvailable = true
        info.category = category
        return info
    }
}
