//
//  CloudKitHandler.swift
//  Lychee
//
//  Created by Ryan McGrath on 5/3/18.
//  Copyright © 2018 Ryan McGrath. All rights reserved.
//

/**
 *  CloudKitHandler
 *
 *  Handles communicating with CloudKit and the associated APIs. The CloudKit APIs can be a bit
 *  unwieldy and verbose, so this library aims to work around those limitations and streamline
 *  everything.
 */
class CloudKitHandler {
    static let shared = CloudKitHandler()
    
    var isConfiguring: Bool = true
    var isSyncing: Bool = false
    let errorHandler: CloudKitErrorHandler = CloudKitErrorHandler()
    
    var accountStatus: CKAccountStatus = .noAccount
    var container: CKContainer = CKContainer(identifier: RYMC_CLOUDKIT_CONTAINER_ID)
    var userRecordID: String?

    var pendingInvites: [URL] = []
    var pendingMetadatas: [CKShareMetadata] = []
    private var operationQueue: OperationQueue = OperationQueue()
    private var queuedOperations: [CKOperation] = []
    
    // Internal
    var backingPreviousChangeToken: CKServerChangeToken?
    var backingRootRecord: CKRecord?

    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(onAccountChanged), name: NSNotification.Name.CKAccountChanged, object: nil)
    }
    
    @objc func onAccountChanged() {
        isConfiguring = true
        isSyncing = false
        determineAccountStatus()
    }

    public func determineAccountStatus() {
        container.accountStatus { [unowned self] (status: CKAccountStatus, error: Error?) in
            if(error != nil) {
                print("Error retrieving account status \(String(describing: error))")
                self.finishConfiguration(successful: false)
                return
            }
            
            if(status != CKAccountStatus.available) {
                // error
                self.finishConfiguration(successful: false)
                return
            }
            
            self.container.fetchUserRecordID(completionHandler: { (recordID: CKRecordID?, err: Error?) in
                guard let recordID = recordID else {
                    self.finishConfiguration(successful: false)
                    return
                }
                
                print("User record ID: \(String(describing: recordID.recordName))")
                self.userRecordID = recordID.recordName
                self.accountStatus = status
                self.configure()
            })
        }
    }
    
    func configure() {
        let createZone: CKModifyRecordZonesOperation = createPrivateZoneOperation()
        let fetchZones: CKFetchRecordZonesOperation = fetchPrivateZonesOperation(cancelIfExistsAlready: [createZone])
        createZone.addDependency(fetchZones)

        let createPrivateSub: CKModifySubscriptionsOperation = createSubscriptionOperation(.private)
        let fetchPrivateSub: CKFetchSubscriptionsOperation = fetchSubscriptionsOperation(.private, cancelIfExistsAlready: [createPrivateSub])
        fetchPrivateSub.addDependency(createZone)
        createPrivateSub.addDependency(fetchPrivateSub)
        
        let createSharedSub: CKModifySubscriptionsOperation = createSubscriptionOperation(.shared)
        let fetchSharedSub: CKFetchSubscriptionsOperation = fetchSubscriptionsOperation(.shared, cancelIfExistsAlready: [createSharedSub])
        fetchSharedSub.addDependency(createZone)
        createSharedSub.addDependency(fetchSharedSub)

        let createRootRecord: CKModifyRecordsOperation = createRootRecordOperation()
        let fetchRootRecord: CKFetchRecordsOperation = fetchRootRecordOperation(cancelIfExistsAlready: [createRootRecord])
        fetchRootRecord.addDependency(createZone)
        createRootRecord.addDependency(fetchRootRecord)

        let complete: BlockOperation = BlockOperation(block: { [unowned self] in
            self.finishConfiguration()
        })
        complete.addDependency(createRootRecord)

        operationQueue.addOperations([
            fetchZones, createZone,
            fetchPrivateSub, createPrivateSub,
            fetchSharedSub, createSharedSub,
            fetchRootRecord, createRootRecord,
            complete
        ], waitUntilFinished: false)
    }
    
    func finishConfiguration(successful: Bool = true) {
        isConfiguring = false
        operationQueue.addOperations(queuedOperations, waitUntilFinished: false)
        queuedOperations.removeAll()
    }
    
    func addOperations(_ operations: [CKOperation]) {
        if(isConfiguring) {
            queuedOperations.append(contentsOf: operations)
        } else {
            operationQueue.addOperations(operations, waitUntilFinished: false)
        }
    }
    
    func stopAllOperations() {
        for operation: Operation in operationQueue.operations.reversed() {
            operation.cancel()
        }
    }
}
