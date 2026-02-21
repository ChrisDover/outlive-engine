// WhoopClient.swift
// OutliveEngine
//
// OAuth 2.0 PKCE integration with the Whoop API for recovery, strain,
// and sleep data. Tokens are stored securely in the Keychain.

import Foundation
import CryptoKit
import AuthenticationServices

// MARK: - Whoop Errors

enum WhoopClientError: Error, Sendable, LocalizedError {
    case notAuthenticated
    case authorizationFailed(underlying: String)
    case tokenExchangeFailed
    case requestFailed(statusCode: Int)
    case decodingFailed(underlying: String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:              "Not authenticated with Whoop. Please connect your account."
        case .authorizationFailed(let msg):  "Whoop authorization failed: \(msg)"
        case .tokenExchangeFailed:           "Failed to exchange authorization code for tokens."
        case .requestFailed(let code):       "Whoop API request failed with status \(code)."
        case .decodingFailed(let msg):       "Failed to decode Whoop response: \(msg)"
        case .invalidResponse:              "Invalid response from Whoop API."
        }
    }
}

// MARK: - Whoop API Response Models

private struct WhoopTokenResponse: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken  = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn    = "expires_in"
    }
}

private struct WhoopRecoveryResponse: Decodable, Sendable {
    let records: [WhoopRecovery]

    enum CodingKeys: String, CodingKey {
        case records
    }
}

private struct WhoopRecovery: Decodable, Sendable {
    let cycleId: Int
    let score: WhoopRecoveryScore

    enum CodingKeys: String, CodingKey {
        case cycleId = "cycle_id"
        case score
    }
}

private struct WhoopRecoveryScore: Decodable, Sendable {
    let recoveryScore: Double
    let restingHeartRate: Double
    let hrvRmssd: Double

    enum CodingKeys: String, CodingKey {
        case recoveryScore  = "recovery_score"
        case restingHeartRate = "resting_heart_rate"
        case hrvRmssd       = "hrv_rmssd_milli"
    }
}

private struct WhoopStrainResponse: Decodable, Sendable {
    let records: [WhoopStrain]
}

private struct WhoopStrain: Decodable, Sendable {
    let score: WhoopStrainScore

    enum CodingKeys: String, CodingKey {
        case score
    }
}

private struct WhoopStrainScore: Decodable, Sendable {
    let strain: Double
    let averageHeartRate: Int
    let kilojoule: Double

    enum CodingKeys: String, CodingKey {
        case strain
        case averageHeartRate = "average_heart_rate"
        case kilojoule
    }
}

private struct WhoopSleepResponse: Decodable, Sendable {
    let records: [WhoopSleep]
}

private struct WhoopSleep: Decodable, Sendable {
    let score: WhoopSleepScore

    enum CodingKeys: String, CodingKey {
        case score
    }
}

private struct WhoopSleepScore: Decodable, Sendable {
    let totalSleepTimeMillis: Int
    let remSleepTimeMillis: Int
    let slowWaveSleepTimeMillis: Int

    enum CodingKeys: String, CodingKey {
        case totalSleepTimeMillis     = "stage_summary.total_in_bed_time_milli"
        case remSleepTimeMillis       = "stage_summary.total_rem_sleep_time_milli"
        case slowWaveSleepTimeMillis  = "stage_summary.total_slow_wave_sleep_time_milli"
    }
}

// MARK: - Whoop Client

/// Thread-safe client for the Whoop REST API using OAuth 2.0 with PKCE.
actor WhoopClient {

    // MARK: - Constants

    private enum API {
        static let authorizationURL  = URL(string: "https://api.prod.whoop.com/oauth/oauth2/auth")!
        static let tokenURL          = URL(string: "https://api.prod.whoop.com/oauth/oauth2/token")!
        static let baseURL           = URL(string: "https://api.prod.whoop.com/developer/v1")!
        static let clientId          = "WHOOP_CLIENT_ID"   // Replace with actual client ID.
        static let redirectURI       = "outliveengine://whoop/callback"
    }

    private enum KeychainKeys {
        static let service      = "com.outlive-engine.whoop"
        static let accessToken  = "whoop-access-token"
        static let refreshToken = "whoop-refresh-token"
    }

    // MARK: - State

    private var accessToken: String?
    private var codeVerifier: String?

    // MARK: - Initialization

    init() {
        // Attempt to restore tokens from Keychain.
        self.accessToken = Self.readKeychain(account: KeychainKeys.accessToken)
    }

    /// Whether the client has a stored access token.
    var isAuthenticated: Bool {
        accessToken != nil
    }

    // MARK: - OAuth 2.0 PKCE Authentication

    /// Generates the PKCE authorization URL for initiating the OAuth flow.
    ///
    /// The caller should present this URL in an `ASWebAuthenticationSession`.
    /// After the user authorizes, call `exchangeCode(_:)` with the returned code.
    func authorizationURL() -> URL {
        let verifier = generateCodeVerifier()
        codeVerifier = verifier
        let challenge = generateCodeChallenge(from: verifier)

        var components = URLComponents(url: API.authorizationURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: API.clientId),
            URLQueryItem(name: "redirect_uri", value: API.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "read:recovery read:cycles read:sleep read:workout"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]
        return components.url!
    }

    /// Exchanges an authorization code for access and refresh tokens.
    func exchangeCode(_ code: String) async throws {
        guard let verifier = codeVerifier else {
            throw WhoopClientError.authorizationFailed(underlying: "Missing code verifier.")
        }

        var request = URLRequest(url: API.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "grant_type": "authorization_code",
            "client_id": API.clientId,
            "code": code,
            "redirect_uri": API.redirectURI,
            "code_verifier": verifier,
        ]
        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WhoopClientError.tokenExchangeFailed
        }

        let tokenResponse = try JSONDecoder().decode(WhoopTokenResponse.self, from: data)
        accessToken = tokenResponse.accessToken
        codeVerifier = nil

        Self.storeKeychain(tokenResponse.accessToken, account: KeychainKeys.accessToken)
        Self.storeKeychain(tokenResponse.refreshToken, account: KeychainKeys.refreshToken)
    }

    // MARK: - Data Fetching

    /// Fetches recovery data for a specific date.
    /// Returns partial `DailyWearableData` fields: recoveryScore, restingHR, hrvMs.
    func fetchRecovery(for date: Date, userId: String) async throws -> DailyWearableData {
        let (start, end) = dayBounds(for: date)

        let data: WhoopRecoveryResponse = try await authenticatedGet(
            path: "recovery",
            queryItems: [
                URLQueryItem(name: "start", value: start),
                URLQueryItem(name: "end", value: end),
            ]
        )

        guard let recovery = data.records.first else {
            throw WhoopClientError.invalidResponse
        }

        return DailyWearableData(
            userId: userId,
            date: date,
            source: .whoop,
            hrvMs: recovery.score.hrvRmssd,
            restingHR: Int(recovery.score.restingHeartRate),
            recoveryScore: recovery.score.recoveryScore
        )
    }

    /// Fetches strain data for a specific date.
    func fetchStrain(for date: Date, userId: String) async throws -> (strain: Double, activeCalories: Int) {
        let (start, end) = dayBounds(for: date)

        let data: WhoopStrainResponse = try await authenticatedGet(
            path: "cycle",
            queryItems: [
                URLQueryItem(name: "start", value: start),
                URLQueryItem(name: "end", value: end),
            ]
        )

        guard let cycle = data.records.first else {
            throw WhoopClientError.invalidResponse
        }

        let caloriesKcal = Int(cycle.score.kilojoule / 4.184)
        return (strain: cycle.score.strain, activeCalories: caloriesKcal)
    }

    /// Fetches sleep data for a specific date.
    func fetchSleep(for date: Date) async throws -> (sleepHours: Double, deepSleepMinutes: Int, remSleepMinutes: Int) {
        let (start, end) = dayBounds(for: date)

        let data: WhoopSleepResponse = try await authenticatedGet(
            path: "activity/sleep",
            queryItems: [
                URLQueryItem(name: "start", value: start),
                URLQueryItem(name: "end", value: end),
            ]
        )

        guard let sleep = data.records.first else {
            throw WhoopClientError.invalidResponse
        }

        let totalHours = Double(sleep.score.totalSleepTimeMillis) / 3_600_000.0
        let deepMinutes = sleep.score.slowWaveSleepTimeMillis / 60_000
        let remMinutes = sleep.score.remSleepTimeMillis / 60_000

        return (sleepHours: totalHours, deepSleepMinutes: deepMinutes, remSleepMinutes: remMinutes)
    }

    // MARK: - Authenticated Request

    private func authenticatedGet<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> T {
        guard let token = accessToken else {
            throw WhoopClientError.notAuthenticated
        }

        var components = URLComponents(url: API.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = queryItems

        guard let url = components.url else {
            throw WhoopClientError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WhoopClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw WhoopClientError.requestFailed(statusCode: httpResponse.statusCode)
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            throw WhoopClientError.decodingFailed(underlying: error.localizedDescription)
        }
    }

    // MARK: - PKCE Helpers

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Date Helpers

    private func dayBounds(for date: Date) -> (start: String, end: String) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        return (start: formatter.string(from: startOfDay), end: formatter.string(from: endOfDay))
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
}
