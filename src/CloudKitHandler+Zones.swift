//
//  CloudKitHandler+Zones.swift
//  Lychee
//
//  Created by Ryan McGrath on 5/3/18.
//  Copyright © 2018 Ryan McGrath. All rights reserved.
//

extension CloudKitHandler {
    func defaultRecordZone() -> CKRecordZone {
        return CKRecordZone(zoneName: RYMC_CKZONE_NAME)
    }

    func fetchPrivateZonesOperation(cancelIfExistsAlready: [Operation]) -> CKFetchRecordZonesOperation {
        let recordZone: CKRecordZone = defaultRecordZone()
        let op: CKFetchRecordZonesOperation = CKFetchRecordZonesOperation.fetchAllRecordZonesOperation()
        op.qualityOfService = .userInitiated
        op.database = container.privateCloudDatabase
        op.fetchRecordZonesCompletionBlock = { [unowned self] (z: [CKRecordZoneID: CKRecordZone]?, err: Error?) in
            switch self.errorHandler.resultType(with: err) {
                case .success:
                    if(z != nil && z?[recordZone.zoneID] != nil) {
                        for operation: Operation in cancelIfExistsAlready { operation.cancel() }
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
        
        return op
    }
    
    func createPrivateZoneOperation() -> CKModifyRecordZonesOperation {
        let recordZone: CKRecordZone = defaultRecordZone()
        let op: CKModifyRecordZonesOperation = CKModifyRecordZonesOperation(recordZonesToSave: [recordZone], recordZoneIDsToDelete: nil)
        op.qualityOfService = .userInitiated
        op.database = container.privateCloudDatabase
        op.modifyRecordZonesCompletionBlock = { (_, _, err: Error?) in
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
        
        return op
    }
}
