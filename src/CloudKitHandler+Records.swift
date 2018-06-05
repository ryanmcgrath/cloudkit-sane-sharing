//
//  CloudKitHandler+Records.swift
//  Lychee
//
//  Created by Ryan McGrath on 5/8/18.
//  Copyright © 2018 Ryan McGrath. All rights reserved.
//

extension CloudKitHandler {
    func rootRecordID() -> CKRecordID {
        return CKRecordID(recordName: "Profile", zoneID: defaultRecordZone().zoneID)
    }

    public var rootRecord: CKRecord? {
        get {
            if(backingRootRecord == nil) {
                backingRootRecord = CKRecord(recordType: "Profile", recordID: rootRecordID())
            }
            
            return backingRootRecord
        }

        set(value) { backingRootRecord = value }
    }
    
    func fetchRootRecordOperation(cancelIfExistsAlready: [Operation]) -> CKFetchRecordsOperation {
        let recordID: CKRecordID = rootRecordID()
        let operation: CKFetchRecordsOperation = CKFetchRecordsOperation(recordIDs: [recordID])
        operation.qualityOfService = .userInitiated
        operation.database = container.privateCloudDatabase
        
        operation.fetchRecordsCompletionBlock = { [unowned self] (records: [CKRecordID: CKRecord]?, err: Error?) in
            switch self.errorHandler.resultType(with: err) {
                case .success:
                    if(records != nil && records?[recordID] != nil) {
                        self.rootRecord = records![recordID]!
                        for operation: Operation in cancelIfExistsAlready { operation.cancel() }
                    }
                    return

                case .retry:
                    self.stopAllOperations()
                    self.errorHandler.retryOperation(after: 30, block: {
                        self.configure()
                    })
                    return
                
                case .recoverableError(let reason, _):
                    // This is an oddity of CloudKit, but should be handled. It's complaining that the
                    // record doesn't exist. In our case, we want to just move right along.
                    if(reason == CloudKitErrorHandler.CKOperationFailReason.partialFailure) {
                        return
                    }
                    
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
    
    func createRootRecordOperation() -> CKModifyRecordsOperation {
        let operation: CKModifyRecordsOperation = CKModifyRecordsOperation(recordsToSave: [rootRecord!], recordIDsToDelete: nil)
        operation.qualityOfService = .userInitiated
        operation.database = container.privateCloudDatabase
        operation.modifyRecordsCompletionBlock = { [unowned self] (records: [CKRecord]?, _, err: Error?) in
            switch self.errorHandler.resultType(with: err) {
                case .success:
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
        
        return operation
    }

    typealias modifyRecordsCompleteBlock = ([CKRecord]?, [CKRecordID]?, Error?) -> Void

    public func modifyRecordsOperation(save: [CKRecord]?, delete: [CKRecordID]?, _ complete: @escaping modifyRecordsCompleteBlock) -> CKModifyRecordsOperation {
        let operation: CKModifyRecordsOperation = CKModifyRecordsOperation(recordsToSave: save, recordIDsToDelete: delete)
        operation.qualityOfService = .userInitiated
        operation.database = container.privateCloudDatabase
        operation.modifyRecordsCompletionBlock = complete
        return operation
    }
}
