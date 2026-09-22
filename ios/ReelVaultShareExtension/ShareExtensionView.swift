import SwiftUI

public enum ShareUIState {
    case extracting
    case saving
    case success
    case duplicate
    case offlineQueued
    case unsupported
    case error(String)
}

public struct ShareExtensionView: View {
    public weak var extensionContext: NSExtensionContext?
    public var onComplete: () -> Void
    public var onCancel: () -> Void

    @State private var state: ShareUIState = .extracting

    public var body: some View {
        ZStack {
            // Dimmed backdrop
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    if !isSaving { onCancel() }
                }

            // Compact Floating Card
            VStack(spacing: 16) {
                // Header Brand
                HStack {
                    Label("ReelVault", systemImage: "sparkles.tv")
                        .font(.headline)
                    Spacer()
                    if !isSaving {
                        Button(action: onCancel) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.title3)
                        }
                    }
                }

                Divider()

                // State content
                switch state {
                case .extracting:
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Reading shared Reel...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 16)

                case .saving:
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Saving to ReelVault...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 16)

                case .success:
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.green)
                        Text("✓ Saved to ReelVault")
                            .font(.headline)
                        Text("Processing will continue in the background.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 12)
                    .task {
                        try? await Task.sleep(nanoseconds: 800_000_000)
                        onComplete()
                    }

                case .duplicate:
                    VStack(spacing: 8) {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                        Text("Already in your library")
                            .font(.headline)
                    }
                    .padding(.vertical, 12)
                    .task {
                        try? await Task.sleep(nanoseconds: 1_200_000_000)
                        onComplete()
                    }

                case .offlineQueued:
                    VStack(spacing: 8) {
                        Image(systemName: "icloud.and.arrow.up")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        Text("Saved Offline")
                            .font(.headline)
                        Text("We'll process it when you're online.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 12)
                    .task {
                        try? await Task.sleep(nanoseconds: 1_200_000_000)
                        onComplete()
                    }

                case .unsupported:
                    VStack(spacing: 8) {
                        Image(systemName: "link.badge.plus")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("This link isn't currently supported.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                        Button("Dismiss", action: onCancel)
                            .buttonStyle(.bordered)
                            .padding(.top, 4)
                    }
                    .padding(.vertical, 12)

                case .error(let msg):
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.red)
                        Text("Couldn't save Reel")
                            .font(.headline)
                        Text(msg)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Dismiss", action: onCancel)
                            .buttonStyle(.bordered)
                            .padding(.top, 4)
                    }
                    .padding(.vertical, 12)
                }
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
            .padding(.horizontal, 32)
        }
        .task {
            await handleShare()
        }
    }

    private var isSaving: Bool {
        if case .saving = state { return true }
        if case .extracting = state { return true }
        return false
    }

    private func handleShare() async {
        guard let url = await ShareExtractor.extractURL(from: extensionContext) else {
            state = .unsupported
            return
        }

        guard URLValidator.isValidInstagramURL(url) else {
            state = .unsupported
            return
        }

        state = .saving
        let result = await BackendClient.shared.submitReel(url: url)

        switch result {
        case .success:
            state = .success
        case .duplicate:
            state = .duplicate
        case .offlineQueued:
            state = .offlineQueued
        case .error(let msg):
            state = .error(msg)
        }
    }
}
