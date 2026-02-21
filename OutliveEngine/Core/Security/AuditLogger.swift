// AuditLogger.swift
// OutliveEngine
//
// Created for Outlive Engine iOS App
// Security foundation: local audit logging with batched sync capability

import Foundation

// MARK: - Audit Action

/// Enumeration of auditable actions within the application.
/// Extend this enum as new auditable operations are introduced.
enum AuditAction: String, Codable, Sendable {
    // Authentication
    case signIn
    case signOut
    case tokenRefresh
    case sessionExpired

    // Data Access
    case dataRead
    case dataWrite
    case dataDelete
    case dataExport

    // Security Events
    case encryptionKeyDerived
    case encryptionKeyRotated
    case certificatePinFailure
    case unauthorizedAccess

    // Network
    case apiRequest
    case apiResponse
    case apiError
    case syncStarted
    case syncCompleted
    case syncFailed

    // User Actions
    case settingsChanged
    case profileUpdated
    case consentGranted
    case consentRevoked
}

// MARK: - Audit Entry

/// A single audit log entry capturing a security-relevant event.
///
/// Entries are `Codable` for JSON serialization and `Sendable` for safe
/// cross-isolation-boundary transfer.
struct AuditEntry: Codable, Sendable, Identifiable {
    /// Unique identifier for this entry.
    let id: UUID

    /// The authenticated user ID associated with this event, if any.
    let userId: String?

    /// The auditable action that occurred.
    let action: AuditAction

    /// The API endpoint or local resource path involved, if applicable.
    let endpoint: String?

    /// ISO 8601 timestamp of when the event occurred.
    let timestamp: Date

    /// Arbitrary key-value metadata providing additional context.
    let metadata: [String: String]?

    init(
        id: UUID = UUID(),
        userId: String? = nil,
        action: AuditAction,
        endpoint: String? = nil,
        timestamp: Date = Date(),
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.userId = userId
        self.action = action
        self.endpoint = endpoint
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

// MARK: - Audit Logger

/// Thread-safe audit logger using Swift actor isolation.
///
/// Collects `AuditEntry` values in an in-memory buffer. Entries can be
/// flushed on demand for batched upload to a remote audit service.
///
/// Usage:
/// ```swift
/// let logger = AuditLogger(userId: "user-abc-123")
/// await logger.log(.signIn, endpoint: "/auth/apple")
/// await logger.log(.apiRequest, endpoint: "/v1/health", metadata: ["method": "GET"])
///
/// let batch = await logger.flush()
/// // Upload `batch` to your audit ingestion endpoint.
/// ```
actor AuditLogger {

    // MARK: - Configuration

    /// Maximum number of entries to buffer before the oldest are dropped.
    /// Prevents unbounded memory growth if flush is delayed.
    private let maxBufferSize: Int

    /// The user ID to stamp on all entries created by this logger instance.
    private var userId: String?

    // MARK: - State

    /// The in-memory buffer of audit entries awaiting flush.
    private var buffer: [AuditEntry] = []

    /// Running count of entries dropped due to buffer overflow since the last flush.
    private var droppedCount: Int = 0

    // MARK: - Initialization

    /// Creates a new audit logger.
    ///
    /// - Parameters:
    ///   - userId: The current authenticated user ID. Can be updated via `setUserId(_:)`.
    ///   - maxBufferSize: Maximum entries to hold before dropping the oldest. Defaults to 1000.
    init(userId: String? = nil, maxBufferSize: Int = 1000) {
        self.userId = userId
        self.maxBufferSize = maxBufferSize
    }

    // MARK: - User Management

    /// Updates the user ID stamped on subsequent log entries.
    ///
    /// Call this after sign-in to associate entries with the authenticated user,
    /// or pass `nil` on sign-out.
    func setUserId(_ userId: String?) {
        self.userId = userId
    }

    // MARK: - Logging

    /// Records an audit entry in the buffer.
    ///
    /// - Parameters:
    ///   - action: The auditable action that occurred.
    ///   - endpoint: The API endpoint or resource path involved, if any.
    ///   - metadata: Optional key-value pairs providing additional context.
    func log(
        _ action: AuditAction,
        endpoint: String? = nil,
        metadata: [String: String]? = nil
    ) {
        let entry = AuditEntry(
            userId: userId,
            action: action,
            endpoint: endpoint,
            metadata: metadata
        )

        buffer.append(entry)

        // Enforce buffer capacity by dropping the oldest entries.
        if buffer.count > maxBufferSize {
            let overflow = buffer.count - maxBufferSize
            buffer.removeFirst(overflow)
            droppedCount += overflow
        }
    }

    /// Records an audit entry with an explicit user ID override.
    ///
    /// Useful for logging events on behalf of a different user or before
    /// the user ID is set on the logger.
    func log(
        _ action: AuditAction,
        userId: String,
        endpoint: String? = nil,
        metadata: [String: String]? = nil
    ) {
        let entry = AuditEntry(
            userId: userId,
            action: action,
            endpoint: endpoint,
            metadata: metadata
        )

        buffer.append(entry)

        if buffer.count > maxBufferSize {
            let overflow = buffer.count - maxBufferSize
            buffer.removeFirst(overflow)
            droppedCount += overflow
        }
    }

    // MARK: - Flushing

    /// Atomically drains the buffer and returns all pending entries for upload.
    ///
    /// After this call the internal buffer is empty. The caller is responsible
    /// for transmitting the entries to the audit ingestion service and handling
    /// any upload failures (e.g., re-enqueueing via `restore(_:)`).
    ///
    /// - Returns: The array of buffered `AuditEntry` values, ordered chronologically.
    func flush() -> [AuditEntry] {
        let entries = buffer
        buffer.removeAll(keepingCapacity: true)
        droppedCount = 0
        return entries
    }

    /// Restores entries back into the buffer after a failed upload attempt.
    ///
    /// Restored entries are prepended so they are flushed first on the next attempt,
    /// preserving chronological order.
    ///
    /// - Parameter entries: The entries that failed to upload.
    func restore(_ entries: [AuditEntry]) {
        buffer.insert(contentsOf: entries, at: 0)

        // Re-enforce buffer cap, dropping the newest restored entries if needed.
        if buffer.count > maxBufferSize {
            let overflow = buffer.count - maxBufferSize
            buffer.removeLast(overflow)
            droppedCount += overflow
        }
    }

    // MARK: - Diagnostics

    /// The current number of entries in the buffer.
    var pendingCount: Int {
        buffer.count
    }

    /// The number of entries dropped due to buffer overflow since the last flush.
    var totalDropped: Int {
        droppedCount
    }

    /// Serializes all pending entries to JSON `Data` for local persistence.
    ///
    /// Use this to persist the buffer to disk before app termination so entries
    /// are not lost.
    func encodeBuffer() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(buffer)
    }

    /// Loads previously persisted entries into the buffer.
    ///
    /// - Parameter data: JSON data previously produced by `encodeBuffer()`.
    func decodeAndRestore(from data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entries = try decoder.decode([AuditEntry].self, from: data)
        buffer.insert(contentsOf: entries, at: 0)

        if buffer.count > maxBufferSize {
            let overflow = buffer.count - maxBufferSize
            buffer.removeLast(overflow)
            droppedCount += overflow
        }
    }
}
