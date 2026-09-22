import SwiftUI

public struct ReelCardView: View {
    public let item: ReelItem

    public var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Thumbnail / Icon
            ZStack {
                if let urlString = item.thumbnailUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure, .empty:
                            thumbnailFallback
                        @unknown default:
                            thumbnailFallback
                        }
                    }
                } else {
                    thumbnailFallback
                }
            }
            .frame(width: 84, height: 112)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)

            // Content Body
            VStack(alignment: .leading, spacing: 6) {
                // Header: Title & Status Indicator
                HStack(alignment: .top) {
                    Text(item.title ?? (item.status.isProcessing ? "Processing Reel..." : "Instagram Reel"))
                        .font(.headline)
                        .lineLimit(2)
                        .foregroundColor(.primary)

                    Spacer(minLength: 4)

                    // Status Badge
                    HStack(spacing: 4) {
                        if item.status.isProcessing {
                            ProgressView()
                                .scaleEffect(0.6)
                        } else {
                            Image(systemName: item.status.iconName)
                                .font(.caption2)
                        }
                        Text(item.status.displayName)
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(item.status.badgeColor.opacity(0.15))
                    .foregroundColor(item.status.badgeColor)
                    .clipShape(Capsule())
                }

                // Creator
                if let creator = item.creatorUsername {
                    Text("@\(creator)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }

                // Topic Pill
                if let topic = item.topic {
                    Text(topic)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(4)
                        .foregroundColor(.secondary)
                }

                // Summary / Hook Preview
                if let summary = item.summary {
                    Text(summary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                } else if let hook = item.hook {
                    Text("\"\(hook)\"")
                        .font(.caption)
                        .italic()
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 2)

                // Timestamp
                Text(item.createdAt.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundColor(.tertiaryLabel)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var thumbnailFallback: some View {
        ZStack {
            Color(.tertiarySystemFill)
            Image(systemName: "film")
                .font(.title2)
                .foregroundColor(.secondary)
        }
    }
}
