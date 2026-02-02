# Contacts Integration Research

**Status:** Complete
**Priority:** High
**Last Updated:** February 2, 2026

---

## Overview

Contacts is fundamental to a personal assistant—it enables addressing people by name rather than phone numbers/emails, and provides context about relationships.

## User Value

| Capability | User Benefit |
|------------|--------------|
| Name resolution | "Text John" → finds John's number |
| Contact lookup | "What's Sarah's email?" |
| Add contacts | "Add this person to my contacts" |
| Update contacts | "Update Mike's phone number" |
| Relationship context | Know who's family, work, etc. |

---

## Technical Approach: Contacts Framework

The Contacts framework (`CNContactStore`) is Apple's modern API, replacing the deprecated Address Book framework.

### Platform Support

| Platform | Support |
|----------|---------|
| macOS | 10.11+ |
| iOS | 9.0+ |
| watchOS | 2.0+ |

### Key Classes

| Class | Purpose |
|-------|---------|
| `CNContactStore` | Central access to contacts database |
| `CNContact` | A single contact record |
| `CNMutableContact` | Editable contact |
| `CNContactFetchRequest` | Query for contacts |
| `CNSaveRequest` | Batch save operations |
| `CNGroup` | Contact groups |

---

## Implementation

### Authorization

```swift
import Contacts

class ContactsService {
    private let store = CNContactStore()

    func requestAccess() async -> Bool {
        do {
            return try await store.requestAccess(for: .contacts)
        } catch {
            print("Contacts access error: \(error)")
            return false
        }
    }

    func checkAuthorizationStatus() -> CNAuthorizationStatus {
        return CNContactStore.authorizationStatus(for: .contacts)
    }
}
```

### Fetching Contacts

```swift
func searchContacts(name: String) throws -> [CNContact] {
    let predicate = CNContact.predicateForContacts(matchingName: name)
    let keysToFetch: [CNKeyDescriptor] = [
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactEmailAddressesKey as CNKeyDescriptor,
        CNContactImageDataKey as CNKeyDescriptor
    ]

    return try store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
}

func getAllContacts() throws -> [CNContact] {
    let keysToFetch: [CNKeyDescriptor] = [
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactEmailAddressesKey as CNKeyDescriptor
    ]

    var contacts: [CNContact] = []
    let request = CNContactFetchRequest(keysToFetch: keysToFetch)

    try store.enumerateContacts(with: request) { contact, _ in
        contacts.append(contact)
    }

    return contacts
}

func getContact(identifier: String) throws -> CNContact? {
    let keysToFetch: [CNKeyDescriptor] = [
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactEmailAddressesKey as CNKeyDescriptor,
        CNContactPostalAddressesKey as CNKeyDescriptor,
        CNContactBirthdayKey as CNKeyDescriptor,
        CNContactImageDataKey as CNKeyDescriptor,
        CNContactNoteKey as CNKeyDescriptor
    ]

    return try store.unifiedContact(withIdentifier: identifier, keysToFetch: keysToFetch)
}
```

### Creating Contacts

```swift
func createContact(
    firstName: String,
    lastName: String,
    phoneNumber: String? = nil,
    email: String? = nil
) throws -> CNContact {

    let contact = CNMutableContact()
    contact.givenName = firstName
    contact.familyName = lastName

    if let phone = phoneNumber {
        let phoneValue = CNPhoneNumber(stringValue: phone)
        contact.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMobile, value: phoneValue)]
    }

    if let emailAddress = email {
        contact.emailAddresses = [CNLabeledValue(label: CNLabelHome, value: emailAddress as NSString)]
    }

    let saveRequest = CNSaveRequest()
    saveRequest.add(contact, toContainerWithIdentifier: nil)
    try store.execute(saveRequest)

    return contact
}
```

### Updating Contacts

```swift
func updateContactPhone(identifier: String, newPhone: String, label: String = CNLabelPhoneNumberMobile) throws {
    guard let contact = try getContact(identifier: identifier) else {
        throw ContactsError.notFound
    }

    let mutableContact = contact.mutableCopy() as! CNMutableContact
    let phoneValue = CNPhoneNumber(stringValue: newPhone)
    mutableContact.phoneNumbers.append(CNLabeledValue(label: label, value: phoneValue))

    let saveRequest = CNSaveRequest()
    saveRequest.update(mutableContact)
    try store.execute(saveRequest)
}

func addPhotoToContact(identifier: String, imageData: Data) throws {
    guard let contact = try getContact(identifier: identifier) else {
        throw ContactsError.notFound
    }

    let mutableContact = contact.mutableCopy() as! CNMutableContact
    mutableContact.imageData = imageData

    let saveRequest = CNSaveRequest()
    saveRequest.update(mutableContact)
    try store.execute(saveRequest)
}
```

### Name Resolution for Messaging

```swift
func resolveRecipient(_ name: String) throws -> (name: String, phone: String)? {
    let contacts = try searchContacts(name: name)

    guard let contact = contacts.first else { return nil }

    // Prefer mobile number
    let mobilePhone = contact.phoneNumbers.first { labeled in
        labeled.label == CNLabelPhoneNumberMobile
    }

    let phone = mobilePhone?.value.stringValue ?? contact.phoneNumbers.first?.value.stringValue

    guard let phoneNumber = phone else { return nil }

    let fullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
    return (fullName, phoneNumber)
}
```

---

## Permissions Required

| Permission | Key | Purpose |
|------------|-----|---------|
| Contacts Access | `NSContactsUsageDescription` | Read/write contacts |

**Info.plist:**
```xml
<key>NSContactsUsageDescription</key>
<string>EmberHearth needs contacts access to help you communicate with people by name.</string>
```

**Entitlements:**
```xml
<key>com.apple.security.personal-information.addressbook</key>
<true/>
```

---

## EmberHearth Integration Design

### Core Use Case: Name Resolution

This is critical for the iMessage interface:

```
User: "Text John about dinner"
EmberHearth: [Looks up "John" in contacts]
    → Found: John Smith (+1-555-123-4567)
    → Sends message to that number
```

### Conversation Examples

**User:** "What's Sarah's phone number?"
**EmberHearth:** "Sarah Johnson's phone numbers:
- Mobile: (555) 123-4567
- Work: (555) 987-6543"

**User:** "Add a contact: Mike Chen, 555-222-3333, mike@email.com"
**EmberHearth:** "I've added Mike Chen to your contacts:
- Phone: (555) 222-3333
- Email: mike@email.com

Would you like to add any additional details?"

**User:** "Update John's work number to 555-999-8888"
**EmberHearth:** "I found John Smith. I'll add this as his work number:
- Work: (555) 999-8888

Confirm this change?"

**User:** [Sends photo via iMessage] "Add this photo to Sarah's contact"
**EmberHearth:** "I've updated Sarah Johnson's contact photo."

### Handling Ambiguity

```swift
func handleAmbiguousName(_ name: String) throws -> ContactResolution {
    let contacts = try searchContacts(name: name)

    switch contacts.count {
    case 0:
        return .notFound
    case 1:
        return .unique(contacts[0])
    default:
        return .ambiguous(contacts)
    }
}

enum ContactResolution {
    case notFound
    case unique(CNContact)
    case ambiguous([CNContact])
}

// Usage in conversation:
// "I found 3 contacts named John:
// 1. John Smith (Mobile: 555-123-4567)
// 2. John Doe (Mobile: 555-234-5678)
// 3. John Wilson (Mobile: 555-345-6789)
// Which John do you mean?"
```

---

## Privacy Considerations

1. **Sensitive Data:** Contacts contain personal information
   - Never log contact details
   - Don't cache unnecessarily
   - Don't send to external services

2. **Authorization Privacy:** Can't determine if access was denied
   - If denied, appears as if no contacts exist
   - Handle gracefully without revealing status

3. **Photo Handling:** Contact photos are sensitive
   - Only access when needed
   - Don't transmit without consent

---

## Limitations

| Limitation | Impact | Workaround |
|------------|--------|------------|
| No relationship data | Can't know "my brother" | Ask user to specify |
| Group membership | Limited access | Use contact notes |
| Linked contacts | May appear as duplicates | Use unified contacts API |
| Sync delays | Changes may take time | Wait for sync |

---

## Implementation Priority

| Feature | Priority | Complexity |
|---------|----------|------------|
| Name → phone resolution | Critical | Low |
| Search contacts | High | Low |
| Get contact details | High | Low |
| Create contact | Medium | Low |
| Update contact | Medium | Low |
| Add photo | Low | Low |
| Handle ambiguity | High | Medium |

---

## Testing Checklist

- [ ] Search by first name
- [ ] Search by last name
- [ ] Search by full name
- [ ] Handle no results
- [ ] Handle multiple matches
- [ ] Create new contact
- [ ] Update existing contact
- [ ] Add phone number
- [ ] Add email
- [ ] Add photo from iMessage
- [ ] Handle permission denied

---

## Resources

- [Contacts Framework Documentation](https://developer.apple.com/documentation/contacts)
- [CNContactStore Documentation](https://developer.apple.com/documentation/contacts/cncontactstore)
- [WWDC 2015: Introducing the Contacts Framework](https://asciiwwdc.com/2015/sessions/223)

---

## Recommendation

**Feasibility: HIGH**

The Contacts framework is essential for EmberHearth—it's what makes "text John" work instead of requiring phone numbers. Benefits:

1. Official Apple API
2. Cross-platform consistency
3. iCloud sync built-in
4. Well-documented

**Implementation Notes:**
- Implement name resolution first (critical for messaging)
- Build disambiguation UI for common names
- Contact photo integration adds nice polish for iMessage
