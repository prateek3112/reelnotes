import SwiftUI
import SwiftData

public struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ReelItem.createdAt, order: .reverse) private var allItems: [ReelItem]

    @State private var viewModel = LibraryViewModel()

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter Segment Chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.filters, id: \.self) { filter in
                            Button(action: {
                                withAnimation {
                                    viewModel.selectedFilter = filter
                                }
                            }) {
                                Text(filter)
                                    .font(.subheadline)
                                    .fontWeight(viewModel.selectedFilter == filter ? .semibold : .regular)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(
                                        viewModel.selectedFilter == filter
                                            ? Color.accentColor
                                            : Color(.secondarySystemBackground)
                                    )
                                    .foregroundColor(viewModel.selectedFilter == filter ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                // Error Banner
                if let errorMsg = viewModel.errorMessage {
                    ErrorBannerView(message: errorMsg) {
                        viewModel.errorMessage = nil
                    }
                }

                // Content List or Empty State
                let filtered = viewModel.filteredItems(allItems)
                if filtered.isEmpty {
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView("Syncing your vault...")
                        Spacer()
                    } else {
                        Spacer()
                        EmptyStateView()
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(filtered) { item in
                            NavigationLink(destination: ReelDetailView(item: item)) {
                                ReelCardView(item: item)
                            }
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.deleteReel(item, context: modelContext)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                if item.status == .failed {
                                    Button {
                                        Task {
                                            await viewModel.retryReel(item, context: modelContext)
                                        }
                                    } label: {
                                        Label("Retry", systemImage: "arrow.clockwise")
                                    }
                                    .tint(.blue)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await viewModel.refresh(context: modelContext)
                    }
                }
            }
            .navigationTitle("ReelVault")
            .searchable(text: $viewModel.searchText, prompt: "Search reels, topics, creators...")
            .task {
                await viewModel.refresh(context: modelContext)
                // Subscribe to Realtime events
                await RealtimeService.shared.subscribe { recordId, newStatus in
                    if let item = allItems.first(where: { $0.id == recordId }) {
                        item.status = newStatus
                        try? modelContext.save()
                    }
                }
            }
        }
    }
}
