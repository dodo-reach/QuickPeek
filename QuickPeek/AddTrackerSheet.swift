import SwiftUI

struct AddTrackerSheet: View {
    @EnvironmentObject var viewModel: TrackerViewModel
    var onDismiss: () -> Void
    
    @State private var urlOrID = ""
    @State private var selectedType: MetricType = .github
    @State private var selectedCategory: MetricCategory = .githubStars
    @State private var customName = ""
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("New Tracker")
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
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PLATFORM")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(MetricType.allCases) { type in
                                Button(action: { 
                                    selectedType = type 
                                    selectedCategory = type.availableCategories.first ?? .githubStars
                                }) {
                                    VStack(spacing: 8) {
                                        Image(systemName: type.icon)
                                            .font(.title2)
                                        Text(type.displayName)
                                            .font(.system(size: 10, weight: .bold))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(selectedType == type ? Color.accentColor : Color.primary.opacity(0.05))
                                    .foregroundStyle(selectedType == type ? .white : .primary)
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("METRIC")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                        
                        Picker("Metric", selection: $selectedCategory) {
                            ForEach(selectedType.availableCategories) { category in
                                Text(category.label).tag(category)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(inputLabel)
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                        
                        TextField(inputPlaceholder, text: $urlOrID)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color.primary.opacity(0.05))
                            .cornerRadius(10)
                            .onChange(of: urlOrID) { oldValue, newValue in
                                autoDetect(newValue)
                            }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CUSTOM NAME (OPTIONAL)")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                        
                        TextField("e.g. My Project", text: $customName)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color.primary.opacity(0.05))
                            .cornerRadius(10)
                    }
                    
                    Text(helpText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, -8)
                    
                    if selectedType == .instagram {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Only public accounts/posts are supported.")
                                .font(.caption.bold())
                                .foregroundStyle(.orange)
                        }
                        .padding(.top, -12)
                    }
                }
            }
            
            Spacer()
            
            Button(action: {
                viewModel.addTracker(urlOrID: urlOrID, type: selectedType, category: selectedCategory, customName: customName)
                onDismiss()
            }) {
                Text("Add Tracker")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(urlOrID.isEmpty ? Color.gray : Color.accentColor)
                    .cornerRadius(12)
                    .shadow(color: (urlOrID.isEmpty ? Color.clear : Color.accentColor).opacity(0.3), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(urlOrID.isEmpty)
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .cornerRadius(24)
    }
    
    private func autoDetect(_ newValue: String) {
        let lower = newValue.lowercased()
        if lower.contains("github.com") { 
            selectedType = .github 
            if !selectedType.availableCategories.contains(selectedCategory) {
                selectedCategory = .githubStars
            }
        }
        else if lower.contains("reddit.com/") { 
            selectedType = .reddit 
            if lower.contains("/comments/") { selectedCategory = .redditPostUpvotes }
            else if lower.contains("/user/") || lower.contains("/u/") { selectedCategory = .redditTotalKarma }
            else { selectedCategory = .redditSubscribers }
        }
        else if lower.contains("youtube.com") { 
            selectedType = .youtube 
            selectedCategory = .youtubeSubscribers
        }
        else if lower.contains("x.com") || lower.contains("twitter.com") || lower.hasPrefix("@") { 
            selectedType = .x 
            if lower.contains("/status/") { selectedCategory = .xPostLikes }
            else { selectedCategory = .xFollowers }
        }
        else if lower.contains("npmjs.com") {
            selectedType = .npm
            selectedCategory = .npmDownloads
        }
        else if lower.contains("discord.gg") || lower.contains("discord.com/invite") {
            selectedType = .discord
            if !selectedType.availableCategories.contains(selectedCategory) {
                selectedCategory = .discordMembers
            }
        }
        else if lower.contains("instagram.com") {
            selectedType = .instagram
            if lower.contains("/p/") || lower.contains("/reels/") {
                if selectedCategory != .instagramLikes && selectedCategory != .instagramComments {
                    selectedCategory = .instagramLikes
                }
            } else {
                selectedCategory = .instagramFollowers
            }
        }
    }
    
    private var inputLabel: String {
        switch selectedType {
        case .youtube: return "CHANNEL ID"
        case .x: return selectedCategory == .xFollowers ? "USERNAME (@...)" : "TWEET ID / LINK"
        case .npm: return "PACKAGE NAME / URL"
        case .discord: return "INVITE LINK"
        case .instagram: return selectedCategory == .instagramFollowers ? "USERNAME (@...)" : "POST LINK"
        default: return "FULL URL"
        }
    }
    
    private var inputPlaceholder: String {
        switch selectedType {
        case .youtube: return "UCxxxxxxxxxxxxxxxx"
        case .x: return selectedCategory == .xFollowers ? "@username" : "tweet_id or link"
        case .npm: return "e.g. express"
        case .discord: return "discord.gg/invite"
        case .instagram: return selectedCategory == .instagramFollowers ? "@username" : "https://instagram.com/p/..."
        default: return "https://..."
        }
    }
    
    private var helpText: String {
        switch selectedType {
        case .github: return "Examples:\n• https://github.com/owner/repo"
        case .reddit: return "Examples:\n• Subreddit\n• User profile\n• Direct post link (Upvotes)"
        case .x: return "Enter username (e.g. @elonmusk) for followers or post link for likes."
        case .youtube: return "Enter the Channel ID (e.g. UCxxxxxxxxxx)."
        case .npm: return "Enter the package name (e.g. 'react') or the npmjs URL."
        case .discord: return "Paste a public invite link (e.g. discord.gg/xxxxx)."
        case .instagram: return "Enter username (e.g. @cristiano) or direct link to a public post."
        }
    }
}
