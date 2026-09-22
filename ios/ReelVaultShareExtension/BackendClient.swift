import Foundation

public struct ShareSubmitResponse: Codable {
    public let id: String
    public let status: String
    public let message: String?
}

public enum ShareSubmitResult {
    case success(ShareSubmitResponse)
    case duplicate(String)
    case offlineQueued
    case error(String)
}

public final class BackendClient: Sendable {
    public static let shared = BackendClient()

    private let session = URLSession.shared

    private init() {}

    public func submitReel(url: URL) async -> ShareSubmitResult {
        let baseURLString = SharedStorage.shared.apiBaseURLString
        guard let endpoint = URL(string: baseURLString)?.appendingPathComponent("api/v1/reels") else {
            SharedStorage.shared.appendPendingReel(url: url.absoluteString)
            return .offlineQueued
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SharedStorage.shared.apiKey, forHTTPHeaderField: "X-API-Key")
        request.timeoutInterval = 10.0  # Extensions must execute quickly

        let payload = ["url": url.absoluteString]
        guard let body = try? JSONEncoder().encode(payload) else {
            return .error("Serialization error")
        }
        request.httpBody = body

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                SharedStorage.shared.appendPendingReel(url: url.absoluteString)
                return .offlineQueued
            }

            if http.statusCode == 200 || http.statusCode == 201 || http.statusCode == 202 {
                if let decoded = try? JSONDecoder().decode(ShareSubmitResponse.self, from: data) {
                    if decoded.message == "Already in your library." {
                        return .duplicate(decoded.message ?? "Already in your library.")
                    }
                    return .success(decoded)
                }
                return .success(ShareSubmitResponse(id: "saved", status: "pending", message: "Saved"))
            } else if http.statusCode == 409 {
                return .duplicate("Already in your library.")
            } else {
                let msg = String(data: data, encoding: .utf8) ?? "Server error (\(http.statusCode))"
                return .error(msg)
            }
        } catch {
            // Network unavailable; queue locally for background sync
            SharedStorage.shared.appendPendingReel(url: url.absoluteString)
            return .offlineQueued
        }
    }
}
