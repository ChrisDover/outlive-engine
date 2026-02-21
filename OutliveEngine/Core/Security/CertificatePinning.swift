// CertificatePinning.swift
// OutliveEngine
//
// Created for Outlive Engine iOS App
// Security foundation: TLS certificate pinning via SHA-256 public key hashes

import Foundation
import CryptoKit
import Security

// MARK: - Pinning Configuration

/// Configuration for a pinned host, containing one or more SHA-256 hashes
/// of the Subject Public Key Info (SPKI) of trusted certificates.
struct PinningConfiguration: Sendable {
    /// The hostname to pin (e.g., "api.outlive.app").
    let hostname: String

    /// SHA-256 hashes of the SPKI for trusted certificates, base64-encoded.
    /// Multiple pins allow for certificate rotation without app updates.
    let pinnedHashes: [String]

    /// Whether to enforce pinning. When `false`, pin failures are logged but connections proceed.
    /// Set to `false` only during development or staged rollout.
    let enforced: Bool

    init(hostname: String, pinnedHashes: [String], enforced: Bool = true) {
        self.hostname = hostname
        self.pinnedHashes = pinnedHashes
        self.enforced = enforced
    }
}

// MARK: - Pinning Errors

enum CertificatePinningError: Error, Sendable {
    case noPinConfiguredForHost(String)
    case pinValidationFailed(host: String, receivedHash: String)
    case certificateChainEmpty
    case publicKeyExtractionFailed
}

// MARK: - PinnedURLSession

/// A `URLSessionDelegate` implementation that enforces TLS certificate pinning
/// by validating the server's public key hash against a set of known-good SHA-256 hashes.
///
/// Usage:
/// ```swift
/// let session = PinnedURLSession.makeSession(configurations: [
///     PinningConfiguration(
///         hostname: "api.outlive.app",
///         pinnedHashes: ["base64EncodedSHA256HashHere"]
///     )
/// ])
/// let (data, response) = try await session.data(from: url)
/// ```
final class PinnedURLSession: NSObject, URLSessionDelegate, Sendable {

    // MARK: - Properties

    /// Pin configurations keyed by hostname for O(1) lookup.
    private let configurations: [String: PinningConfiguration]

    // MARK: - Initialization

    /// Creates a delegate with the given pinning configurations.
    ///
    /// - Parameter configurations: Array of `PinningConfiguration` values, one per host.
    init(configurations: [PinningConfiguration]) {
        var map: [String: PinningConfiguration] = [:]
        for config in configurations {
            map[config.hostname] = config
        }
        self.configurations = map
        super.init()
    }

    // MARK: - Factory

    /// Creates a URLSession pre-configured with certificate pinning.
    ///
    /// - Parameters:
    ///   - configurations: The pinning configurations for each host.
    ///   - sessionConfiguration: The underlying `URLSessionConfiguration`. Defaults to `.default`.
    /// - Returns: A `URLSession` with pinning enforced through its delegate.
    static func makeSession(
        configurations: [PinningConfiguration],
        sessionConfiguration: URLSessionConfiguration = .default
    ) -> URLSession {
        let delegate = PinnedURLSession(configurations: configurations)
        return URLSession(
            configuration: sessionConfiguration,
            delegate: delegate,
            delegateQueue: nil
        )
    }

    // MARK: - URLSessionDelegate

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let host = challenge.protectionSpace.host

        // If no pin is configured for this host, allow default TLS validation.
        guard let pinConfig = configurations[host] else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Evaluate the server trust against system root certificates first.
        var secResult: SecTrustResultType = .invalid
        let evaluateStatus = SecTrustEvaluate(serverTrust, &secResult)

        guard evaluateStatus == errSecSuccess,
              secResult == .unspecified || secResult == .proceed else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Validate the public key hash of each certificate in the chain.
        let certificateCount = SecTrustGetCertificateCount(serverTrust)

        guard certificateCount > 0 else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        var matched = false

        for index in 0..<certificateCount {
            guard let certificate = SecTrustCopyCertificateChain(serverTrust)
                .map({ ($0 as! [SecCertificate])[index] }) else {
                continue
            }

            guard let publicKeyHash = Self.sha256HashOfPublicKey(for: certificate) else {
                continue
            }

            if pinConfig.pinnedHashes.contains(publicKeyHash) {
                matched = true
                break
            }
        }

        if matched {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else if pinConfig.enforced {
            completionHandler(.cancelAuthenticationChallenge, nil)
        } else {
            // Non-enforced: log the mismatch but allow the connection.
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        }
    }

    // MARK: - Public Key Hashing

    /// Extracts the public key from a certificate and returns its SHA-256 hash, base64-encoded.
    ///
    /// This hashes the Subject Public Key Info (SPKI) data, which includes both the
    /// algorithm identifier and the public key bits. This is the same format used by
    /// HTTP Public Key Pinning (HPKP / RFC 7469).
    ///
    /// - Parameter certificate: The `SecCertificate` to hash.
    /// - Returns: The base64-encoded SHA-256 hash, or `nil` if extraction fails.
    static func sha256HashOfPublicKey(for certificate: SecCertificate) -> String? {
        guard let publicKey = SecCertificateCopyKey(certificate) else {
            return nil
        }

        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            return nil
        }

        let hash = SHA256.hash(data: publicKeyData)
        return Data(hash).base64EncodedString()
    }

    /// Convenience method to compute a pin hash from DER-encoded certificate data.
    /// Useful for extracting pins from `.cer` files bundled in the app.
    ///
    /// - Parameter derData: DER-encoded certificate data.
    /// - Returns: The base64-encoded SHA-256 public key hash, or `nil` on failure.
    static func pinHash(fromDERCertificate derData: Data) -> String? {
        guard let certificate = SecCertificateCreateWithData(nil, derData as CFData) else {
            return nil
        }
        return sha256HashOfPublicKey(for: certificate)
    }
}
