// AIClient.swift
// OutliveEngine
//
// Communicates with the backend AI inference endpoints for health insights,
// experiment analysis, and bloodwork OCR processing.

import Foundation

// MARK: - AI Response Types

/// A single AI-generated health insight.
struct AIInsight: Codable, Sendable, Identifiable {
    let id: UUID
    let category: String
    let title: String
    let summary: String
    let confidence: Double
    let sourceDataRef: String?

    init(
        id: UUID = UUID(),
        category: String,
        title: String,
        summary: String,
        confidence: Double,
        sourceDataRef: String? = nil
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.summary = summary
        self.confidence = confidence
        self.sourceDataRef = sourceDataRef
    }
}

/// Analysis results for an N-of-1 experiment.
struct ExperimentAnalysis: Codable, Sendable {
    let summary: String
    let metricAnalysis: [MetricAnalysisItem]
    let recommendation: String
}

/// Per-metric analysis within an experiment.
struct MetricAnalysisItem: Codable, Sendable {
    let metricName: String
    let baselineMean: Double
    let testMean: Double
    let percentChange: Double
    let isStatisticallySignificant: Bool
    let interpretation: String
}

// MARK: - AI Request Types

private struct InsightsRequest: Encodable, Sendable {
    let userData: [String: AnyCodable]
}

private struct ExperimentAnalysisRequest: Encodable, Sendable {
    let experimentId: String
}

private struct OCRRequest: Encodable, Sendable {
    let imageBase64: String
}

// MARK: - AI Response Wrappers

private struct InsightsResponse: Decodable, Sendable {
    let insights: [AIInsight]
}

private struct ExperimentAnalysisResponse: Decodable, Sendable {
    let analysis: ExperimentAnalysis
}

private struct OCRResponse: Decodable, Sendable {
    let markers: [BloodworkMarker]
}

// MARK: - AI Client Errors

enum AIClientError: Error, Sendable, LocalizedError {
    case inferenceTimeout
    case invalidInput(reason: String)
    case serverError(message: String)

    var errorDescription: String? {
        switch self {
        case .inferenceTimeout:          "AI processing timed out. Please try again."
        case .invalidInput(let reason):  "Invalid input: \(reason)"
        case .serverError(let message):  "AI server error: \(message)"
        }
    }
}

// MARK: - AI Client

/// Provides typed access to backend AI inference endpoints.
///
/// All requests flow through `APIClient`, inheriting its JWT injection,
/// certificate pinning, retry logic, and audit logging.
actor AIClient {

    // MARK: - Dependencies

    private let apiClient: APIClient

    // MARK: - Configuration

    /// Timeout for AI inference requests (seconds). AI workloads are typically
    /// longer-running than standard CRUD operations.
    private let inferenceTimeout: TimeInterval

    // MARK: - Initialization

    init(apiClient: APIClient, inferenceTimeout: TimeInterval = 120) {
        self.apiClient = apiClient
        self.inferenceTimeout = inferenceTimeout
    }

    // MARK: - Insights

    /// Sends user health data to the backend AI and receives personalized insights.
    ///
    /// - Parameter userData: Dictionary of user health data to analyze. Keys should
    ///   match the backend's expected schema (e.g., "hrv_trend", "sleep_scores",
    ///   "bloodwork_latest").
    /// - Returns: An array of AI-generated health insights.
    func generateInsights(userData: [String: Any]) async throws -> [AIInsight] {
        // Convert [String: Any] to encodable representation.
        let encodableData = userData.mapValues { AnyCodable($0) }
        let request = InsightsRequest(userData: encodableData)

        let response: InsightsResponse = try await withThrowingTimeout(seconds: inferenceTimeout) {
            try await self.apiClient.post(.aiInsights, body: request)
        }

        return response.insights
    }

    // MARK: - Experiment Analysis

    /// Requests AI analysis of an N-of-1 experiment's baseline vs. test data.
    ///
    /// - Parameter experimentId: The identifier of the experiment to analyze.
    /// - Returns: Structured analysis including per-metric comparisons and recommendations.
    func analyzeExperiment(experimentId: String) async throws -> ExperimentAnalysis {
        let request = ExperimentAnalysisRequest(experimentId: experimentId)

        let response: ExperimentAnalysisResponse = try await withThrowingTimeout(seconds: inferenceTimeout) {
            try await self.apiClient.post(.aiInsights, body: request)
        }

        return response.analysis
    }

    // MARK: - Bloodwork OCR

    /// Sends a lab report image to the backend for OCR extraction of biomarkers.
    ///
    /// - Parameter imageData: The raw image data (JPEG or PNG) of the lab report.
    /// - Returns: An array of extracted bloodwork markers.
    func processBloodworkOCR(imageData: Data) async throws -> [BloodworkMarker] {
        guard !imageData.isEmpty else {
            throw AIClientError.invalidInput(reason: "Image data is empty.")
        }

        let base64 = imageData.base64EncodedString()
        let request = OCRRequest(imageBase64: base64)

        let response: OCRResponse = try await withThrowingTimeout(seconds: inferenceTimeout) {
            try await self.apiClient.post(.aiOCR, body: request)
        }

        return response.markers
    }

    // MARK: - Timeout Helper

    /// Wraps an async operation with a timeout.
    private func withThrowingTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @Sendable @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw AIClientError.inferenceTimeout
            }

            guard let result = try await group.next() else {
                throw AIClientError.inferenceTimeout
            }

            group.cancelAll()
            return result
        }
    }
}

// MARK: - AnyCodable

/// A type-erased `Codable` wrapper for bridging `[String: Any]` dictionaries
/// into the `Encodable` world. Supports JSON primitives and nested collections.
struct AnyCodable: Codable, Sendable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map(\.value)
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues(\.value)
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let arrayValue as [Any]:
            try container.encode(arrayValue.map { AnyCodable($0) })
        case let dictValue as [String: Any]:
            try container.encode(dictValue.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}
