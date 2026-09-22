import Foundation
import Supabase
import SwiftData

@MainActor
public final class RealtimeService {
    public static let shared = RealtimeService()

    private var channel: RealtimeChannelV2?
    private var isSubscribed = false

    private init() {}

    public func subscribe(onUpdate: @escaping @Sendable (String, ProcessingStatus) -> Void) async {
        guard !isSubscribed else { return }
        guard !SupabaseConfig.anonKey.isEmpty else { return }

        let client = SupabaseService.shared.client
        let channel = client.channel("public:reels")
        self.channel = channel

        let changeStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "reels"
        )

        do {
            await channel.subscribe()
            self.isSubscribed = true

            Task {
                for await change in changeStream {
                    switch change {
                    case .update(let action):
                        if let recordId = action.record["id"]?.stringValue,
                           let statusStr = action.record["status"]?.stringValue,
                           let status = ProcessingStatus(rawValue: statusStr) {
                            await MainActor.run {
                                onUpdate(recordId, status)
                            }
                        }
                    default:
                        break
                    }
                }
            }
        } catch {
            print("Failed to subscribe to Realtime events: \(error)")
        }
    }

    public func unsubscribe() async {
        if let channel {
            await SupabaseService.shared.client.removeChannel(channel)
            self.isSubscribed = false
        }
    }
}
