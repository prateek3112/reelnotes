import SwiftUI

public struct EmptyStateView: View {
    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles.tv")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Your Reel Vault is empty")
                .font(.title2)
                .fontWeight(.bold)

            VStack(spacing: 8) {
                Text("Save any Instagram Reel by tapping:")
                    .foregroundColor(.secondary)

                HStack(spacing: 6) {
                    Text("Share")
                        .fontWeight(.semibold)
                    Image(systemName: "arrow.right")
                        .font(.caption)
                    Text("ReelVault")
                        .fontWeight(.semibold)
                        .foregroundColor(.accentColor)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)

                Text("We'll automatically transcribe and organize it.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .multilineTextAlignment(.center)
        .padding(40)
    }
}
