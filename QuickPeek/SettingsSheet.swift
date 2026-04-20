import SwiftUI

struct SettingsSheet: View {
    @EnvironmentObject var viewModel: TrackerViewModel
    var onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Settings")
                    .font(.title2.bold())
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.top)
            
            VStack(alignment: .leading, spacing: 24) {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("YOUTUBE API KEY (OPTIONAL)")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                        
                        TextField("Enter your API Key", text: $viewModel.youtubeAPIKey)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color.primary.opacity(0.05))
                            .cornerRadius(10)
                        
                        Link(destination: URL(string: "https://console.cloud.google.com/apis/library/youtube.googleapis.com")!) {
                            HStack {
                                Text("Get a free key")
                                Image(systemName: "arrow.up.right.square")
                            }
                            .font(.subheadline)
                            .foregroundStyle(Color.accentColor)
                        }
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("X (TWITTER) BEARER TOKEN (OPTIONAL)")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                        
                        SecureField("Enter your Bearer Token", text: $viewModel.xBearerToken)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color.primary.opacity(0.05))
                            .cornerRadius(10)
                        
                        Link(destination: URL(string: "https://developer.twitter.com/en/portal/dashboard")!) {
                            HStack {
                                Text("Get a token (Free/Basic plan)")
                                Image(systemName: "arrow.up.right.square")
                            }
                            .font(.subheadline)
                            .foregroundStyle(Color.accentColor)
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("INFO")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    
                    Text("QuickPeek supports API-less tracking for YouTube, X, and Instagram. API keys are recommended only for higher accuracy and rate limit stability.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button(action: onDismiss) {
                    Text("Done")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .cornerRadius(24)
    }
}
