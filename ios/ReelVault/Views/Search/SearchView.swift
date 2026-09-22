import SwiftUI
import SwiftData

public struct SearchView: View {
    @Query private var allItems: [ReelItem]
    @State private var searchQuery: String = ""

    private var filteredResults: [ReelItem] {
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        let q = searchQuery.lowercased()
        return allItems.filter { item in
            let titleMatch = item.title?.lowercased().contains(q) ?? false
            let topicMatch = item.topic?.lowercased().contains(q) ?? false
            let creatorMatch = item.creatorUsername?.lowercased().contains(q) ?? false
            let transcriptMatch = item.transcript?.lowercased().contains(q) ?? false
            let summaryMatch = item.summary?.lowercased().contains(q) ?? false
            let tagMatch = item.tags.contains(where: { $0.lowercased().contains(q) })
            return titleMatch || topicMatch || creatorMatch || transcriptMatch || summaryMatch || tagMatch
        }
    }

    public var body: some View {
        NavigationStack {
            VStack {
                if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("Search your second brain")
                            .font(.headline)
                        Text("Search across spoken transcripts, hooks, topics, and creators.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxHeight: .infinity)
                } else if filteredResults.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "questionmark.folder")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No matching Reels")
                            .font(.headline)
                        Text("Try searching for different keywords or spoken phrases.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List(filteredResults) { item in
                        NavigationLink(destination: ReelDetailView(item: item)) {
                            ReelCardView(item: item)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Search")
            .searchable(text: $searchQuery, prompt: "Search scripts, topics, creators...")
        }
    }
}
