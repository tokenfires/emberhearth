import Foundation
import os.log

/// Filters incoming messages to only respond to configured phone numbers.
///
/// EmberHearth only responds to messages from phone numbers that the user has
/// explicitly added to the allowed list during onboarding. This prevents the
/// assistant from responding to unknown contacts.
///
/// Phone numbers are normalized to E.164 format before storage and comparison.
/// E.164 format: `+` followed by country code and subscriber number, with no
/// spaces, dashes, or parentheses. Example: `+15551234567`.
///
/// This class is thread-safe. All mutations to the allowed set are serialized
/// on an internal queue.
///
/// ## Usage
/// ```swift
/// let filter = PhoneNumberFilter()
/// filter.addAllowedNumber("(555) 123-4567")  // Stored as +15551234567
///
/// filter.shouldRespond(to: "+15551234567")     // true
/// filter.shouldRespond(to: "+15559999999")     // false
/// ```
final class PhoneNumberFilter {

    // MARK: - Properties

    /// The UserDefaults key for persisting allowed phone numbers.
    static let allowedNumbersKey = "com.emberhearth.phonenumberfilter.allowedNumbers"

    /// Logger for phone number filtering operations.
    private let logger = Logger(subsystem: "com.emberhearth.core", category: "PhoneNumberFilter")

    /// Serial queue protecting all reads/writes to `_allowedNumbers`.
    private let queue = DispatchQueue(label: "com.emberhearth.phonenumberfilter")

    /// The backing store for allowed phone numbers in E.164 format.
    /// Access only via `queue` to guarantee thread safety.
    private var _allowedNumbers: Set<String>

    // MARK: - Initialization

    /// Creates a new PhoneNumberFilter, loading any previously saved allowed numbers.
    ///
    /// Persisted numbers are re-validated on load; any that no longer pass E.164
    /// validation are silently discarded.
    init() {
        if let saved = UserDefaults.standard.stringArray(forKey: Self.allowedNumbersKey) {
            self._allowedNumbers = Set(saved.filter { Self.isValidE164($0) })
        } else {
            self._allowedNumbers = Set()
        }
    }

    // MARK: - Filtering

    /// Determines whether EmberHearth should respond to a message from this phone number.
    ///
    /// The phone number is normalized to E.164 before comparison. If normalization
    /// fails (invalid format), returns false.
    ///
    /// - Parameter phoneNumber: The phone number to check, in any supported format.
    /// - Returns: True if the number is in the allowed list.
    func shouldRespond(to phoneNumber: String) -> Bool {
        guard let normalized = Self.normalize(phoneNumber) else {
            logger.debug("Cannot normalize phone number, rejecting: \(phoneNumber, privacy: .private)")
            return false
        }
        let result = queue.sync { _allowedNumbers.contains(normalized) }
        logger.debug("shouldRespond(to: \(phoneNumber, privacy: .private)) = \(result)")
        return result
    }

    // MARK: - Managing Allowed Numbers

    /// Adds a phone number to the allowed list.
    ///
    /// The number is normalized to E.164 format before storing. If the number
    /// cannot be normalized, it is not added and the method returns false.
    ///
    /// - Parameter number: The phone number in any supported format.
    /// - Returns: True if the number was successfully added (or already present).
    @discardableResult
    func addAllowedNumber(_ number: String) -> Bool {
        guard let normalized = Self.normalize(number) else {
            logger.warning("Cannot add invalid phone number: \(number, privacy: .private)")
            return false
        }
        queue.sync {
            _allowedNumbers.insert(normalized)
            persistAllowedNumbers()
        }
        logger.info("Added allowed number: \(normalized, privacy: .private)")
        return true
    }

    /// Removes a phone number from the allowed list.
    ///
    /// The number is normalized to E.164 format before removal.
    ///
    /// - Parameter number: The phone number in any supported format.
    /// - Returns: True if the number was found and removed.
    @discardableResult
    func removeAllowedNumber(_ number: String) -> Bool {
        guard let normalized = Self.normalize(number) else {
            logger.warning("Cannot remove invalid phone number: \(number, privacy: .private)")
            return false
        }
        let removed = queue.sync { () -> Bool in
            let result = _allowedNumbers.remove(normalized) != nil
            if result { persistAllowedNumbers() }
            return result
        }
        if removed {
            logger.info("Removed allowed number: \(normalized, privacy: .private)")
        }
        return removed
    }

    /// Returns all currently allowed phone numbers in E.164 format.
    ///
    /// - Returns: An array of E.164 phone numbers, sorted ascending.
    func getAllowedNumbers() -> [String] {
        return queue.sync { Array(_allowedNumbers).sorted() }
    }

    /// Removes all allowed phone numbers.
    func removeAllAllowedNumbers() {
        queue.sync {
            _allowedNumbers.removeAll()
            persistAllowedNumbers()
        }
        logger.info("Removed all allowed numbers")
    }

    /// Returns the number of allowed phone numbers.
    var allowedNumberCount: Int {
        return queue.sync { _allowedNumbers.count }
    }

    // MARK: - Persistence

    /// Writes the current allowed set to UserDefaults.
    /// Must be called from `queue`.
    private func persistAllowedNumbers() {
        let array = Array(_allowedNumbers)
        UserDefaults.standard.set(array, forKey: Self.allowedNumbersKey)
        logger.info("Allowed numbers updated. Count: \(self._allowedNumbers.count)")
    }

    // MARK: - Phone Number Normalization

    /// Characters that commonly appear as extension delimiters in phone numbers.
    private static let extensionDelimiters: CharacterSet = {
        var set = CharacterSet()
        set.insert(charactersIn: "xXeE;,#")
        return set
    }()

    /// Normalizes a phone number to E.164 format.
    ///
    /// Handles the following input formats:
    /// - `+15551234567` — Already E.164, returned as-is
    /// - `15551234567` — Missing +, prepend +
    /// - `(555) 123-4567` — US formatted, strip formatting, prepend +1
    /// - `555-123-4567` — Dashed, strip dashes, prepend +1
    /// - `555.123.4567` — Dotted, strip dots, prepend +1
    /// - `5551234567` — 10 digits, assume US (+1)
    ///
    /// Extension suffixes (e.g., "x123", "ext 456", ";789") are stripped before
    /// normalization.
    ///
    /// For non-US numbers, the + and country code must be provided.
    ///
    /// - Parameter phoneNumber: The phone number in any supported format.
    /// - Returns: The phone number in E.164 format, or nil if it cannot be normalized.
    static func normalize(_ phoneNumber: String) -> String? {
        var stripped = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !stripped.isEmpty else { return nil }

        // Strip extension suffixes before processing.
        // Find the first occurrence of an extension delimiter and truncate there.
        if let delimiterRange = stripped.rangeOfCharacter(from: extensionDelimiters) {
            stripped = String(stripped[stripped.startIndex..<delimiterRange.lowerBound])
            stripped = stripped.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !stripped.isEmpty else { return nil }
        }

        let hasLeadingPlus = stripped.hasPrefix("+")

        // Keep only ASCII digits (0-9). This rejects Unicode numeral look-alikes.
        stripped = stripped.filter { $0.isASCII && $0.isNumber }

        guard !stripped.isEmpty else { return nil }

        if hasLeadingPlus {
            let result = "+" + stripped
            return isValidE164(result) ? result : nil
        }

        if stripped.count == 10 {
            let result = "+1" + stripped
            return isValidE164(result) ? result : nil
        } else if stripped.count == 11 && stripped.hasPrefix("1") {
            let result = "+" + stripped
            return isValidE164(result) ? result : nil
        } else if stripped.count >= 7 && stripped.count <= 15 {
            if let first = stripped.first, first != "0" {
                let result = "+" + stripped
                return isValidE164(result) ? result : nil
            }
            return nil
        }

        return nil
    }

    /// Validates that a string is in correct E.164 format.
    ///
    /// E.164: `+` followed by 1–15 digits, first digit 1–9.
    /// Minimum real-world length is enforced at 2 digits (country code + at least
    /// one subscriber digit), matching the ITU-T E.164 recommendation.
    ///
    /// - Parameter number: The number to validate.
    /// - Returns: True if it matches E.164 format.
    static func isValidE164(_ number: String) -> Bool {
        let pattern = #"^\+[1-9]\d{1,14}$"#
        return number.range(of: pattern, options: .regularExpression) != nil
    }
}
