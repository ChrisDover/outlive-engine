// APIClient.swift
// OutliveEngine
//
// Central network client. All server communication flows through this actor,
// which enforces certificate pinning, JWT injection, automatic 401 retry,
// and offline request queuing.

import Foundation
import Network

// MARK: - HTTP Method

enum HTTPMethod: String, Sendable {
    case get    = "GET"
    case post   = "POST"
    case put    = "PUT"
    case delete = "DELETE"
    case patch  = "PATCH"
}

// MARK: - API Error

enum APIError: Error, Sendable, LocalizedError {
    case unauthorized
    case serverError(statusCode: Int, message: String?)
    case networkError(underlying: String)
    case decodingError(underlying: String)
    case offline
    case invalidURL
    case tokenRefreshFailed
    case requestTimeout

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            "Authentication required. Please sign in again."
        case .serverError(let code, let message):
            "Server error \(code): \(message ?? "Unknown error")"
        case .networkError(let underlying):
            "Network error: \(underlying)"
        case .decodingError(let underlying):
            "Failed to decode response: \(underlying)"
        case .offline:
            "No network connection. Request queued for retry."
        case .invalidURL:
            "Invalid URL."
        case .tokenRefreshFailed:
            "Failed to refresh authentication token."
        case .requestTimeout:
            "Request timed out."
        }
    }
}

// MARK: - Queued Request

/// A request captured while offline for later replay.
private struct QueuedRequest: Sendable {
    let urlRequest: URLRequest
    let enqueuedAt: Date
}

// MARK: - API Client

/// Thread-safe network client backed by certificate-pinned URLSession.
///
/// All outbound HTTP traffic should flow through this actor to guarantee
/// consistent JWT injection, audit logging, retry logic, and offline queuing.
actor APIClient {

    // MARK: - Configuration

    private let baseURL: URL
    private let session: URLSession
    private let auditLogger: AuditLogger

    // MARK: - JSON Coding

    nonisolated let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    nonisolated let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    // MARK: - Offline Queue

    private var offlineQueue: [QueuedRequest] = []
    private var isConnected: Bool = true
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.outlive-engine.network-monitor")

    // MARK: - Keychain Constants

    private enum KeychainKeys {
        static let service      = "com.outlive-engine.auth"
        static let tokenAccount = "auth-token"
        static let refreshAccount = "refresh-token"
    }

    // MARK: - Initialization

    /// Creates the API client.
    ///
    /// - Parameters:
    ///   - baseURL: The root URL for all API requests. Defaults to localhost development server.
    ///   - pinningConfigurations: TLS pinning configurations for the session.
    ///   - auditLogger: The shared audit logger instance.
    init(
        baseURL: URL = URL(string: "https://localhost:8000/api/v1")!,
        pinningConfigurations: [PinningConfiguration] = [],
        auditLogger: AuditLogger = AuditLogger()
    ) {
        self.baseURL = baseURL
        self.auditLogger = auditLogger

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 30
        sessionConfig.timeoutIntervalForResource = 120
        sessionConfig.waitsForConnectivity = false

        self.session = PinnedURLSession.makeSession(
            configurations: pinningConfigurations,
            sessionConfiguration: sessionConfig
        )

        Task { await self.startNetworkMonitor() }
    }

    // MARK: - Network Monitoring

    private func startNetworkMonitor() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            Task { await self.handleConnectivityChange(isConnected: path.status == .satisfied) }
        }
        pathMonitor.start(queue: monitorQueue)
    }

    private func handleConnectivityChange(isConnected newValue: Bool) {
        let wasDisconnected = !isConnected
        isConnected = newValue

        if newValue && wasDisconnected {
            Task { await replayOfflineQueue() }
        }
    }

    // MARK: - Public Request Methods

    /// Performs a GET request and decodes the response.
    func get<T: Decodable & Sendable>(
        _ endpoint: APIEndpoint,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> T {
        let request = try buildRequest(endpoint: endpoint, method: .get, queryItems: queryItems)
        return try await execute(request)
    }

    /// Performs a POST request with an encodable body and decodes the response.
    func post<T: Decodable & Sendable, B: Encodable & Sendable>(
        _ endpoint: APIEndpoint,
        body: B
    ) async throws -> T {
        var request = try buildRequest(endpoint: endpoint, method: .post)
        request.httpBody = try encoder.encode(body)
        return try await execute(request)
    }

    /// Performs a POST request with raw `Data` body and decodes the response.
    func post<T: Decodable & Sendable>(
        _ endpoint: APIEndpoint,
        data: Data,
        contentType: String = "application/octet-stream"
    ) async throws -> T {
        var request = try buildRequest(endpoint: endpoint, method: .post)
        request.httpBody = data
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        return try await execute(request)
    }

    /// Performs a PUT request with an encodable body and decodes the response.
    func put<T: Decodable & Sendable, B: Encodable & Sendable>(
        _ endpoint: APIEndpoint,
        body: B
    ) async throws -> T {
        var request = try buildRequest(endpoint: endpoint, method: .put)
        request.httpBody = try encoder.encode(body)
        return try await execute(request)
    }

    /// Performs a DELETE request.
    func delete(_ endpoint: APIEndpoint) async throws {
        let request = try buildRequest(endpoint: endpoint, method: .delete)
        let _: EmptyResponse = try await execute(request)
    }

    // MARK: - Request Building

    private func buildRequest(
        endpoint: APIEndpoint,
        method: HTTPMethod,
        queryItems: [URLQueryItem]? = nil
    ) throws -> URLRequest {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(endpoint.path),
            resolvingAgainstBaseURL: true
        )
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Inject JWT from Keychain.
        if let token = readKeychainValue(account: KeychainKeys.tokenAccount) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    // MARK: - Execution

    private func execute<T: Decodable & Sendable>(_ request: URLRequest, isRetry: Bool = false) async throws -> T {
        // Check connectivity — queue if offline.
        guard isConnected else {
            offlineQueue.append(QueuedRequest(urlRequest: request, enqueuedAt: .now))
            await auditLogger.log(.apiRequest, endpoint: request.url?.path, metadata: ["status": "queued_offline"])
            throw APIError.offline
        }

        // Log outbound request.
        await auditLogger.log(
            .apiRequest,
            endpoint: request.url?.path,
            metadata: ["method": request.httpMethod ?? "UNKNOWN"]
        )

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            await auditLogger.log(.apiError, endpoint: request.url?.path, metadata: ["error": error.localizedDescription])
            throw APIError.networkError(underlying: error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(underlying: "Invalid HTTP response.")
        }

        // Log response.
        await auditLogger.log(
            .apiResponse,
            endpoint: request.url?.path,
            metadata: ["status": "\(httpResponse.statusCode)"]
        )

        // Handle 401 — attempt token refresh then retry once.
        if httpResponse.statusCode == 401 && !isRetry {
            let refreshed = await attemptTokenRefresh()
            if refreshed {
                var retryRequest = request
                if let newToken = readKeychainValue(account: KeychainKeys.tokenAccount) {
                    retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                }
                return try await execute(retryRequest, isRetry: true)
            } else {
                throw APIError.unauthorized
            }
        }

        // Handle other error status codes.
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8)
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: message)
        }

        // Decode.
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(underlying: error.localizedDescription)
        }
    }

    // MARK: - Token Refresh

    private func attemptTokenRefresh() async -> Bool {
        guard let refreshToken = readKeychainValue(account: KeychainKeys.refreshAccount) else {
            return false
        }

        do {
            var request = try buildRequest(endpoint: .authRefresh, method: .post)
            let body = ["refresh_token": refreshToken]
            request.httpBody = try encoder.encode(body)

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return false
            }

            let tokenResponse = try decoder.decode(TokenResponse.self, from: data)
            storeKeychainValue(tokenResponse.accessToken, account: KeychainKeys.tokenAccount)
            if let newRefresh = tokenResponse.refreshToken {
                storeKeychainValue(newRefresh, account: KeychainKeys.refreshAccount)
            }

            await auditLogger.log(.tokenRefresh)
            return true
        } catch {
            await auditLogger.log(.apiError, metadata: ["error": "Token refresh failed: \(error.localizedDescription)"])
            return false
        }
    }

    // MARK: - Offline Queue Replay

    private func replayOfflineQueue() async {
        let queued = offlineQueue
        offlineQueue.removeAll()

        for item in queued {
            // Discard requests older than 10 minutes.
            guard Date.now.timeIntervalSince(item.enqueuedAt) < 600 else { continue }

            do {
                let _: EmptyResponse = try await execute(item.urlRequest)
            } catch {
                // If still offline, re-queue.
                if case APIError.offline = error {
                    offlineQueue.append(item)
                }
            }
        }
    }

    // MARK: - Keychain Helpers

    private nonisolated func readKeychainValue(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String:  KeychainKeys.service,
            kSecAttrAccount as String:  account,
            kSecReturnData as String:   kCFBooleanTrue!,
            kSecMatchLimit as String:   kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private nonisolated func storeKeychainValue(_ value: String, account: String) {
        guard let data = value.data(using: .utf8) else { return }

        let deleteQuery: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String:  KeychainKeys.service,
            kSecAttrAccount as String:  account,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:   KeychainKeys.service,
            kSecAttrAccount as String:   account,
            kSecValueData as String:     data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecAttrSynchronizable as String: kCFBooleanFalse!,
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }
}

// MARK: - Internal Response Types

/// Placeholder for responses with no meaningful body.
private struct EmptyResponse: Decodable, Sendable {}

/// Token response from the refresh endpoint.
private struct TokenResponse: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int?
}
