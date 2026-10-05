import Foundation

/// Manages shared persistence between the main ReelVault iOS application
/// and the ReelVault Share Extension using an App Group UserDefaults suite.
public final class SharedStorage: @unchecked Sendable {
    public static let shared = SharedStorage()

    public static let defaultAppGroupID = "group.com.reelvault.app"
    private let defaults: UserDefaults?

    private init(appGroupID: String = defaultAppGroupID) {
        self.defaults = UserDefaults(suiteName: appGroupID) ?? UserDefaults.standard
    }

    // MARK: - Configuration Keys

    public var apiBaseURLString: String {
        get { defaults?.string(forKey: "api_base_url") ?? "https://reelnotes-7cld.onrender.com" }
        set { defaults?.setValue(newValue, forKey: "api_base_url") }
    }

    public var apiKey: String {
        get { defaults?.string(forKey: "api_key") ?? "reelvault-secret-api-key" }
        set { defaults?.setValue(newValue, forKey: "api_key") }
    }

    public var supabaseURLString: String {
        get { defaults?.string(forKey: "supabase_url") ?? "https://fpmnkmavkqshgndzhxwl.supabase.co" }
        set { defaults?.setValue(newValue, forKey: "supabase_url") }
    }

    public var supabaseAnonKey: String {
        get { defaults?.string(forKey: "supabase_anon_key") ?? "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZwbW5rbWF2a3FzaGduZHpoeHdsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAwOTg5NTEsImV4cCI6MjEwNTY3NDk1MX0.xbd1x0fukhOMYCJ2ELDNal6FWYRN6vzbPfI4DcY-U-Y" }
        set { defaults?.setValue(newValue, forKey: "supabase_anon_key") }
    }

    // MARK: - Offline Pending Reels Queue

    public struct PendingReel: Codable, Identifiable {
        public var id: String { url }
        public let url: String
        public let timestamp: Double
    }

    public func appendPendingReel(url: String) {
        var list = fetchPendingReels()
        // Deduplicate
        if !list.contains(where: { $0.url == url }) {
            list.append(PendingReel(url: url, timestamp: Date().timeIntervalSince1970))
            savePendingReels(list)
        }
    }

    public func fetchPendingReels() -> [PendingReel] {
        guard let data = defaults?.data(forKey: "pending_reels"),
              let list = try? JSONDecoder().decode([PendingReel].self, from: data) else {
            return []
        }
        return list
    }

    public func removePendingReel(url: String) {
        var list = fetchPendingReels()
        list.removeAll(where: { $0.url == url })
        savePendingReels(list)
    }

    public func clearPendingReels() {
        defaults?.removeObject(forKey: "pending_reels")
    }

    private func savePendingReels(_ list: [PendingReel]) {
        if let encoded = try? JSONEncoder().encode(list) {
            defaults?.setValue(encoded, forKey: "pending_reels")
        }
    }
}
