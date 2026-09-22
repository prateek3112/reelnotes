import SwiftUI
import SwiftData

@main
struct ReelVaultApp: App {
    @Environment(\.scenePhase) private var scenePhase

    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: ReelItem.self)
        } catch {
            fatalError("Could not initialize ModelContainer for ReelVault: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                // Whenever app becomes active, flush pending shares from Share Extension
                Task { @MainActor in
                    await ReelRepository.shared.flushPendingShares(context: modelContainer.mainContext)
                }
            }
        }
    }
}
