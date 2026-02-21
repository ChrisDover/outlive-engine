// OuraClient.swift
// OutliveEngine
//
// OAuth 2.0 integration with the Oura Ring API for readiness, sleep,
// and activity data. Tokens are stored securely in the Keychain.

import Foundation
import CryptoKit

// MARK: - Oura Errors

enum OuraClientError: Error, Sendable, LocalizedError {
    case notAuthenticated
    case authorizationFailed(underlying: String)
    case tokenExchangeFailed
    case requestFailed(statusCode: Int)
    case decodingFailed(underlying: String)
    case noData

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:              "Not authenticated with Oura. Please connect your ring."
        case .authorizationFailed(let msg):  "Oura authorization failed: \(msg)"
        case .tokenExchangeFailed:           "Failed to exchange authorization code for Oura tokens."
        case .requestFailed(let code):       "Oura API request failed with status \(code)."
        case .decodingFailed(let msg):       "Failed to decode Oura response: \(msg)"
        case .noData:                        "No Oura data found for the requested date."
        }
    }
}

// MARK: - Oura API Response Models

private struct OuraTokenResponse: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken  = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn    = "expires_in"
    }
}

private struct OuraReadinessResponse: Decodable, Sendable {
    let data: [OuraReadiness]
}

private struct OuraReadiness: Decodable, Sendable {
    let day: String
    let score: Int
    let contributors: OuraReadinessContributors
}

private struct OuraReadinessContributors: Decodable, Sendable {
    let restingHeartRate: Int?
    let hrvBalance: Int?

    enum CodingKeys: String, CodingKey {
        case restingHeartRate = "resting_heart_rate"
        case hrvBalance       = "hrv_balance"
    }
}

private struct OuraSleepResponse: Decodable, Sendable {
    let data: [OuraSleep]
}

private struct OuraSleep: Decodable, Sendable {
    let day: String
    let score: Int?
    let contributors: OuraSleepContributors?
    let totalSleepDuration: Int?
    let deepSleepDuration: Int?
    let remSleepDuration: Int?
    let averageHeartRate: Double?
    let averageHrv: Double?

    enum CodingKeys: String, CodingKey {
        case day
        case score
        case contributors
        case totalSleepDuration  = "total_sleep_duration"
        case deepSleepDuration   = "deep_sleep_duration"
        case remSleepDuration    = "rem_sleep_duration"
        case averageHeartRate    = "average_heart_rate"
        case averageHrv          = "average_hrv"
    }
}

private struct OuraSleepContributors: Decodable, Sendable {
    let totalSleep: Int?
    let deepSleep: Int?

    enum CodingKeys: String, CodingKey {
        case totalSleep = "total_sleep"
        case deepSleep  = "deep_sleep"
    }
}

private struct OuraActivityResponse: Decodable, Sendable {
    let data: [OuraActivity]
}

private struct OuraActivity: Decodable, Sendable {
    let day: String
    let score: Int?
    let steps: Int
    let activeCalories: Int
    let totalCalories: Int
    let targetCalories: Int?

    enum CodingKeys: String, CodingKey {
        case day
        case score
        case steps
        case activeCalories = "active_calories"
        case totalCalories  = "total_calories"
        case targetCalories = "target_calories"
    }
}

// MARK: - Oura Client

/// Thread-safe client for the Oura Ring REST API using OAuth 2.0.
actor OuraClient {

    // MARK: - Constants

    private enum API {
        static let authorizationURL  = URL(string: "https://cloud.ouraring.com/oauth/authorize")!
        static let tokenURL          = URL(string: "https://api.ouraring.com/oauth/token")!
        static let baseURL           = URL(string: "https://api.ouraring.com/v2/usercollection")!
        static let clientId          = "OURA_CLIENT_ID"    // Replace with actual client ID.
        static let clientSecret      = "OURA_CLIENT_SECRET" // Replace — stored securely in production.
        static let redirectURI       = "outliveengine://oura/callback"
    }

    private enum KeychainKeys {
        static let service      = "com.outlive-engine.oura"
        static let accessToken  = "oura-access-token"
        static let refreshToken = "oura-refresh-token"
    }

    // MARK: - State

    private var accessToken: String?

    // MARK: - Initialization

    init() {
        self.accessToken = Self.readKeychain(account: KeychainKeys.accessToken)
    }

    /// Whether the client has a stored access token.
    var isAuthenticated: Bool {
        accessToken != nil
    }

    // MARK: - OAuth 2.0 Authentication

    /// Generates the OAuth authorization URL for initiating the Oura flow.
    ///
    /// The caller should present this URL in an `ASWebAuthenticationSession`.
    /// After the user authorizes, call `exchangeCode(_:)` with the returned code.
    func authorizationURL() -> URL {
        var components = URLComponents(url: API.authorizationURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: API.clientId),
            URLQueryItem(name: "redirect_uri", value: API.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "daily readiness sleep activity personal"),
            URLQueryItem(name: "state", value: UUID().uuidString),
        ]
        return components.url!
    }

    /// Exchanges an authorization code for access and refresh tokens.
    func exchangeCode(_ code: String) async throws {
        var request = URLRequest(url: API.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "grant_type": "authorization_code",
            "client_id": API.clientId,
            "client_secret": API.clientSecret,
            "code": code,
            "redirect_uri": API.redirectURI,
        ]
        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OuraClientError.tokenExchangeFailed
        }

        let tokenResponse = try JSONDecoder().decode(OuraTokenResponse.self, from: data)
        accessToken = tokenResponse.accessToken

        Self.storeKeychain(tokenResponse.accessToken, account: KeychainKeys.accessToken)
        Self.storeKeychain(tokenResponse.refreshToken, account: KeychainKeys.refreshToken)
    }

    /// Disconnects the Oura account by removing stored tokens.
    func disconnect() {
        accessToken = nil
        Self.deleteKeychain(account: KeychainKeys.accessToken)
        Self.deleteKeychain(account: KeychainKeys.refreshToken)
    }

    // MARK: - Data Fetching

    /// Fetches readiness data for a specific date.
    /// Returns partial `DailyWearableData` fields: recoveryScore, restingHR.
    func fetchReadiness(for date: Date, userId: String) async throws -> DailyWearableData {
        let dateString = Self.formatDate(date)

        let response: OuraReadinessResponse = try await authenticatedGet(
            path: "daily_readiness",
            queryItems: [
                URLQueryItem(name: "start_date", value: dateString),
                URLQueryItem(name: "end_date", value: dateString),
            ]
        )

        guard let readiness = response.data.first else {
            throw OuraClientError.noData
        }

        return DailyWearableData(
            userId: userId,
            date: date,
            source: .oura,
            restingHR: readiness.contributors.restingHeartRate,
            recoveryScore: Double(readiness.score)
        )
    }

    /// Fetches sleep data for a specific date.
    /// Returns partial `DailyWearableData` fields: sleepHours, deepSleepMinutes, remSleepMinutes, hrvMs.
    func fetchSleep(for date: Date, userId: String) async throws -> DailyWearableData {
        let dateString = Self.formatDate(date)

        let response: OuraSleepResponse = try await authenticatedGet(
            path: "daily_sleep",
            queryItems: [
                URLQueryItem(name: "start_date", value: dateString),
                URLQueryItem(name: "end_date", value: dateString),
            ]
        )

        guard let sleep = response.data.first else {
            throw OuraClientError.noData
        }

        let sleepHours = sleep.totalSleepDuration.map { Double($0) / 3600.0 }
        let deepMinutes = sleep.deepSleepDuration.map { $0 / 60 }
        let remMinutes = sleep.remSleepDuration.map { $0 / 60 }

        return DailyWearableData(
            userId: userId,
            date: date,
            source: .oura,
            hrvMs: sleep.averageHrv,
            sleepHours: sleepHours,
            deepSleepMinutes: deepMinutes,
            remSleepMinutes: remMinutes
        )
    }

    /// Fetches activity data for a specific date.
    /// Returns partial `DailyWearableData` fields: steps, activeCalories.
    func fetchActivity(for date: Date, userId: String) async throws -> DailyWearableData {
        let dateString = Self.formatDate(date)

        let response: OuraActivityResponse = try await authenticatedGet(
            path: "daily_activity",
            queryItems: [
                URLQueryItem(name: "start_date", value: dateString),
                URLQueryItem(name: "end_date", value: dateString),
            ]
        )

        guard let activity = response.data.first else {
            throw OuraClientError.noData
        }

        return DailyWearableData(
            userId: userId,
            date: date,
            source: .oura,
            steps: activity.steps,
            activeCalories: activity.activeCalories
        )
    }

    // MARK: - Authenticated Request

    private func authenticatedGet<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> T {
        guard let token = accessToken else {
            throw OuraClientError.notAuthenticated
        }

        var components = URLComponents(url: API.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = queryItems

        guard let url = components.url else {
            throw OuraClientError.noData
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OuraClientError.noData
        }

        // Handle token refresh on 401.
        if httpResponse.statusCode == 401 {
            let refreshed = await refreshAccessToken()
            if refreshed {
                return try await authenticatedGet(path: path, queryItems: queryItems)
            }
            throw OuraClientError.notAuthenticated
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw OuraClientError.requestFailed(statusCode: httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw OuraClientError.decodingFailed(underlying: error.localizedDescription)
        }
    }

    // MARK: - Token Refresh

    private func refreshAccessToken() async -> Bool {
        guard let refreshToken = Self.readKeychain(account: KeychainKeys.refreshToken) else {
            return false
        }

        var request = URLRequest(url: API.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "grant_type": "refresh_token",
            "client_id": API.clientId,
            "client_secret": API.clientSecret,
            "refresh_token": refreshToken,
        ]
        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return false
            }

            let tokenResponse = try JSONDecoder().decode(OuraTokenResponse.self, from: data)
            accessToken = tokenResponse.accessToken

            Self.storeKeychain(tokenResponse.accessToken, account: KeychainKeys.accessToken)
            Self.storeKeychain(tokenResponse.refreshToken, account: KeychainKeys.refreshToken)

            return true
        } catch {
            return false
        }
    }

    // MARK: - Date Formatting

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }

    // MARK: - Keychain Helpers

    private static func storeKeychain(_ value: String, account: String) {
        guard let data = value.data(using: .utf8) else { return }

        let deleteQuery: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String:  KeychainKeys.service,
            kSecAttrAccount as String:  account,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String:         kSecClassGenericPassword,
            kSecAttrService as String:    KeychainKeys.service,
            kSecAttrAccount as String:    account,
            kSecValueData as String:      data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecAttrSynchronizable as String: kCFBooleanFalse!,
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private static func readKeychain(account: String) -> String? {
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

    private static func deleteKeychain(account: String) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String:  KeychainKeys.service,
            kSecAttrAccount as String:  account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
