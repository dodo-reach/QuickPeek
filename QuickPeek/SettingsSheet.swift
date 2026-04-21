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
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    settingsSection {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("YOUTUBE API (OPTIONAL)")
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)

                            TextField("API Key", text: $viewModel.youtubeAPIKey)
                                .textFieldStyle(.plain)
                                .padding(12)
                                .background(fieldBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                            Link(destination: URL(string: "https://console.cloud.google.com/apis/library/youtube.googleapis.com")!) {
                                HStack {
                                    Text("Create API key")
                                    Image(systemName: "arrow.up.right.square")
                                }
                                .font(.subheadline)
                                .foregroundStyle(Color.accentColor)
                            }
                        }
                    }

                    settingsSection {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("X TOKEN (OPTIONAL)")
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)

                            SecureField("Bearer Token", text: $viewModel.xBearerToken)
                                .textFieldStyle(.plain)
                                .padding(12)
                                .background(fieldBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                            Link(destination: URL(string: "https://developer.twitter.com/en/portal/dashboard")!) {
                                HStack {
                                    Text("Open developer portal")
                                    Image(systemName: "arrow.up.right.square")
                                }
                                .font(.subheadline)
                                .foregroundStyle(Color.accentColor)
                            }
                        }
                    }

                    settingsSection {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("AUTOMATIC TRACKING")
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)

                            Text("QuickPeek works without API keys. Add them only if you need more reliable or more frequent updates.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Button(action: onDismiss) {
                        Text("Done")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(24)
        .background(sheetBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 24, y: 16)
        .compositingGroup()
    }

    private var fieldBackground: some ShapeStyle {
        Color.primary.opacity(0.06)
    }

    private var sheetBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(Color(nsColor: .windowBackgroundColor).opacity(0.98))
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.regularMaterial.opacity(0.96))
            )
    }

    private func settingsSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(.white.opacity(0.05), lineWidth: 1)
            )
    }
}
