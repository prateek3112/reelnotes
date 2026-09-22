import SwiftUI
import SwiftData

public struct ReelDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: ReelDetailViewModel
    @State private var showDeleteAlert = false
    @State private var isTranscriptExpanded = true

    public init(item: ReelItem) {
        _viewModel = State(initialValue: ReelDetailViewModel(item: item))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Area
                headerSection

                // Toast banner
                if viewModel.showCopiedToast {
                    HStack {
                        Spacer()
                        Label(viewModel.toastMessage, systemImage: "checkmark")
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                            .shadow(radius: 4)
                        Spacer()
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                // Failed Status Alert Banner
                if viewModel.item.status == .failed {
                    failedStateBanner
                }

                // SUMMARY
                if let summary = viewModel.item.summary, !summary.isEmpty {
                    sectionCard(title: "SUMMARY", icon: "text.alignleft") {
                        Text(summary)
                            .font(.body)
                            .lineSpacing(4)
                    }
                }

                // HOOK
                if let hook = viewModel.item.hook, !hook.isEmpty {
                    sectionCard(title: "HOOK", icon: "bolt.fill") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("\"\(hook)\"")
                                .font(.body)
                                .fontWeight(.medium)
                                .italic()
                                .lineSpacing(4)

                            Button(action: viewModel.copyHook) {
                                Label("Copy Hook", systemImage: "doc.on.doc")
                                    .font(.footnote)
                                    .fontWeight(.medium)
                            }
                            .buttonStyle(.bordered)
                            .tint(.accentColor)
                        }
                    }
                }

                // TRANSCRIPT
                if let transcript = viewModel.item.cleanedTranscript ?? viewModel.item.transcript, !transcript.isEmpty {
                    sectionCard(title: "TRANSCRIPT", icon: "waveform.and.mic") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(transcript)
                                .font(.callout)
                                .lineSpacing(4)
                                .textSelection(.enabled)

                            Button(action: viewModel.copyTranscript) {
                                Label("Copy Complete Transcript", systemImage: "doc.on.doc.fill")
                                    .font(.footnote)
                                    .fontWeight(.medium)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }

                // TAGS
                if !viewModel.item.tags.isEmpty {
                    sectionCard(title: "TAGS", icon: "tag.fill") {
                        FlowLayout(spacing: 8) {
                            ForEach(viewModel.item.tags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                // METADATA FOOTER
                metadataSection
            }
            .padding(16)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(action: viewModel.copyTranscript) {
                        Label("Copy Transcript", systemImage: "doc.on.doc")
                    }
                    Button(action: viewModel.copyHook) {
                        Label("Copy Hook", systemImage: "bolt")
                    }
                    Button(action: viewModel.openOriginal) {
                        Label("Open on Instagram", systemImage: "arrow.up.right")
                    }
                    Divider()
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Delete Reel", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Delete Reel?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    let success = await viewModel.delete(context: modelContext)
                    if success {
                        dismiss()
                    }
                }
            }
        } message: {
            Text("This will permanently remove this Reel and its transcribed notes from your library.")
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 16) {
            // Thumbnail
            ZStack {
                if let urlString = viewModel.item.thumbnailUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Color(.tertiarySystemFill)
                        }
                    }
                } else {
                    Color(.tertiarySystemFill)
                }
            }
            .frame(width: 90, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 4)

            // Header Meta
            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.item.title ?? "Instagram Reel")
                    .font(.title3)
                    .fontWeight(.bold)
                    .lineLimit(3)

                if let creator = viewModel.item.creatorUsername {
                    Text("@\(creator)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if let topic = viewModel.item.topic {
                    Text(topic)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.12))
                        .foregroundColor(.accentColor)
                        .clipShape(Capsule())
                }

                Button(action: viewModel.openOriginal) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.square")
                        Text("Open Original Reel")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                }
                .padding(.top, 4)
            }
        }
    }

    private var failedStateBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Couldn't process this Reel")
                    .fontWeight(.semibold)
            }
            Text(viewModel.item.errorMessage ?? "The Reel may be private, unavailable, or temporarily inaccessible.")
                .font(.footnote)
                .foregroundColor(.secondary)

            HStack {
                Button(action: {
                    Task { await viewModel.retry(context: modelContext) }
                }) {
                    Text("Retry Processing")
                }
                .buttonStyle(.borderedProminent)

                Button(action: viewModel.openOriginal) {
                    Text("Open on Instagram")
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 4)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func sectionCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            if let duration = viewModel.item.durationSeconds {
                Text("Duration: \(duration) seconds")
            }
            Text("Saved: \(viewModel.item.createdAt.formatted(date: .abbreviated, time: .shortened))")
            if let processed = viewModel.item.processedAt {
                Text("Processed: \(processed.formatted(date: .abbreviated, time: .shortened))")
            }
            Text("Source: Instagram Reel")
        }
        .font(.caption2)
        .foregroundColor(.tertiaryLabel)
        .padding(.horizontal, 4)
    }
}

// Simple FlowLayout helper for Tag chips
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var maxHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += maxHeight + spacing
                maxHeight = 0
            }
            x += size.width + spacing
            maxHeight = max(maxHeight, size.height)
        }
        height = y + maxHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var maxHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += maxHeight + spacing
                maxHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            maxHeight = max(maxHeight, size.height)
        }
    }
}
