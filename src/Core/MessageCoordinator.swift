// MessageCoordinator.swift
// EmberHearth
//
// Central orchestrator for the complete message processing lifecycle.

import Foundation
import os
import Combine

/// Central orchestrator for EmberHearth's message processing pipeline.
///
/// The MessageCoordinator wires together all subsystems:
/// ```
/// New iMessage (MessageWatcher)
///   → Inbound security (TronPipeline)
///   → Context building, fact retrieval, session history (ContextBuilder)
///   → LLM call (ClaudeAPIClient)
///   → Outbound security (TronPipeline)
///   → Send response (MessageSender)
///   → Session storage (SessionManager)
///   → Fact extraction (background)
///   → Summary check (background)
/// ```
///
/// ## Thread Safety
/// The coordinator uses an NSLock-based approach for per-phone-number serial processing.
/// Messages from the same phone number are processed one at a time.
/// Messages from different phone numbers can be processed concurrently.
///
/// ## Error Handling
/// Errors at each step are handled gracefully:
/// - Security block → Friendly "Could you rephrase?" message
/// - Ignored number → No response sent
/// - Context/session failure → "Having trouble" message
/// - LLM error → "Having trouble connecting" message, status bar updated to .degraded
/// - Send failure → Retry once, then give up (log only)
/// - Memory/session errors → Logged and skipped; conversation continues
final class MessageCoordinator {

    // MARK: - Properties

    /// Delegate for status update callbacks.
    weak var delegate: MessageCoordinatorDelegate?

    /// The security pipeline for inbound/outbound checks.
    private let tronPipeline: TronPipeline

    /// The iMessage sender.
    private let messageSender: MessageSender

    /// The LLM provider client.
    private let llmClient: any LLMProviderProtocol

    /// The session manager for conversation state.
    private let sessionManager: SessionManager

    /// The fact retriever for memory context.
    private let factRetriever: FactRetriever

    /// The fact extractor for learning from conversations.
    private let factExtractor: FactExtractor

    /// The context builder for assembling LLM prompts.
    private let contextBuilder: ContextBuilder

    /// The summary generator for rolling conversation summaries.
    private let summaryGenerator: SummaryGenerator

    /// The message watcher for detecting new iMessages.
    private let messageWatcher: MessageWatcher

    /// The status bar controller for updating the menu bar state (weak to avoid retain cycles).
    private weak var statusBarController: StatusBarController?

    /// Logger for message processing events. NEVER logs message content.
    private let logger = AppLogger.logger(for: .messages)

    /// Lock protecting `processingNumbers` from concurrent mutation.
    private var processingLock = NSLock()

    /// Set of phone numbers currently being processed (one message at a time per number).
    private var processingNumbers: Set<String> = []

    /// Cancellables for Combine subscriptions.
    private var cancellables = Set<AnyCancellable>()

    /// Whether the coordinator has been started.
    private(set) var isRunning = false

    // MARK: - Initialization

    /// Creates a MessageCoordinator with all required dependencies.
    ///
    /// - Parameters:
    ///   - tronPipeline: The security pipeline for inbound/outbound checks.
    ///   - messageSender: The iMessage sender.
    ///   - llmClient: The LLM provider client.
    ///   - sessionManager: The conversation session manager.
    ///   - factRetriever: The memory fact retriever.
    ///   - factExtractor: The fact extractor for learning from conversations.
    ///   - contextBuilder: The LLM context builder.
    ///   - summaryGenerator: The rolling summary generator.
    ///   - messageWatcher: The iMessage watcher.
    ///   - statusBarController: The menu bar controller (optional, weak reference).
    init(
        tronPipeline: TronPipeline,
        messageSender: MessageSender,
        llmClient: any LLMProviderProtocol,
        sessionManager: SessionManager,
        factRetriever: FactRetriever,
        factExtractor: FactExtractor,
        contextBuilder: ContextBuilder,
        summaryGenerator: SummaryGenerator,
        messageWatcher: MessageWatcher,
        statusBarController: StatusBarController? = nil
    ) {
        self.tronPipeline = tronPipeline
        self.messageSender = messageSender
        self.llmClient = llmClient
        self.sessionManager = sessionManager
        self.factRetriever = factRetriever
        self.factExtractor = factExtractor
        self.contextBuilder = contextBuilder
        self.summaryGenerator = summaryGenerator
        self.messageWatcher = messageWatcher
        self.statusBarController = statusBarController
    }

    // MARK: - Lifecycle

    /// Starts the message coordinator.
    ///
    /// Starts the MessageWatcher, subscribes to new-message events via Combine,
    /// and updates the status bar to `.healthy`.
    ///
    /// - Throws: If the MessageWatcher fails to start (e.g., chat.db not found).
    func start() throws {
        guard !isRunning else {
            logger.warning("MessageCoordinator is already running")
            return
        }

        logger.info("Starting MessageCoordinator")

        try messageWatcher.start()

        messageWatcher.newMessagesPublisher
            .sink { [weak self] messages in
                self?.handleNewMessages(messages)
            }
            .store(in: &cancellables)

        isRunning = true
        statusBarController?.updateState(.healthy)
        delegate?.coordinatorReadinessChanged(isReady: true)

        logger.info("MessageCoordinator started successfully")
    }

    /// Stops the message coordinator.
    ///
    /// Cancels all subscriptions, stops the message watcher, and updates the
    /// status bar to `.offline`.
    func stop() {
        guard isRunning else { return }

        logger.info("Stopping MessageCoordinator")

        cancellables.removeAll()
        messageWatcher.stop()
        isRunning = false

        statusBarController?.updateState(.offline)
        delegate?.coordinatorReadinessChanged(isReady: false)

        logger.info("MessageCoordinator stopped")
    }

    // MARK: - Message Handling

    /// Called when the MessageWatcher detects new incoming messages.
    ///
    /// Dispatches each message into its own async Task for processing.
    private func handleNewMessages(_ messages: [ChatMessage]) {
        for message in messages {
            Task {
                await handleNewMessage(message)
            }
        }
    }

    /// Validates and routes a single incoming ChatMessage.
    ///
    /// Acquires a per-phone-number processing lock to serialize messages from the
    /// same sender. If the lock cannot be acquired immediately, retries once after
    /// 2 seconds; drops the message if still locked.
    private func handleNewMessage(_ message: ChatMessage) async {
        guard let messageText = message.text, !messageText.isEmpty else {
            logger.debug("Skipping message with no text content (id: \(message.id, privacy: .public))")
            return
        }

        guard let phoneNumber = message.phoneNumber else {
            logger.warning("Skipping message with no phone number (id: \(message.id, privacy: .public))")
            return
        }

        guard acquireProcessingLock(for: phoneNumber) else {
            logger.info("Already processing for: \(phoneNumber.suffix(4), privacy: .public), queuing")
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard acquireProcessingLock(for: phoneNumber) else {
                logger.warning("Still processing for: \(phoneNumber.suffix(4), privacy: .public), dropping")
                return
            }
            defer { releaseProcessingLock(for: phoneNumber) }
            await processMessage(messageText, phoneNumber: phoneNumber, isGroupChat: message.isGroupChat)
            return
        }
        defer { releaseProcessingLock(for: phoneNumber) }

        await processMessage(messageText, phoneNumber: phoneNumber, isGroupChat: message.isGroupChat)
    }

    // MARK: - Pipeline Stages

    /// Runs the inbound security check and dispatches to the appropriate handler.
    private func processMessage(_ messageText: String, phoneNumber: String, isGroupChat: Bool) async {
        delegate?.coordinatorDidStartProcessing(from: phoneNumber)

        let inboundResult = tronPipeline.processInbound(
            message: messageText,
            phoneNumber: phoneNumber,
            isGroupChat: isGroupChat
        )

        switch inboundResult {
        case .blocked(let reason):
            logger.info("Message blocked by security: \(reason, privacy: .public)")
            await sendSafeResponse(
                "I noticed something unusual in that message. Could you rephrase what you're asking?",
                to: phoneNumber
            )
            delegate?.coordinatorDidFinishProcessing(from: phoneNumber)

        case .ignored:
            logger.debug("Message ignored (unauthorized number ending in: \(phoneNumber.suffix(4), privacy: .public))")
            delegate?.coordinatorDidFinishProcessing(from: phoneNumber)

        case .allowed(let allowedMessage):
            await processAllowedMessage(allowedMessage, phoneNumber: phoneNumber)
        }
    }

    /// Processes a message that passed the inbound security pipeline.
    ///
    /// Pipeline steps:
    /// 1. Build LLM context (handles session history + fact retrieval internally)
    /// 2. Call the LLM
    /// 3. Run the outbound security pipeline
    /// 4. Send the response via iMessage
    /// 5. Store user and assistant messages in the session
    /// 6. Run background tasks (fact extraction, summary check)
    private func processAllowedMessage(_ messageText: String, phoneNumber: String) async {
        // Step 1: Build context (handles session + facts + system prompt internally)
        let context: ContextBuildResult
        do {
            context = try contextBuilder.buildIntegratedContext(
                factRetriever: factRetriever,
                sessionManager: sessionManager,
                phoneNumber: phoneNumber,
                newMessage: messageText
            )
        } catch {
            logger.error("Context build failed for \(phoneNumber.suffix(4), privacy: .public): \(error.localizedDescription, privacy: .public)")
            await sendSafeResponse(
                "I'm having trouble getting ready to respond. Please try again in a moment.",
                to: phoneNumber
            )
            statusBarController?.updateState(.degraded)
            delegate?.coordinatorDidEncounterError(error, from: phoneNumber)
            delegate?.coordinatorDidFinishProcessing(from: phoneNumber)
            return
        }

        // Step 2: Call the LLM
        let llmResponse: String
        do {
            let response = try await llmClient.sendMessage(
                context.messages,
                systemPrompt: context.systemPrompt
            )
            llmResponse = response.content
        } catch {
            logger.error("LLM call failed for \(phoneNumber.suffix(4), privacy: .public): \(error.localizedDescription, privacy: .public)")
            await sendSafeResponse(
                "I'm having trouble connecting right now. I'll try again soon.",
                to: phoneNumber
            )
            statusBarController?.updateState(.degraded)
            delegate?.coordinatorDidEncounterError(error, from: phoneNumber)
            delegate?.coordinatorDidFinishProcessing(from: phoneNumber)
            return
        }

        // Step 3: Outbound security pipeline
        let outboundResult = tronPipeline.processOutbound(response: llmResponse)
        let finalResponse: String

        switch outboundResult {
        case .allowed(let response):
            finalResponse = response
        case .redacted(let cleanResponse):
            finalResponse = cleanResponse
            logger.info("Outbound response was redacted before sending")
        }

        // Step 4: Send the response
        await sendSafeResponse(finalResponse, to: phoneNumber)

        // Step 5: Persist both messages to the session database
        do {
            let session = try sessionManager.getOrCreateSession(for: phoneNumber)
            try sessionManager.addMessage(to: session, role: .user, content: messageText)
            try sessionManager.addMessage(to: session, role: .assistant, content: finalResponse)
        } catch {
            logger.warning(
                "Failed to store messages in session for \(phoneNumber.suffix(4), privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }

        // Step 6: Background tasks (non-blocking)
        Task.detached(priority: .background) { [weak self] in
            guard let self = self else { return }
            await self.runBackgroundTasks(
                userMessage: messageText,
                assistantResponse: finalResponse,
                phoneNumber: phoneNumber
            )
        }

        delegate?.coordinatorDidFinishProcessing(from: phoneNumber)
    }

    // MARK: - Background Tasks

    /// Runs fact extraction and rolling summary generation after a response is sent.
    ///
    /// Both operations are non-critical: failures are logged and skipped without
    /// interrupting or rolling back anything in the main pipeline.
    private func runBackgroundTasks(
        userMessage: String,
        assistantResponse: String,
        phoneNumber: String
    ) async {
        // Fact extraction
        do {
            let existingFacts = (try? factRetriever.retrieveRelevantFacts(for: userMessage)) ?? []
            let newFacts = try await factExtractor.extractFacts(
                from: userMessage,
                assistantResponse: assistantResponse,
                existingFacts: existingFacts
            )
            if !newFacts.isEmpty {
                logger.info("Extracted \(newFacts.count, privacy: .public) fact(s) from conversation")
            }
        } catch {
            logger.warning("Fact extraction failed: \(error.localizedDescription, privacy: .public)")
        }

        // Rolling summary check
        do {
            let session = try sessionManager.getOrCreateSession(for: phoneNumber)
            let allMessages = try sessionManager.getRecentMessages(for: session, limit: 200)

            let summaryMessages = allMessages.map { msg in
                SummaryMessage(
                    id: msg.id,
                    content: msg.content,
                    isFromUser: msg.role == .user,
                    timestamp: msg.timestamp
                )
            }

            let result = await summaryGenerator.summarizeIfNeeded(
                allMessages: summaryMessages,
                previousSummary: session.summary,
                apiClient: llmClient,
                tokenEstimator: { TokenCounter.estimateTokens(for: $0) }
            )

            if let result = result {
                logger.info(
                    "Generated rolling summary (\(result.summary.count, privacy: .public) chars, \(result.summarizedMessageCount, privacy: .public) messages condensed)"
                )
            }
        } catch {
            logger.warning("Summary check failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Helpers

    /// Sends a message via iMessage with one automatic retry on failure.
    ///
    /// Never throws — all errors are logged and swallowed after the retry attempt.
    private func sendSafeResponse(_ response: String, to phoneNumber: String) async {
        do {
            try await messageSender.send(message: response, to: phoneNumber)
            logger.info("Response sent to: \(phoneNumber.suffix(4), privacy: .public)")
        } catch {
            logger.error(
                "Failed to send response to \(phoneNumber.suffix(4), privacy: .public): \(error.localizedDescription, privacy: .public). Retrying in 1s..."
            )
            do {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                try await messageSender.send(message: response, to: phoneNumber)
                logger.info("Retry succeeded for: \(phoneNumber.suffix(4), privacy: .public)")
            } catch {
                logger.error(
                    "Retry failed for \(phoneNumber.suffix(4), privacy: .public): \(error.localizedDescription, privacy: .public). Giving up."
                )
            }
        }
    }

    /// Attempts to acquire the processing lock for the given phone number.
    ///
    /// - Returns: `true` if the lock was acquired, `false` if already processing.
    private func acquireProcessingLock(for phoneNumber: String) -> Bool {
        processingLock.lock()
        defer { processingLock.unlock() }

        if processingNumbers.contains(phoneNumber) {
            return false
        }
        processingNumbers.insert(phoneNumber)
        return true
    }

    /// Releases the processing lock for the given phone number.
    private func releaseProcessingLock(for phoneNumber: String) {
        processingLock.lock()
        defer { processingLock.unlock() }
        processingNumbers.remove(phoneNumber)
    }
}
