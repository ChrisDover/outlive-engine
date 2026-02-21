// KeyManager.swift
// OutliveEngine
//
// Created for Outlive Engine iOS App
// Security foundation: AES-256-GCM encryption, HKDF key derivation, Keychain storage

import Foundation
import CryptoKit
import Security
import Observation

// MARK: - KeyManager Errors

enum KeyManagerError: Error, Sendable, CustomStringConvertible {
    case keyNotAvailable
    case encryptionFailed(underlying: String)
    case decryptionFailed(underlying: String)
    case keychainSaveFailed(status: OSStatus)
    case keychainReadFailed(status: OSStatus)
    case keychainDeleteFailed(status: OSStatus)
    case invalidSealedBoxData
    case keyDerivationFailed

    var description: String {
        switch self {
        case .keyNotAvailable:
            return "Master symmetric key is not available. Derive or retrieve it first."
        case .encryptionFailed(let underlying):
            return "Encryption failed: \(underlying)"
        case .decryptionFailed(let underlying):
            return "Decryption failed: \(underlying)"
        case .keychainSaveFailed(let status):
            return "Keychain save failed with status: \(status)"
        case .keychainReadFailed(let status):
            return "Keychain read failed with status: \(status)"
        case .keychainDeleteFailed(let status):
            return "Keychain delete failed with status: \(status)"
        case .invalidSealedBoxData:
            return "Data is not a valid AES-GCM sealed box."
        case .keyDerivationFailed:
            return "HKDF key derivation failed."
        }
    }
}

// MARK: - KeyManager

@Observable
final class KeyManager: @unchecked Sendable {

    // MARK: - Constants

    private enum Constants {
        static let keychainService = "com.outlive-engine.security"
        static let keychainAccount = "master-symmetric-key"
        static let hkdfSalt = "OutliveEngine-KeyDerivation-Salt-v1"
        static let hkdfInfo = "OutliveEngine-MasterKey-AES256"
        static let symmetricKeyByteCount = 32 // AES-256
    }

    // MARK: - State

    /// Indicates whether a master key is currently loaded in memory.
    private(set) var isKeyLoaded: Bool = false

    /// The in-memory master symmetric key. Access is serialized through the internal lock.
    private var _masterKey: SymmetricKey?

    /// NSLock for thread-safe access to the mutable key state.
    private let lock = NSLock()

    // MARK: - Computed

    private var masterKey: SymmetricKey? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _masterKey
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _masterKey = newValue
            isKeyLoaded = newValue != nil
        }
    }

    // MARK: - Lifecycle

    init() {}

    // MARK: - Key Derivation

    /// Derives a 256-bit symmetric key from an Apple ID user identifier using HKDF-SHA256.
    ///
    /// The user identifier (stable, opaque string from `ASAuthorizationAppleIDCredential.user`)
    /// is used as the input key material. A fixed application salt and info string ensure
    /// deterministic, domain-separated derivation.
    ///
    /// - Parameter userIdentifier: The stable Apple ID user identifier string.
    /// - Returns: The derived `SymmetricKey`.
    @discardableResult
    func deriveKey(from userIdentifier: String) throws -> SymmetricKey {
        guard let inputKeyMaterial = userIdentifier.data(using: .utf8), !inputKeyMaterial.isEmpty else {
            throw KeyManagerError.keyDerivationFailed
        }

        guard let salt = Constants.hkdfSalt.data(using: .utf8),
              let info = Constants.hkdfInfo.data(using: .utf8) else {
            throw KeyManagerError.keyDerivationFailed
        }

        let derivedKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: inputKeyMaterial),
            salt: salt,
            info: info,
            outputByteCount: Constants.symmetricKeyByteCount
        )

        self.masterKey = derivedKey
        return derivedKey
    }

    // MARK: - Encryption

    /// Encrypts arbitrary data using AES-256-GCM with the current master key.
    ///
    /// The returned `Data` contains the combined representation of the sealed box
    /// (nonce + ciphertext + tag), which can be passed directly to `decrypt(_:)`.
    ///
    /// - Parameter data: The plaintext data to encrypt.
    /// - Returns: The combined sealed box data.
    /// - Throws: `KeyManagerError.keyNotAvailable` if no master key is loaded.
    func encrypt(_ data: Data) throws -> Data {
        guard let key = masterKey else {
            throw KeyManagerError.keyNotAvailable
        }

        do {
            let sealedBox = try AES.GCM.seal(data, using: key)

            guard let combined = sealedBox.combined else {
                throw KeyManagerError.encryptionFailed(underlying: "Failed to produce combined sealed box.")
            }

            return combined
        } catch let error as KeyManagerError {
            throw error
        } catch {
            throw KeyManagerError.encryptionFailed(underlying: error.localizedDescription)
        }
    }

    /// Decrypts data that was previously encrypted with `encrypt(_:)`.
    ///
    /// - Parameter data: The combined sealed box data (nonce + ciphertext + tag).
    /// - Returns: The original plaintext data.
    /// - Throws: `KeyManagerError.keyNotAvailable` if no master key is loaded,
    ///           or `KeyManagerError.decryptionFailed` if authentication or decryption fails.
    func decrypt(_ data: Data) throws -> Data {
        guard let key = masterKey else {
            throw KeyManagerError.keyNotAvailable
        }

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            return decryptedData
        } catch let error as KeyManagerError {
            throw error
        } catch is CryptoKitError {
            throw KeyManagerError.invalidSealedBoxData
        } catch {
            throw KeyManagerError.decryptionFailed(underlying: error.localizedDescription)
        }
    }

    // MARK: - Keychain Storage

    /// Persists the current master key to the iOS Keychain.
    ///
    /// The key is stored with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` protection,
    /// meaning it survives device locks but is not included in backups or transferred to
    /// new devices.
    ///
    /// - Throws: `KeyManagerError.keyNotAvailable` if no key is loaded,
    ///           `KeyManagerError.keychainSaveFailed` on Keychain errors.
    func storeMasterKey() throws {
        guard let key = masterKey else {
            throw KeyManagerError.keyNotAvailable
        }

        let keyData = key.withUnsafeBytes { Data($0) }

        // Delete any existing item first to avoid errSecDuplicateItem.
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.keychainService,
            kSecAttrAccount as String: Constants.keychainAccount,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.keychainService,
            kSecAttrAccount as String: Constants.keychainAccount,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecAttrSynchronizable as String: kCFBooleanFalse!,
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeyManagerError.keychainSaveFailed(status: status)
        }
    }

    /// Retrieves the master key from the iOS Keychain and loads it into memory.
    ///
    /// - Returns: The retrieved `SymmetricKey`.
    /// - Throws: `KeyManagerError.keychainReadFailed` if the key cannot be found or read.
    @discardableResult
    func retrieveMasterKey() throws -> SymmetricKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.keychainService,
            kSecAttrAccount as String: Constants.keychainAccount,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let keyData = result as? Data else {
            throw KeyManagerError.keychainReadFailed(status: status)
        }

        let key = SymmetricKey(data: keyData)
        self.masterKey = key
        return key
    }

    /// Removes the master key from both memory and the iOS Keychain.
    ///
    /// - Throws: `KeyManagerError.keychainDeleteFailed` if the Keychain item cannot be removed.
    func deleteMasterKey() throws {
        self.masterKey = nil

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.keychainService,
            kSecAttrAccount as String: Constants.keychainAccount,
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeyManagerError.keychainDeleteFailed(status: status)
        }
    }
}
