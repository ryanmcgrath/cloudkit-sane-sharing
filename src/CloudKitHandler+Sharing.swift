//
//  CloudKitHandler+Sharing.swift
//  Lychee
//
//  Created by Ryan McGrath on 5/8/18.
//  Copyright © 2018 Ryan McGrath. All rights reserved.
//

extension CloudKitHandler {
    public func acceptShares(_ shareMetadatas: [CKShareMetadata]) {
        let operation: CKAcceptSharesOperation = CKAcceptSharesOperation(shareMetadatas: shareMetadatas)
        operation.qualityOfService = .userInitiated

        operation.perShareCompletionBlock = { [unowned self] (shareMetaData: CKShareMetadata, acceptedShare: CKShare?, err: Error?) in
            switch self.errorHandler.resultType(with: err) {
                case .retry, .recoverableError(_, _):
                    self.errorHandler.retryOperation(after: 30, block: {
                        self.acceptShares(shareMetadatas)
                    })
                    return
                
                default:
                    return
            }
        }

        operation.acceptSharesCompletionBlock = { [unowned self] (err: Error?) in
            print("ACCEPTED SHARES!!!!")
            switch self.errorHandler.resultType(with: err) {
                case .retry, .recoverableError(_, _):
                    self.errorHandler.retryOperation(after: 30, block: {
                        self.acceptShares(shareMetadatas)
                    })
                    return
                
                default:
                    return
            }
        }

        addOperations([operation])
    }
    
    typealias shareCompleteBlock = (CKShare?, Error?) -> Void

    // @TODO: This convenience method can be much safer.
    public func shareRootRecord(with users: [ShareableUser], _ complete: @escaping shareCompleteBlock) {
        share(record: rootRecord!, with: users, complete)
    }

    public func share(record: CKRecord, with users: [ShareableUser], _ complete: @escaping shareCompleteBlock) {
        let share: CKShare = CKShare(rootRecord: record)
        share[CKShareTitleKey] = "Lychee" as CKRecordValue
        share[CKShareTypeKey] = "com.rymc.Lychee" as CKRecordValue

        let identities: [CKUserIdentityLookupInfo] = users.map { (user: ShareableUser) -> CKUserIdentityLookupInfo in
            return CKUserIdentityLookupInfo(userRecordID: user.identity.userRecordID!)
        }
        
        let shareOperation: CKFetchShareParticipantsOperation = CKFetchShareParticipantsOperation(userIdentityLookupInfos: identities)
        shareOperation.qualityOfService = .userInitiated
        shareOperation.shareParticipantFetchedBlock = { (participant: CKShareParticipant) in
            participant.permission = .readOnly
            share.addParticipant(participant)
        }

        let saveOperation: CKModifyRecordsOperation = modifyRecordsOperation(save: [record, share], delete: nil) { [unowned self] (savedRecords: [CKRecord]?, deletedRecordIDs: [CKRecordID]?, error: Error?) in
            switch self.errorHandler.resultType(with: error) {
                case .success:
                    DispatchQueue.main.async { complete(share, error) }
                    return
                
                case .retry, .recoverableError(_, _):
                    self.errorHandler.retryOperation(after: 30, block: {
                        self.share(record: record, with: users, complete)
                    })
                    return
                
                default:
                    return
            }
        }

        shareOperation.fetchShareParticipantsCompletionBlock = { [unowned self] (shareOperationError: Error?) in
            switch self.errorHandler.resultType(with: shareOperationError) {
                case .retry, .recoverableError(_, _):
                    saveOperation.cancel()
                    self.errorHandler.retryOperation(after: 30, block: {
                        self.share(record: record, with: users, complete)
                    })
                    return
                
                default:
                    return
            }
        }

        saveOperation.addDependency(shareOperation)
        addOperations([shareOperation, saveOperation])
    }

    public func saveToPublicDatabase(users: [ShareableUser], share: CKShare) {
        let recordID: CKRecordID = CKRecordID(recordName: NSUUID().uuidString)
        let record: CKRecord = CKRecord(recordType: "Share", recordID: recordID)
        record["url"] = share.url?.absoluteString as CKRecordValue?
        record["userID"] = users[0].identity.userRecordID?.recordName as CKRecordValue?
        
        let op: CKModifyRecordsOperation = CKModifyRecordsOperation(recordsToSave: [
            record
        ], recordIDsToDelete: [])
        op.qualityOfService = .userInitiated
        op.database = container.publicCloudDatabase
        
        op.modifyRecordsCompletionBlock = { (_, _, err: Error?) in
            if(err != nil) { print("Error saving share to public DB: \(String(describing: err))") }
        }
        
        addOperations([op])
    }
    
    public func checkForInvitesOperation() -> CKQueryOperation {
        let query: CKQuery = CKQuery(recordType: "Share", predicate: NSPredicate(format: "userID = %@", userRecordID!))
        let op: CKQueryOperation = CKQueryOperation(query: query)
        op.database = container.publicCloudDatabase
        op.recordFetchedBlock = { [unowned self] (record: CKRecord) in
            let url: String = record["url"] as! String
            print("URL: \(url)")
            guard let shareURL = URL(string: url) else { return }
            self.pendingInvites.append(shareURL)
        }
        
        op.queryCompletionBlock = { (_, err: Error?) in
            if(err != nil) { print("Error retrieving urls: \(String(describing: err))") }
            print("COMPLETED?!")
        }
        
        return op
    }
    
    public func fetchShareMetadatas() -> CKFetchShareMetadataOperation {
        print("HERE NOW?!")
        let op: CKFetchShareMetadataOperation = CKFetchShareMetadataOperation(shareURLs: pendingInvites)
        op.qualityOfService = .userInitiated
        op.perShareMetadataBlock = { [unowned self] (url: URL, metadata: CKShareMetadata?, err: Error?) in
            if(err != nil) { print("Error retrieving metadatas: \(String(describing: err))") }
            guard let metadata = metadata else { return }
            print("Metadata: \(String(describing: metadata))")
            self.pendingMetadatas.append(metadata)
        }
        
        op.fetchShareMetadataCompletionBlock = { [unowned self] (err: Error?) in
            self.acceptShares(self.pendingMetadatas)
        }
        
        return op
    }
}
