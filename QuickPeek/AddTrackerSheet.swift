import SwiftUI

struct AddTrackerSheet: View {
    @EnvironmentObject var viewModel: TrackerViewModel
    var onDismiss: () -> Void
    
    @State private var urlOrID = ""
    @State private var selectedType: MetricType = .github
    @State private var selectedCategories: Set<MetricCategory> = [.githubStars]
    @State private var customName = ""
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Tracker")
                    .font(.title2.bold())
                Spacer()
                Button("Cancel", action: onDismiss)
            }
            .padding(20)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Service")
                            .font(.headline)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92))], spacing: 8) {
                            ForEach(MetricType.allCases) { type in
                                Button {
                                    selectedType = type
                                    selectedCategories = [type.availableCategories.first ?? .githubStars]
                                } label: {
                                    Label(type.displayName, systemImage: type.icon)
                                        .frame(maxWidth: .infinity)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .foregroundStyle(selectedType == type ? Color.white : Color.primary)
                                        .background(
                                            selectedType == type ? Color.accentColor : Color.primary.opacity(0.06),
                                            in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        )
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                                .strokeBorder(
                                                    selectedType == type ? Color.accentColor : Color.primary.opacity(0.12),
                                                    lineWidth: 1
                                                )
                                        }
                                }
                                .buttonStyle(.plain)
                                .controlSize(.small)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(selectedType.hasExclusiveSourceModes ? "Metric" : "Metrics to Track")
                            .font(.headline)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), alignment: .leading)], alignment: .leading, spacing: 8) {
                            ForEach(selectedType.availableCategories) { category in
                                Toggle(category.label, isOn: Binding(
                                    get: { selectedCategories.contains(category) },
                                    set: { _ in toggleCategory(category) }
                                ))
                                .toggleStyle(.button)
                                .controlSize(.small)
                            }
                        }

                        if let compatibilityNote {
                            Text(compatibilityNote)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(inputLabel.capitalized)
                            .font(.headline)

                        TextField(inputPlaceholder, text: $urlOrID)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: urlOrID) { _, newValue in
                                autoDetect(newValue)
                            }

                        Text(helpText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Display Name")
                            .font(.headline)

                        TextField("Optional nickname", text: $customName)
                            .textFieldStyle(.roundedBorder)
                    }

                    if selectedType == .instagram || selectedType == .tiktok {
                        Label(
                            selectedType == .tiktok ? "Only public profiles and videos are supported." : "Only public accounts and posts are supported.",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(.orange)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }

            Divider()

            HStack {
                Spacer()
                Button("Start Tracking") {
                    let orderedCategories = selectedType.availableCategories.filter { selectedCategories.contains($0) }
                    viewModel.addTracker(urlOrID: urlOrID, type: selectedType, categories: orderedCategories, customName: customName)
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(urlOrID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(20)
        }
    }

    private func toggleCategory(_ category: MetricCategory) {
        let sameGroupCategories = Set(selectedType.availableCategories.filter { $0.selectionGroup == category.selectionGroup })

        if selectedCategories.contains(category) {
            let selectedInSameGroup = selectedCategories.intersection(sameGroupCategories)
            if selectedCategories.count > 1 && selectedInSameGroup.count > 1 {
                selectedCategories.remove(category)
            }
            return
        }

        let hasIncompatibleSelection = !selectedCategories.isEmpty && selectedCategories.contains { $0.selectionGroup != category.selectionGroup }
        if hasIncompatibleSelection {
            selectedCategories = [category]
            return
        }

        selectedCategories.insert(category)
    }
    
    private func autoDetect(_ newValue: String) {
        let lower = newValue.lowercased()
        
        // Bare @handles are ambiguous across YouTube and X.
        // Once the user has explicitly picked a platform, keep that choice.
        if lower.hasPrefix("@") {
            switch selectedType {
            case .youtube:
                selectedCategories = [.youtubeSubscribers]
                return
            case .tiktok:
                selectedCategories = [.tiktokFollowers]
                return
            case .x:
                selectedCategories = [.xFollowers]
                return
            default:
                break
            }
        }
        
        if lower.contains("github.com") { 
            selectedType = .github 
            if selectedCategories.intersection(selectedType.availableCategories).isEmpty {
                selectedCategories = [.githubStars]
            }
        }
        else if lower.contains("reddit.com/") { 
            selectedType = .reddit 
            if lower.contains("/comments/") { selectedCategories = [.redditPostUpvotes] }
            else if lower.contains("/user/") || lower.contains("/u/") { selectedCategories = [.redditTotalKarma] }
            else { selectedCategories = [.redditSubscribers] }
        }
        else if lower.contains("youtube.com/watch") || lower.contains("youtube.com/shorts/") || lower.contains("youtu.be/") {
            selectedType = .youtube 
            selectedCategories = [.youtubeVideoViews]
        }
        else if lower.contains("youtube.com") || lower.hasPrefix("uc") {
            selectedType = .youtube
            selectedCategories = [.youtubeSubscribers]
        }
        else if lower.contains("tiktok.com") {
            selectedType = .tiktok
            if lower.contains("/video/") || (lower.contains("/embed/") && !lower.contains("/embed/@")) {
                selectedCategories = [.tiktokVideoViews]
            } else {
                selectedCategories = [.tiktokFollowers]
            }
        }
        else if lower.contains("x.com") || lower.contains("twitter.com") { 
            selectedType = .x 
            if lower.contains("/status/") { selectedCategories = [.xPostLikes] }
            else { selectedCategories = [.xFollowers] }
        }
        else if lower.contains("bsky.app/profile/") || lower.contains(".bsky.social") || lower.contains("did:plc:") {
            selectedType = .bluesky
            if selectedCategories.intersection(selectedType.availableCategories).isEmpty {
                selectedCategories = [.blueskyFollowers]
            }
        }
        else if lower.contains("npmjs.com") {
            selectedType = .npm
            selectedCategories = [.npmDownloads]
        }
        else if lower.contains("discord.gg") || lower.contains("discord.com/invite") {
            selectedType = .discord
            if selectedCategories.intersection(selectedType.availableCategories).isEmpty {
                selectedCategories = [.discordMembers]
            }
        }
        else if lower.contains("instagram.com") {
            selectedType = .instagram
            if lower.contains("/p/") || lower.contains("/reel/") || lower.contains("/reels/") {
                selectedCategories = [.instagramLikes]
            } else {
                selectedCategories = [.instagramFollowers]
            }
        }
    }
    
    private var inputLabel: String {
        switch selectedType {
        case .youtube: return selectedCategories.contains(.youtubeSubscribers) ? "CHANNEL" : "VIDEO"
        case .tiktok: return selectedCategories.contains(.tiktokFollowers) || selectedCategories.contains(.tiktokTotalLikes) ? "PROFILE" : "VIDEO"
        case .x: return selectedCategories.contains(.xFollowers) ? "USERNAME" : "POST LINK OR ID"
        case .bluesky: return "HANDLE OR PROFILE URL"
        case .npm: return "PACKAGE NAME OR URL"
        case .discord: return "INVITE LINK"
        case .instagram: return selectedCategories.contains(.instagramFollowers) ? "USERNAME" : "POST LINK"
        default: return "SOURCE URL"
        }
    }
    
    private var inputPlaceholder: String {
        switch selectedType {
        case .youtube:
            return selectedCategories.contains(.youtubeSubscribers) ? "@handle, channel URL, or UC..." : "watch URL, shorts URL, or video ID"
        case .tiktok:
            return selectedCategories.contains(.tiktokFollowers) || selectedCategories.contains(.tiktokTotalLikes) ? "@handle or profile URL" : "video URL or video ID"
        case .x: return selectedCategories.contains(.xFollowers) ? "@username" : "Post URL or ID"
        case .bluesky: return "@handle, handle.bsky.social, or bsky.app/profile/..."
        case .npm: return "e.g. react"
        case .discord: return "discord.gg/invite-code"
        case .instagram: return selectedCategories.contains(.instagramFollowers) ? "username" : "Post URL"
        default: return "https://..."
        }
    }
    
    private var helpText: String {
        switch selectedType {
        case .github: return "Enter a repository URL or path (e.g., owner/repo)."
        case .reddit: return "Enter a subreddit, user profile, or post link."
        case .x: return "Enter a profile handle (@name) or a direct status link."
        case .bluesky: return "Enter a Bluesky handle, DID, or profile URL."
        case .youtube:
            return selectedCategories.contains(.youtubeSubscribers)
                ? "Enter a handle, channel URL, or channel ID."
                : "Enter a public watch link, Shorts link, or video ID."
        case .tiktok:
            return selectedCategories.contains(.tiktokFollowers) || selectedCategories.contains(.tiktokTotalLikes)
                ? "Enter a public TikTok handle or profile URL."
                : "Enter a public TikTok video link or video ID."
        case .npm: return "Enter a package name or the full npmjs.com URL."
        case .discord: return "Paste a public invitation link."
        case .instagram: return "Enter a public profile username or a direct post link."
        }
    }

    private var compatibilityNote: String? {
        switch selectedType {
        case .reddit:
            return "Subreddit, user, and post metrics use different inputs, so only one mode can be active at a time."
        case .youtube:
            return "Channel subscribers and video likes/views come from different inputs, so choose one mode at a time."
        case .tiktok:
            return "Profile followers/total likes and video likes/views come from different public pages, so choose one mode at a time."
        case .x:
            return "Profile followers and post likes come from different inputs, so choose one mode at a time."
        case .instagram:
            return "Profile followers cannot be combined with post likes/comments."
        default:
            return nil
        }
    }
}
