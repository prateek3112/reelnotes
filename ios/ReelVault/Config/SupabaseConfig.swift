import Foundation

public enum SupabaseConfig {
    public static var url: URL {
        URL(string: SharedStorage.shared.supabaseURLString) ?? URL(string: "https://fpmnkmavkqshgndzhxwl.supabase.co")!
    }

    public static var anonKey: String {
        let key = SharedStorage.shared.supabaseAnonKey
        return key.isEmpty ? "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZwbW5rbWF2a3FzaGduZHpoeHdsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAwOTg5NTEsImV4cCI6MjEwNTY3NDk1MX0.xbd1x0fukhOMYCJ2ELDNal6FWYRN6vzbPfI4DcY-U-Y" : key
    }

    public static var apiBaseURL: URL {
        URL(string: SharedStorage.shared.apiBaseURLString) ?? URL(string: "https://reelnotes-7cld.onrender.com")!
    }

    public static var apiKey: String {
        SharedStorage.shared.apiKey
    }
}
