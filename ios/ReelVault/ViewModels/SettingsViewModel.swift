import Foundation
import Observation

@Observable
public final class SettingsViewModel {
    public var apiBaseURL: String = ""
    public var apiKey: String = ""
    public var supabaseURL: String = ""
    public var supabaseAnonKey: String = ""

    public var serverStatus: String = "Checking..."
    public var isConnected: Bool = false
    public var isTesting: Bool = false

    public init() {
        self.apiBaseURL = SharedStorage.shared.apiBaseURLString
        self.apiKey = SharedStorage.shared.apiKey
        self.supabaseURL = SharedStorage.shared.supabaseURLString
        self.supabaseAnonKey = SharedStorage.shared.supabaseAnonKey
    }

    public func saveSettings() {
        SharedStorage.shared.apiBaseURLString = apiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        SharedStorage.shared.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        SharedStorage.shared.supabaseURLString = supabaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        SharedStorage.shared.supabaseAnonKey = supabaseAnonKey.trimmingCharacters(in: .whitespacesAndNewlines)

        if let url = URL(string: SharedStorage.shared.supabaseURLString) {
            SupabaseService.shared.reconfigure(url: url, anonKey: SharedStorage.shared.supabaseAnonKey)
        }
    }

    @MainActor
    public func testConnection() async {
        isTesting = true
        serverStatus = "Testing..."

        guard let url = URL(string: apiBaseURL)?.appendingPathComponent("api/v1/healthz") else {
            serverStatus = "Invalid URL"
            isConnected = false
            isTesting = false
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                serverStatus = "Connected ✓"
                isConnected = true
            } else {
                serverStatus = "HTTP Error \((response as? HTTPURLResponse)?.statusCode ?? 0)"
                isConnected = false
            }
        } catch {
            serverStatus = "Unreachable"
            isConnected = false
        }
        isTesting = false
    }
}
