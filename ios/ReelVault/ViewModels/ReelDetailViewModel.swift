import SwiftUI
import SwiftData
import Observation

@Observable
public final class ReelDetailViewModel {
    public var item: ReelItem
    public var showCopiedToast: Bool = false
    public var toastMessage: String = ""
    public var isRetrying: Bool = false
    public var errorMessage: String? = nil

    public init(item: ReelItem) {
        self.item = item
    }

    public func copyTranscript() {
        guard let text = item.cleanedTranscript ?? item.transcript else { return }
        UIPasteboard.general.string = text
        triggerToast("Transcript copied!")
    }

    public func copyHook() {
        guard let hook = item.hook else { return }
        UIPasteboard.general.string = hook
        triggerToast("Hook copied!")
    }

    public func openOriginal() {
        if let url = URL(string: item.originalUrl) {
            UIApplication.shared.open(url)
        }
    }

    @MainActor
    public func retry(context: ModelContext) async {
        isRetrying = true
        errorMessage = nil
        do {
            try await ReelRepository.shared.retryReel(id: item.id)
            item.status = .pending
            try? context.save()
            triggerToast("Processing re-queued!")
        } catch {
            errorMessage = error.localizedDescription
        }
        isRetrying = false
    }

    @MainActor
    public func delete(context: ModelContext) async -> Bool {
        do {
            try await ReelRepository.shared.deleteReel(id: item.id)
            context.delete(item)
            try? context.save()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func triggerToast(_ msg: String) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        toastMessage = msg
        withAnimation {
            showCopiedToast = true
        }
        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            await MainActor.run {
                withAnimation {
                    self.showCopiedToast = false
                }
            }
        }
    }
}
