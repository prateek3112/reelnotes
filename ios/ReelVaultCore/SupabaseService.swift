import Foundation
import Supabase

public final class SupabaseService: @unchecked Sendable {
    public static let shared = SupabaseService()

    public private(set) var client: SupabaseClient

    private init() {
        self.client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey
        )
    }

    public func reconfigure(url: URL, anonKey: String) {
        self.client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: anonKey
        )
    }
}
