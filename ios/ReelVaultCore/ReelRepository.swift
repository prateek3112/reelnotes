import Foundation
import SwiftData

@MainActor
public final class ReelRepository {
    public static let shared = ReelRepository()

    private let session = URLSession.shared

    private init() {}

    // MARK: - API Calls

    /// Submits a new Reel URL to the FastAPI backend
    public func submitReel(url: URL) async throws -> Reel {
        let endpoint = SupabaseConfig.apiBaseURL.appendingPathComponent("api/v1/reels")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.apiKey, forHTTPHeaderField: "X-API-Key")
        request.timeoutInterval = 15.0

        let payload = ["url": url.absoluteString]
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw NSError(domain: "ReelVault", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: errorText])
        }

        return try JSONDecoder().decode(Reel.self, from: data)
    }

    /// Fetches reels from backend API with optional search and filters
    public func fetchReels(search: String? = nil, status: String? = nil, page: Int = 1, limit: Int = 50) async throws -> [Reel] {
        var components = URLComponents(url: SupabaseConfig.apiBaseURL.appendingPathComponent("api/v1/reels"), resolvingAgainstBaseURL: false)!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        if let search = search, !search.isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: search))
        }
        if let status = status, !status.isEmpty {
            queryItems.append(URLQueryItem(name: "status", value: status))
        }
        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.setValue(SupabaseConfig.apiKey, forHTTPHeaderField: "X-API-Key")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let result = try JSONDecoder().decode(ReelListDTO.self, from: data)
        return result.data
    }

    /// Deletes a Reel by ID
    public func deleteReel(id: String) async throws {
        let endpoint = SupabaseConfig.apiBaseURL.appendingPathComponent("api/v1/reels/\(id)")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "DELETE"
        request.setValue(SupabaseConfig.apiKey, forHTTPHeaderField: "X-API-Key")

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    /// Retries processing for a failed Reel
    public func retryReel(id: String) async throws {
        let endpoint = SupabaseConfig.apiBaseURL.appendingPathComponent("api/v1/reels/\(id)/retry")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(SupabaseConfig.apiKey, forHTTPHeaderField: "X-API-Key")

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    // MARK: - SwiftData Sync Operations

    /// Syncs remote reels DTOs into the local SwiftData ModelContext
    public func syncToContext(_ dtos: [Reel], context: ModelContext) {
        let fetchDescriptor = FetchDescriptor<ReelItem>()
        guard let existingItems = try? context.fetch(fetchDescriptor) else { return }
        let existingMap = Dictionary(uniqueKeysWithValues: existingItems.map { ($0.id, $0) })

        for dto in dtos {
            if let existing = existingMap[dto.id] {
                existing.update(from: dto)
            } else {
                let newItem = ReelItem(from: dto)
                context.insert(newItem)
            }
        }
        try? context.save()
    }

    /// Flushes offline pending reels captured by the Share Extension
    public func flushPendingShares(context: ModelContext) async {
        let pending = SharedStorage.shared.fetchPendingReels()
        guard !pending.isEmpty else { return }

        for item in pending {
            if let url = URL(string: item.url) {
                do {
                    let created = try await submitReel(url: url)
                    syncToContext([created], context: context)
                    SharedStorage.shared.removePendingReel(url: item.url)
                } catch {
                    // Retain in queue for next connectivity window
                }
            }
        }
    }
}
