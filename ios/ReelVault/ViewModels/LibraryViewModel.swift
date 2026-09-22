import Foundation
import SwiftData
import Observation

@Observable
public final class LibraryViewModel {
    public var searchText: String = ""
    public var selectedFilter: String = "All"
    public var isLoading: Bool = false
    public var errorMessage: String? = nil

    public let filters = ["All", "Ready", "Processing", "Failed"]

    public init() {}

    @MainActor
    public func refresh(context: ModelContext) async {
        isLoading = true
        errorMessage = nil

        // Flush any pending offline shares first
        await ReelRepository.shared.flushPendingShares(context: context)

        do {
            let remoteReels = try await ReelRepository.shared.fetchReels(
                search: searchText.isEmpty ? nil : searchText,
                limit: 100
            )
            ReelRepository.shared.syncToContext(remoteReels, context: context)
        } catch {
            self.errorMessage = "Failed to load reels: \(error.localizedDescription)"
        }
        isLoading = false
    }

    @MainActor
    public func deleteReel(_ item: ReelItem, context: ModelContext) async {
        do {
            try await ReelRepository.shared.deleteReel(id: item.id)
            context.delete(item)
            try? context.save()
        } catch {
            self.errorMessage = "Failed to delete reel: \(error.localizedDescription)"
        }
    }

    @MainActor
    public func retryReel(_ item: ReelItem, context: ModelContext) async {
        do {
            try await ReelRepository.shared.retryReel(id: item.id)
            item.status = .pending
            try? context.save()
        } catch {
            self.errorMessage = "Failed to retry reel: \(error.localizedDescription)"
        }
    }

    public func filteredItems(_ items: [ReelItem]) -> [ReelItem] {
        return items.filter { item in
            // Filter by search text
            let matchesSearch: Bool
            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                matchesSearch = true
            } else {
                let query = searchText.lowercased()
                let titleMatch = item.title?.lowercased().contains(query) ?? false
                let topicMatch = item.topic?.lowercased().contains(query) ?? false
                let creatorMatch = item.creatorUsername?.lowercased().contains(query) ?? false
                let transcriptMatch = item.transcript?.lowercased().contains(query) ?? false
                let tagMatch = item.tags.contains(where: { $0.lowercased().contains(query) })
                matchesSearch = titleMatch || topicMatch || creatorMatch || transcriptMatch || tagMatch
            }

            // Filter by status category
            let matchesStatus: Bool
            switch selectedFilter {
            case "Ready":
                matchesStatus = item.status == .completed
            case "Processing":
                matchesStatus = item.status.isProcessing
            case "Failed":
                matchesStatus = item.status == .failed
            default:
                matchesStatus = true
            }

            return matchesSearch && matchesStatus
        }
    }
}
