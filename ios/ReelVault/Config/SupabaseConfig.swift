import Foundation

public enum SupabaseConfig {
    // Configurable through SharedStorage or defaults
    public static var url: URL {
        URL(string: SharedStorage.shared.supabaseURLString) ?? URL(string: "https://your-project.supabase.co")!
    }

    public static var anonKey: String {
        SharedStorage.shared.supabaseAnonKey
    }

    public static var apiBaseURL: URL {
        URL(string: SharedStorage.shared.apiBaseURLString) ?? URL(string: "http://localhost:8000")!
    }

    public static var apiKey: String {
        SharedStorage.shared.apiKey
    }
}
