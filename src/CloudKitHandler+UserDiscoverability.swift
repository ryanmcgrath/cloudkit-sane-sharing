//
//  CloudKitHandler+UserDiscoverability.swift
//  Lychee
//
//  Created by Ryan McGrath on 5/8/18.
//  Copyright © 2018 Ryan McGrath. All rights reserved.
//

final class ShareableUser: RYMCModel {
    let contact: CNContact
    let identity: CKUserIdentity
    
    init(contact: CNContact, identity: CKUserIdentity) {
        self.contact = contact
        self.identity = identity
    }
}

struct ShareablePermissionsGranted {
    let contacts: Bool
    let discoverability: Bool
}

extension CloudKitHandler {
    typealias discoverUsersCompleteBlock = (ShareablePermissionsGranted, [ShareableUser], Error?) -> Void

    public func discoverUsers(_ complete: @escaping discoverUsersCompleteBlock) {
        let store: CNContactStore = CNContactStore()
        store.requestAccess(for: .contacts) { [unowned self] (granted: Bool, error: Error?) in
            let shareGranted: ShareablePermissionsGranted = ShareablePermissionsGranted(contacts: granted, discoverability: false)
            if(!granted) {
                return complete(shareGranted, [], nil)
            }
            
            if(error != nil) {
                print("Error fetching contacts store: \(String(describing: error))")
                return complete(shareGranted, [], error)
            }

            let contacts: [CNContact] = self.loadContacts(from: store)
            self.container.requestApplicationPermission(.userDiscoverability) { (status: CKApplicationPermissionStatus, statusError: Error?) in
                if(status != .granted) { return complete(shareGranted, [], nil) }

                if(error != nil) {
                    let discoverabilityGranted: ShareablePermissionsGranted = ShareablePermissionsGranted(contacts: true, discoverability: true)
                    print("Error requesting user discoverability application permission: \(String(describing: error))")
                    return complete(discoverabilityGranted, [], statusError)
                }
                
                self.discoverAndMatchUserIdentities(with: contacts, complete)
            }
        }
    }
    
    private func loadContacts(from store: CNContactStore) -> [CNContact] {
        let keys: [CNKeyDescriptor] = [
            CNContactImageDataKey as CNKeyDescriptor,
            CNContactThumbnailImageDataKey as CNKeyDescriptor,
            CNContactImageDataAvailableKey as CNKeyDescriptor,
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName)
        ]

        var containers: [CNContainer] = []
        do { containers = try store.containers(matching: nil) } catch {
            print("Could not find containers for contacts! \(error)")
        }
        
        var contacts: [CNContact] = []
        for container: CNContainer in containers {
            let predicate: NSPredicate = CNContact.predicateForContactsInContainer(withIdentifier: container.identifier)
            do {
                let unifiedContacts: [CNContact] = try store.unifiedContacts(matching: predicate, keysToFetch: keys)
                contacts.append(contentsOf: unifiedContacts)
            } catch {
                print("Error getting unified contacts! \(error)")
            }
        }
        
        return contacts
    }
    
    private func discoverAndMatchUserIdentities(with contacts: [CNContact], _ complete: @escaping discoverUsersCompleteBlock)  {
        let op: CKDiscoverAllUserIdentitiesOperation = CKDiscoverAllUserIdentitiesOperation()
        
        var users: [ShareableUser] = []
        op.userIdentityDiscoveredBlock = { (identity: CKUserIdentity) in
            for contact: CNContact in contacts {
                if(identity.contactIdentifiers.contains(contact.identifier)) {
                    users.append(ShareableUser(contact: contact, identity: identity))
                    break
                }
            }
        }

        op.discoverAllUserIdentitiesCompletionBlock = { (err: Error?) in
            let permissions: ShareablePermissionsGranted = ShareablePermissionsGranted(contacts: true, discoverability: true)
            complete(permissions, users, err)
        }

        container.add(op)
    }
}
