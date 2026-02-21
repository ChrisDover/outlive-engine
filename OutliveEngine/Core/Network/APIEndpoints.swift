// APIEndpoints.swift
// OutliveEngine
//
// Typed endpoint definitions for every backend route. Each case carries its
// path and HTTP method, providing compile-time safety for API calls.

import Foundation

// MARK: - API Endpoint

enum APIEndpoint: Sendable {

    // MARK: - Auth

    case authApple
    case authRefresh
    case authRevoke

    // MARK: - Users

    case usersMe

    // MARK: - Genomics

    case genomicRisks

    // MARK: - Bloodwork

    case bloodworkList
    case bloodworkCreate
    case bloodworkDetail(id: String)
    case bloodworkDelete(id: String)

    // MARK: - Wearables

    case wearableBatch
    case wearableList

    // MARK: - Protocols

    case protocolDaily
    case protocolLibrary
    case protocolUpdateSource(id: String)

    // MARK: - Experiments

    case experimentList
    case experimentCreate
    case experimentDetail(id: String)
    case experimentAddSnapshot(id: String)

    // MARK: - AI

    case aiInsights
    case aiOCR

    // MARK: - Sync

    case syncPush
    case syncPull

    // MARK: - Path

    var path: String {
        switch self {
        // Auth
        case .authApple:                         "auth/apple"
        case .authRefresh:                       "auth/refresh"
        case .authRevoke:                        "auth/revoke"

        // Users
        case .usersMe:                           "users/me"

        // Genomics
        case .genomicRisks:                      "genomics/risks"

        // Bloodwork
        case .bloodworkList:                     "bloodwork"
        case .bloodworkCreate:                   "bloodwork"
        case .bloodworkDetail(let id):           "bloodwork/\(id)"
        case .bloodworkDelete(let id):           "bloodwork/\(id)"

        // Wearables
        case .wearableBatch:                     "wearables/batch"
        case .wearableList:                      "wearables"

        // Protocols
        case .protocolDaily:                     "protocols/daily"
        case .protocolLibrary:                   "protocols/library"
        case .protocolUpdateSource(let id):      "protocols/sources/\(id)"

        // Experiments
        case .experimentList:                    "experiments"
        case .experimentCreate:                  "experiments"
        case .experimentDetail(let id):          "experiments/\(id)"
        case .experimentAddSnapshot(let id):     "experiments/\(id)/snapshots"

        // AI
        case .aiInsights:                        "ai/insights"
        case .aiOCR:                             "ai/ocr"

        // Sync
        case .syncPush:                          "sync/push"
        case .syncPull:                          "sync/pull"
        }
    }

    // MARK: - Method

    var method: HTTPMethod {
        switch self {
        // Auth
        case .authApple:                         .post
        case .authRefresh:                       .post
        case .authRevoke:                        .post

        // Users
        case .usersMe:                           .get

        // Genomics
        case .genomicRisks:                      .get

        // Bloodwork
        case .bloodworkList:                     .get
        case .bloodworkCreate:                   .post
        case .bloodworkDetail:                   .get
        case .bloodworkDelete:                   .delete

        // Wearables
        case .wearableBatch:                     .post
        case .wearableList:                      .get

        // Protocols
        case .protocolDaily:                     .get
        case .protocolLibrary:                   .get
        case .protocolUpdateSource:              .put

        // Experiments
        case .experimentList:                    .get
        case .experimentCreate:                  .post
        case .experimentDetail:                  .get
        case .experimentAddSnapshot:             .post

        // AI
        case .aiInsights:                        .post
        case .aiOCR:                             .post

        // Sync
        case .syncPush:                          .post
        case .syncPull:                          .post
        }
    }

    // MARK: - Full URL

    /// Resolves the full URL against a base URL.
    func url(relativeTo baseURL: URL) -> URL? {
        baseURL.appendingPathComponent(path)
    }
}
