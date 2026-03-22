// TronPipeline.swift
// EmberHearth
//
// The MVP Tron security pipeline that chains together all security checks.

import Foundation
import os

/// The MVP Tron security pipeline.
///
/// Chains together group chat detection, phone number filtering, injection scanning
/// (inbound), and credential scanning (outbound) into a unified security layer.
///
/// ## Architecture
/// Tron sits between the user and Ember (the LLM personality layer):
/// ```
/// User Message → [Tron Inbound] → Ember/LLM → [Tron Outbound] → Response
/// ```
///
/// ## Key Principle
/// Tron NEVER contacts the user directly. It returns structured results
/// (`InboundResult` / `OutboundResult`) and the caller (MessageCoordinator)
/// decides how to respond.
///
/// ## Thread Safety
/// TronPipeline is designed to be thread-safe. The InjectionScanner and
/// CredentialScanner are both Sendable. The pipeline itself holds no mutable state.
///
/// ## Usage
/// ```swift
/// let pipeline = TronPipeline(config: .default)
///
/// // Inbound: check user message
/// let inbound = pipeline.processInbound(
///     message: "Hello!",
///     phoneNumber: "+15551234567",
///     isGroupChat: false
/// )
///
/// // Outbound: check LLM response
/// let outbound = pipeline.processOutbound(response: llmResponse)
/// ```
final class TronPipeline: Sendable {

    // MARK: - Properties

    /// The pipeline configuration.
    let config: TronPipelineConfig

    /// The crisis detector for inbound messages. Runs BEFORE injection scanning.
    private let crisisDetector: CrisisDetector

    /// The injection scanner for inbound messages.
    private let injectionScanner: InjectionScanner

    /// The credential scanner for outbound responses.
    private let credentialScanner: CredentialScanner

    /// Logger for pipeline decisions. NEVER logs message content.
    private static let logger = Logger(
        subsystem: "com.emberhearth.app",
        category: "TronPipeline"
    )

    // MARK: - Initialization

    /// Creates a TronPipeline with the specified configuration.
    ///
    /// - Parameters:
    ///   - config: Pipeline configuration. Defaults to `.default`.
    ///   - crisisDetector: The crisis detector to use. Defaults to a new instance.
    ///   - injectionScanner: The injection scanner to use. Defaults to a new instance.
    ///   - credentialScanner: The credential scanner to use. Defaults to a new instance.
    init(
        config: TronPipelineConfig = .default,
        crisisDetector: CrisisDetector = CrisisDetector(),
        injectionScanner: InjectionScanner = InjectionScanner(),
        credentialScanner: CredentialScanner = CredentialScanner()
    ) {
        self.config = config
        self.crisisDetector = crisisDetector
        self.injectionScanner = injectionScanner
        self.credentialScanner = credentialScanner
    }

    // MARK: - Inbound Pipeline

    /// Processes an inbound user message through the security pipeline.
    ///
    /// Checks are applied in this order:
    /// 1. **Group chat detection** — Block if message is from a group chat
    /// 2. **Phone number filtering** — Ignore if number is not in allowed list
    /// 3. **Crisis detection** — Return crisis response if crisis signals detected (does NOT block)
    /// 4. **Injection scanning** — Block if injection patterns detected at/above threshold
    ///
    /// Crisis detection runs before injection scanning because a user in crisis may use
    /// language that superficially resembles an injection attempt. Safety takes priority.
    ///
    /// - Parameters:
    ///   - message: The raw message text from the user.
    ///   - phoneNumber: The sender's phone number in E.164 format (e.g., "+15551234567").
    ///   - isGroupChat: Whether the message is from a group chat.
    /// - Returns: An `InboundResult` indicating whether the message should be processed.
    func processInbound(
        message: String,
        phoneNumber: String,
        isGroupChat: Bool
    ) -> InboundResult {

        // Step 1: Group chat check
        if config.blockGroupChats && isGroupChat {
            Self.logger.info("Blocked group chat message from: \(phoneNumber.suffix(4), privacy: .public)")
            SecurityLogger.shared.logGroupChatBlock(phoneNumber: phoneNumber)
            return .blocked(reason: "Group chat messages are not supported")
        }

        // Step 2: Phone number filter
        if !config.allowedPhoneNumbers.isEmpty {
            guard config.allowedPhoneNumbers.contains(phoneNumber) else {
                Self.logger.info("Ignored message from unauthorized number: \(phoneNumber.suffix(4), privacy: .public)")
                SecurityLogger.shared.logUnauthorizedNumber(phoneNumber: phoneNumber)
                return .ignored
            }
        }

        // Step 3: Crisis detection (runs BEFORE injection scanning — safety takes priority)
        if config.enableCrisisDetection {
            if let assessment = crisisDetector.detectCrisis(in: message) {
                Self.logger.warning(
                    "Crisis detected: tier=\(assessment.tier.rawValue, privacy: .public), from=\(phoneNumber.suffix(4), privacy: .public)"
                )
                SecurityLogger.shared.logCrisisDetected(
                    tier: assessment.tier,
                    patternDescriptions: assessment.matchedPatterns,
                    phoneNumber: phoneNumber
                )
                let crisisResponse = CrisisResponseTemplates.response(for: assessment.tier)
                // Not blocked — message still goes to LLM. Caller prepends crisisResponse.
                return .crisis(message: message, tier: assessment.tier, crisisResponse: crisisResponse)
            }
        }

        // Step 4: Injection scanning
        if config.enableInjectionScanning {
            let scanResult = injectionScanner.scan(message: message)

            if scanResult.threatLevel >= config.inboundBlockThreshold {
                let patternIds = scanResult.matchedPatterns.map(\.patternId).joined(separator: ", ")
                Self.logger.warning(
                    "Blocked inbound message: threat=\(scanResult.threatLevel.label, privacy: .public), patterns=[\(patternIds, privacy: .public)]"
                )
                SecurityLogger.shared.logInjectionAttempt(
                    patternIds: scanResult.matchedPatterns.map(\.patternId),
                    threatLevel: scanResult.threatLevel,
                    phoneNumber: phoneNumber
                )
                let reason = "Potential security threat detected (level: \(scanResult.threatLevel.label))"
                SecurityLogger.shared.logMessageBlocked(reason: reason, phoneNumber: phoneNumber)
                return .blocked(reason: reason)
            }

            if scanResult.threatLevel > .none {
                // Log medium/low threats but allow the message
                let patternIds = scanResult.matchedPatterns.map(\.patternId).joined(separator: ", ")
                Self.logger.info(
                    "Allowed inbound message with warning: threat=\(scanResult.threatLevel.label, privacy: .public), patterns=[\(patternIds, privacy: .public)]"
                )
                SecurityLogger.shared.logInjectionAttempt(
                    patternIds: scanResult.matchedPatterns.map(\.patternId),
                    threatLevel: scanResult.threatLevel,
                    phoneNumber: phoneNumber
                )
            }
        }

        // All checks passed
        SecurityLogger.shared.logMessageAllowed(phoneNumber: phoneNumber)
        return .allowed(message)
    }

    // MARK: - Outbound Pipeline

    /// Processes an outbound LLM response through the security pipeline.
    ///
    /// Currently performs credential scanning only.
    /// If credentials are detected, they are redacted before the response is returned.
    ///
    /// - Parameter response: The LLM response text to check.
    /// - Returns: An `OutboundResult` with the original or redacted response.
    func processOutbound(response: String) -> OutboundResult {

        guard config.enableCredentialScanning else {
            return .allowed(response)
        }

        let scanResult = credentialScanner.scanOutput(response: response)

        if scanResult.containsCredentials {
            Self.logger.warning(
                "Redacted \(scanResult.matchCount, privacy: .public) credential(s) from outbound response: \(scanResult.detectedTypes.joined(separator: ", "), privacy: .public)"
            )
            SecurityLogger.shared.logResponseRedacted(
                types: scanResult.detectedTypes,
                count: scanResult.matchCount
            )
            return .redacted(scanResult.redactedResponse)
        }

        SecurityLogger.shared.logResponseAllowed()
        return .allowed(response)
    }
}
