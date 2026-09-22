import SwiftUI
import SwiftData

public struct SettingsView: View {
    @Query private var allItems: [ReelItem]
    @State private var viewModel = SettingsViewModel()

    public var body: some View {
        NavigationStack {
            Form {
                // Section 1: Server Status
                Section(header: Text("Processing Server")) {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(viewModel.serverStatus)
                            .foregroundColor(viewModel.isConnected ? .green : .secondary)
                            .fontWeight(.medium)
                    }

                    TextField("Backend URL", text: $viewModel.apiBaseURL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    SecureField("API Key", text: $viewModel.apiKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Button(action: {
                        viewModel.saveSettings()
                        Task { await viewModel.testConnection() }
                    }) {
                        if viewModel.isTesting {
                            ProgressView()
                        } else {
                            Text("Save & Test Connection")
                        }
                    }
                }

                // Section 2: Supabase Credentials
                Section(header: Text("Supabase Configuration")) {
                    TextField("Project URL", text: $viewModel.supabaseURL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    SecureField("Anon / Public Key", text: $viewModel.supabaseAnonKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Button("Save Supabase Settings") {
                        viewModel.saveSettings()
                    }
                }

                // Section 3: Library Stats
                Section(header: Text("Storage & Usage")) {
                    HStack {
                        Text("Total Saved Reels")
                        Spacer()
                        Text("\(allItems.count)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Ready")
                        Spacer()
                        Text("\(allItems.filter { $0.status == .completed }.count)")
                            .foregroundColor(.green)
                    }
                    HStack {
                        Text("Processing")
                        Spacer()
                        Text("\(allItems.filter { $0.status.isProcessing }.count)")
                            .foregroundColor(.blue)
                    }
                    HStack {
                        Text("Failed")
                        Spacer()
                        Text("\(allItems.filter { $0.status == .failed }.count)")
                            .foregroundColor(.red)
                    }
                }

                // Section 4: About
                Section(header: Text("About")) {
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text("1.0.0 (MVP)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Transcription Engine")
                        Spacer()
                        Text("faster-whisper (Small)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .task {
                await viewModel.testConnection()
            }
        }
    }
}
