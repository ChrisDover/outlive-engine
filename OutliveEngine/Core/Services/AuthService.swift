// AuthService.swift
// OutliveEngine
//
// Handles Sign in with Apple authentication, encryption key derivation,
// session persistence via Keychain, and sign-out.

import Foundation
import AuthenticationServices
import Observation

// MARK: - Auth Errors

enum AuthServiceError: Error, Sendable, LocalizedError {
    case invalidCredential
    case keyDerivationFailed
    case keychainWriteFailed
    case sessionExpired

    var errorDescription: String? {
        switch self {
        case .invalidCredential:   "The Sign in with Apple credential was invalid."
        case .keyDerivationFailed: "Failed to derive the encryption key from your Apple ID."
        case .keychainWriteFailed: "Failed to persist session to the secure keychain."
        case .sessionExpired:      "Your session has expired. Please sign in again."
        }
    }
}

// MARK: - Auth Service

@Observable
final class AuthService: @unchecked Sendable {

    // MARK: Constants

    private enum Constants {
        static let keychainService = "com.outlive-engine.auth"
        static let userIdAccount   = "apple-user-id"
        static let tokenAccount    = "auth-token"
    }

    // MARK: State

    private(set) var isLoading = false

    private let keyManager = KeyManager()

    // MARK: - Sign In with Apple

    /// Processes an `ASAuthorizationAppleIDCredential`, derives the encryption
    /// key, stores session data in the Keychain, and updates `AppState`.
    ///
    /// - Parameters:
    ///   - credential: The credential returned by the Sign in with Apple flow.
    ///   - appState: The shared app state to update on success.
    func signInWithApple(
        credential: ASAuthorizationAppleIDCredential,
        appState: AppState
    ) async throws {
        isLoading = true
        defer { isLoading = false }

        let userIdentifier = credential.user
        guard !userIdentifier.isEmpty else {
            throw AuthServiceError.invalidCredential
        }

        // Derive per-user encryption key via HKDF.
        do {
            try keyManager.deriveKey(from: userIdentifier)
            try keyManager.storeMasterKey()
        } catch {
            throw AuthServiceError.keyDerivationFailed
        }

        // Persist the Apple user ID.
        try storeKeychainValue(userIdentifier, account: Constants.userIdAccount)

        // Generate a mock JWT token (replace with real token exchange in production).
        let mockToken = generateMockToken(userId: userIdentifier)
        try storeKeychainValue(mockToken, account: Constants.tokenAccount)

        // Update shared state on the main actor.
        await MainActor.run {
            appState.currentUserId = userIdentifier
            appState.isAuthenticated = true
        }
    }

    // MARK: - Sign Out

    /// Clears the Keychain session and encryption keys, then resets `AppState`.
    @MainActor
    func signOut(appState: AppState) {
        // Remove auth entries from Keychain.
        deleteKeychainValue(account: Constants.userIdAccount)
        deleteKeychainValue(account: Constants.tokenAccount)

        // Remove the encryption key.
        try? keyManager.deleteMasterKey()

        // Reset shared state.
        appState.isAuthenticated = false
        appState.hasCompletedOnboarding = false
        appState.currentUserId = nil
    }

    // MARK: - Check Existing Auth

    /// Attempts to restore a previous session from the Keychain.
    /// If a valid user ID and token are found, re-derives the encryption key
    /// and updates `AppState`.
    func checkExistingAuth(appState: AppState) async {
        guard let userId = readKeychainValue(account: Constants.userIdAccount),
              let _ = readKeychainValue(account: Constants.tokenAccount) else {
            return
        }

        // Re-derive the encryption key so encrypted data is accessible.
        do {
            try keyManager.deriveKey(from: userId)
        } catch {
            // Key derivation failed — session is invalid.
            await MainActor.run { self.signOut(appState: appState) }
            return
        }

        await MainActor.run {
            appState.currentUserId = userId
            appState.isAuthenticated = true
        }
    }

    // MARK: - Mock Token

    private func generateMockToken(userId: String) -> String {
        // In production this would be an actual JWT from a backend token exchange.
        let header = Data("{\"alg\":\"HS256\",\"typ\":\"JWT\"}".utf8).base64EncodedString()
        let payload = Data("{\"sub\":\"\(userId)\",\"iat\":\(Int(Date().timeIntervalSince1970))}".utf8).base64EncodedString()
        let signature = Data("mock-signature".utf8).base64EncodedString()
        return "\(header).\(payload).\(signature)"
    }

    // MARK: - Keychain Helpers

    private func storeKeychainValue(_ value: String, account: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw AuthServiceError.keychainWriteFailed
        }

        let deleteQuery: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String:  Constants.keychainService,
            kSecAttrAccount as String:  account,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:   Constants.keychainService,
            kSecAttrAccount as String:   account,
            kSecValueData as String:     data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecAttrSynchronizable as String: kCFBooleanFalse!,
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AuthServiceError.keychainWriteFailed
        }
    }

    private func readKeychainValue(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String:  Constants.keychainService,
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

    private func deleteKeychainValue(account: String) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String:  Constants.keychainService,
            kSecAttrAccount as String:  account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
