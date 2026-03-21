// MessageQueueTests.swift
// EmberHearth
//
// Unit tests for MessageQueue.
// Tests FIFO ordering, persistence, capacity limits, thread safety, and edge cases.

import XCTest
@testable import EmberHearth

final class MessageQueueTests: XCTestCase {

    private var queue: MessageQueue!
    private var testStorageURL: URL!

    override func setUp() {
        super.setUp()
        // Use a unique temp file for each test to ensure isolation
        let tempDir = FileManager.default.temporaryDirectory
        testStorageURL = tempDir.appendingPathComponent("test_queue_\(UUID().uuidString).json")
        queue = MessageQueue(storageURL: testStorageURL)
    }

    override func tearDown() {
        // Clean up the test file
        try? FileManager.default.removeItem(at: testStorageURL)
        queue = nil
        testStorageURL = nil
        super.tearDown()
    }

    // MARK: - Basic Operations

    func testNewQueueIsEmpty() {
        XCTAssertTrue(queue.isEmpty, "New queue should be empty")
        XCTAssertEqual(queue.count, 0, "New queue count should be 0")
        XCTAssertNil(queue.peek(), "Peek on empty queue should return nil")
        XCTAssertNil(queue.dequeue(), "Dequeue on empty queue should return nil")
    }

    func testEnqueueIncrementsCount() {
        let message = QueuedMessage(text: "Hello", phoneNumber: "+15551234567")
        queue.enqueue(message: message)

        XCTAssertFalse(queue.isEmpty)
        XCTAssertEqual(queue.count, 1)
    }

    func testEnqueueMultipleMessages() {
        for i in 0..<5 {
            let message = QueuedMessage(text: "Message \(i)", phoneNumber: "+15551234567")
            queue.enqueue(message: message)
        }

        XCTAssertEqual(queue.count, 5)
    }

    // MARK: - FIFO Ordering

    func testDequeueFIFOOrder() {
        let msg1 = QueuedMessage(text: "First", phoneNumber: "+15551111111")
        let msg2 = QueuedMessage(text: "Second", phoneNumber: "+15552222222")
        let msg3 = QueuedMessage(text: "Third", phoneNumber: "+15553333333")

        queue.enqueue(message: msg1)
        queue.enqueue(message: msg2)
        queue.enqueue(message: msg3)

        let dequeued1 = queue.dequeue()
        XCTAssertEqual(dequeued1?.text, "First", "First dequeue should return the oldest message")

        let dequeued2 = queue.dequeue()
        XCTAssertEqual(dequeued2?.text, "Second")

        let dequeued3 = queue.dequeue()
        XCTAssertEqual(dequeued3?.text, "Third")

        XCTAssertNil(queue.dequeue(), "Queue should be empty after draining")
    }

    func testDrainAllReturnsFIFOOrder() {
        let messages = (0..<5).map { i in
            QueuedMessage(text: "Message \(i)", phoneNumber: "+1555000000\(i)")
        }

        for msg in messages {
            queue.enqueue(message: msg)
        }

        let drained = queue.drainAll()

        XCTAssertEqual(drained.count, 5)
        for (index, msg) in drained.enumerated() {
            XCTAssertEqual(msg.text, "Message \(index)",
                "drainAll should return messages in FIFO order")
        }

        XCTAssertTrue(queue.isEmpty, "Queue should be empty after drainAll")
    }

    // MARK: - Peek

    func testPeekReturnsOldestWithoutRemoving() {
        let msg1 = QueuedMessage(text: "First", phoneNumber: "+15551111111")
        let msg2 = QueuedMessage(text: "Second", phoneNumber: "+15552222222")

        queue.enqueue(message: msg1)
        queue.enqueue(message: msg2)

        let peeked = queue.peek()
        XCTAssertEqual(peeked?.text, "First", "Peek should return the oldest message")
        XCTAssertEqual(queue.count, 2, "Peek should NOT remove the message")

        // Peek again should return the same message
        let peekedAgain = queue.peek()
        XCTAssertEqual(peekedAgain?.text, "First")
    }

    // MARK: - Capacity Limits

    func testMaximumCapacityIs50() {
        XCTAssertEqual(MessageQueue.maximumCapacity, 50)
    }

    func testCapacityEnforcedDropsOldest() {
        // Fill the queue to capacity
        for i in 0..<50 {
            let msg = QueuedMessage(text: "Message \(i)", phoneNumber: "+15551234567")
            queue.enqueue(message: msg)
        }
        XCTAssertEqual(queue.count, 50, "Queue should be at capacity")

        // Add one more — should drop the oldest (Message 0)
        let overflow = QueuedMessage(text: "Overflow", phoneNumber: "+15551234567")
        queue.enqueue(message: overflow)

        XCTAssertEqual(queue.count, 50, "Queue should still be at capacity")

        // The oldest message should now be "Message 1" (Message 0 was dropped)
        let oldest = queue.peek()
        XCTAssertEqual(oldest?.text, "Message 1",
            "Oldest message should be 'Message 1' after overflow dropped 'Message 0'")
    }

    func testCapacityDropsMultipleOldest() {
        // Fill to capacity
        for i in 0..<50 {
            queue.enqueue(message: QueuedMessage(text: "Old \(i)", phoneNumber: "+15551234567"))
        }

        // Add 3 more — should drop 3 oldest
        for i in 0..<3 {
            queue.enqueue(message: QueuedMessage(text: "New \(i)", phoneNumber: "+15551234567"))
        }

        XCTAssertEqual(queue.count, 50, "Queue should still be at capacity")

        let oldest = queue.peek()
        XCTAssertEqual(oldest?.text, "Old 3",
            "After adding 3 over capacity, oldest should be 'Old 3'")
    }

    // MARK: - Persistence

    func testPersistenceAcrossInstances() {
        // Enqueue messages in one instance
        let msg1 = QueuedMessage(text: "Persisted 1", phoneNumber: "+15551111111")
        let msg2 = QueuedMessage(text: "Persisted 2", phoneNumber: "+15552222222")
        queue.enqueue(message: msg1)
        queue.enqueue(message: msg2)

        // Create a new instance pointing to the same file
        let newQueue = MessageQueue(storageURL: testStorageURL)

        XCTAssertEqual(newQueue.count, 2, "New instance should load persisted messages")

        let dequeued = newQueue.dequeue()
        XCTAssertEqual(dequeued?.text, "Persisted 1",
            "Persisted messages should maintain FIFO order")
    }

    func testPersistenceAfterDequeue() {
        let msg1 = QueuedMessage(text: "First", phoneNumber: "+15551111111")
        let msg2 = QueuedMessage(text: "Second", phoneNumber: "+15552222222")
        queue.enqueue(message: msg1)
        queue.enqueue(message: msg2)

        // Dequeue one
        _ = queue.dequeue()

        // New instance should only have the remaining message
        let newQueue = MessageQueue(storageURL: testStorageURL)
        XCTAssertEqual(newQueue.count, 1)
        XCTAssertEqual(newQueue.peek()?.text, "Second")
    }

    func testPersistenceAfterDrainAll() {
        queue.enqueue(message: QueuedMessage(text: "Test", phoneNumber: "+15551234567"))
        _ = queue.drainAll()

        // New instance should have empty queue
        let newQueue = MessageQueue(storageURL: testStorageURL)
        XCTAssertTrue(newQueue.isEmpty, "Queue should be empty after drainAll and reload")
    }

    func testPersistenceAfterClear() {
        queue.enqueue(message: QueuedMessage(text: "Test", phoneNumber: "+15551234567"))
        queue.clear()

        let newQueue = MessageQueue(storageURL: testStorageURL)
        XCTAssertTrue(newQueue.isEmpty, "Queue should be empty after clear and reload")
    }

    func testPersistenceWithCorruptFile() {
        // Write garbage to the storage file
        let garbage = "this is not valid json".data(using: .utf8)!
        try? garbage.write(to: testStorageURL)

        // Creating a new queue should not crash — starts with empty queue
        let newQueue = MessageQueue(storageURL: testStorageURL)
        XCTAssertTrue(newQueue.isEmpty, "Corrupt file should result in empty queue")
    }

    func testPersistenceWithMissingFile() {
        // Delete the storage file
        try? FileManager.default.removeItem(at: testStorageURL)

        // Creating a new queue should not crash — starts with empty queue
        let newQueue = MessageQueue(storageURL: testStorageURL)
        XCTAssertTrue(newQueue.isEmpty, "Missing file should result in empty queue")
    }

    // MARK: - QueuedMessage Model

    func testQueuedMessageProperties() {
        let before = Date()
        let msg = QueuedMessage(text: "Hello", phoneNumber: "+15551234567")
        let after = Date()

        XCTAssertEqual(msg.text, "Hello")
        XCTAssertEqual(msg.phoneNumber, "+15551234567")
        XCTAssertEqual(msg.retryCount, 0, "Initial retry count should be 0")
        XCTAssertGreaterThanOrEqual(msg.receivedAt, before)
        XCTAssertLessThanOrEqual(msg.receivedAt, after)
        XCTAssertNotNil(msg.id, "ID should be auto-generated")
    }

    func testQueuedMessageUniqueIds() {
        let msg1 = QueuedMessage(text: "A", phoneNumber: "+15551111111")
        let msg2 = QueuedMessage(text: "A", phoneNumber: "+15551111111")

        XCTAssertNotEqual(msg1.id, msg2.id,
            "Each queued message should have a unique ID")
    }

    func testQueuedMessageCodable() {
        let original = QueuedMessage(text: "Encode me", phoneNumber: "+15551234567")

        do {
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(QueuedMessage.self, from: data)

            XCTAssertEqual(decoded.id, original.id)
            XCTAssertEqual(decoded.text, original.text)
            XCTAssertEqual(decoded.phoneNumber, original.phoneNumber)
            XCTAssertEqual(decoded.retryCount, original.retryCount)
            // Date comparison with 1-second tolerance (JSON date encoding precision)
            XCTAssertEqual(
                decoded.receivedAt.timeIntervalSince1970,
                original.receivedAt.timeIntervalSince1970,
                accuracy: 1.0
            )
        } catch {
            XCTFail("QueuedMessage should be Codable: \(error)")
        }
    }

    func testQueuedMessageEquatable() {
        let msg1 = QueuedMessage(text: "Hello", phoneNumber: "+15551234567")

        // Two different QueuedMessages with different UUIDs should not be equal
        let msg3 = QueuedMessage(text: "Hello", phoneNumber: "+15551234567")
        XCTAssertNotEqual(msg1, msg3,
            "Messages with different UUIDs should not be equal")
    }

    // MARK: - Clear

    func testClearEmptiesQueue() {
        for i in 0..<10 {
            queue.enqueue(message: QueuedMessage(text: "Msg \(i)", phoneNumber: "+15551234567"))
        }

        queue.clear()

        XCTAssertTrue(queue.isEmpty)
        XCTAssertEqual(queue.count, 0)
    }

    func testClearOnEmptyQueueIsSafe() {
        queue.clear()
        XCTAssertTrue(queue.isEmpty, "Clearing an empty queue should be safe")
    }

    // MARK: - DrainAll on Empty

    func testDrainAllOnEmptyQueueReturnsEmpty() {
        let drained = queue.drainAll()
        XCTAssertTrue(drained.isEmpty, "drainAll on empty queue should return empty array")
    }

    // MARK: - Thread Safety

    func testConcurrentEnqueueAndDequeue() {
        let expectation = expectation(description: "Concurrent access should not crash")
        let iterations = 100

        DispatchQueue.concurrentPerform(iterations: iterations) { i in
            if i % 2 == 0 {
                let msg = QueuedMessage(text: "Concurrent \(i)", phoneNumber: "+15551234567")
                self.queue.enqueue(message: msg)
            } else {
                _ = self.queue.dequeue()
            }
        }

        // If we get here without crashing, thread safety is working
        expectation.fulfill()
        wait(for: [expectation], timeout: 5.0)
    }

    func testConcurrentCountAndEnqueue() {
        let expectation = expectation(description: "Concurrent count access should not crash")
        let iterations = 100

        DispatchQueue.concurrentPerform(iterations: iterations) { i in
            if i % 3 == 0 {
                let msg = QueuedMessage(text: "Msg \(i)", phoneNumber: "+15551234567")
                self.queue.enqueue(message: msg)
            } else if i % 3 == 1 {
                _ = self.queue.count
            } else {
                _ = self.queue.isEmpty
            }
        }

        expectation.fulfill()
        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - RetryCount

    func testRetryCountCanBeIncremented() {
        var msg = QueuedMessage(text: "Retry me", phoneNumber: "+15551234567")
        XCTAssertEqual(msg.retryCount, 0)

        msg.retryCount += 1
        XCTAssertEqual(msg.retryCount, 1)

        msg.retryCount += 1
        XCTAssertEqual(msg.retryCount, 2)
    }

    func testRetryCountPersists() {
        var msg = QueuedMessage(text: "Retry me", phoneNumber: "+15551234567")
        msg.retryCount = 3
        queue.enqueue(message: msg)

        let newQueue = MessageQueue(storageURL: testStorageURL)
        let loaded = newQueue.peek()
        XCTAssertEqual(loaded?.retryCount, 3, "Retry count should persist across instances")
    }
}
