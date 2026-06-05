import SwiftUI

struct SettingsSheet: View {
    @EnvironmentObject var viewModel: TrackerViewModel
    var onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.title2.bold())
                Spacer()
                Button("Done", action: onDismiss)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(20)
            
            Form {
                Section("YouTube API (Optional)") {
                    SecureField("API Key", text: $viewModel.youtubeAPIKey)
                    Link("Create API key", destination: URL(string: "https://console.cloud.google.com/apis/library/youtube.googleapis.com")!)
                }

                Section("X Token (Optional)") {
                    SecureField("Bearer Token", text: $viewModel.xBearerToken)
                    Link("Open developer portal", destination: URL(string: "https://developer.twitter.com/en/portal/dashboard")!)
                }

                Section("Automatic Tracking") {
                    Text("QuickPeek works without API keys. Add them only if you need more reliable or more frequent updates.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal, 8)
        }
    }
}
