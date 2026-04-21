import Foundation

struct Tracker: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var urlOrID: String
    var type: MetricType
    var metrics: [MetricValue]
    var lastUpdated: Date? = nil
    
    var isError: Bool {
        metrics.contains { $0.lastErrorMessage != nil }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, urlOrID, type, metrics, lastUpdated
    }
    
    // Default coding keys for legacy migration
    enum LegacyCodingKeys: String, CodingKey {
        case id, name, urlOrID, type, category, count, lastCount, lastUpdated, lastErrorMessage
    }
    
    init(name: String, urlOrID: String, type: MetricType, metrics: [MetricValue]) {
        self.name = name
        self.urlOrID = urlOrID
        self.type = type
        self.metrics = metrics
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        urlOrID = try container.decode(String.self, forKey: .urlOrID)
        type = try container.decode(MetricType.self, forKey: .type)
        lastUpdated = try container.decodeIfPresent(Date.self, forKey: .lastUpdated)
        
        if let metrics = try container.decodeIfPresent([MetricValue].self, forKey: .metrics) {
            self.metrics = metrics
        } else {
            // Migration: handle single-metric legacy tracker
            let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)
            let category = try legacyContainer.decodeIfPresent(MetricCategory.self, forKey: .category) ?? type.availableCategories.first ?? .githubStars
            let count = try legacyContainer.decodeIfPresent(Int.self, forKey: .count) ?? 0
            let lastCount = try legacyContainer.decodeIfPresent(Int.self, forKey: .lastCount)
            let lastError = try legacyContainer.decodeIfPresent(String.self, forKey: .lastErrorMessage)
            
            self.metrics = [MetricValue(category: category, count: count, lastCount: lastCount, lastErrorMessage: lastError)]
        }
    }
}

struct MetricValue: Identifiable, Codable, Equatable {
    var id: String { category.rawValue }
    var category: MetricCategory
    var count: Int = 0
    var lastCount: Int? = nil
    var lastErrorMessage: String? = nil
}

enum MetricType: String, Codable, CaseIterable, Identifiable {
    case github, reddit, youtube, x, bluesky, npm, discord, instagram
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .github: return "GitHub"
        case .reddit: return "Reddit"
        case .youtube: return "YouTube"
        case .x: return "X (Twitter)"
        case .bluesky: return "Bluesky"
        case .npm: return "npm"
        case .discord: return "Discord"
        case .instagram: return "Instagram"
        }
    }
    
    var icon: String {
        switch self {
        case .github: return "star.fill"
        case .reddit: return "r.circle.fill"
        case .youtube: return "play.rectangle.fill"
        case .x: return "bird.fill"
        case .bluesky: return "cloud.fill"
        case .npm: return "shippingbox.fill"
        case .discord: return "bubble.left.and.bubble.right.fill"
        case .instagram: return "camera.fill"
        }
    }
    
    var availableCategories: [MetricCategory] {
        switch self {
        case .github: return [.githubStars, .githubForks, .githubWatchers, .githubIssues, .githubPullRequests]
        case .reddit: return [.redditSubscribers, .redditTotalKarma, .redditPostUpvotes]
        case .youtube: return [.youtubeSubscribers]
        case .x: return [.xFollowers, .xPostLikes]
        case .bluesky: return [.blueskyFollowers, .blueskyPosts]
        case .npm: return [.npmDownloads]
        case .discord: return [.discordMembers, .discordOnline]
        case .instagram: return [.instagramFollowers, .instagramLikes, .instagramComments]
        }
    }

    var hasExclusiveSourceModes: Bool {
        Set(availableCategories.map(\.selectionGroup)).count > 1
    }
}

enum MetricCategory: String, Codable, CaseIterable, Identifiable {
    case githubStars, githubForks, githubWatchers, githubIssues, githubPullRequests
    case redditSubscribers, redditTotalKarma, redditPostUpvotes
    case youtubeSubscribers
    case xFollowers, xPostLikes
    case blueskyFollowers, blueskyPosts
    case npmDownloads
    case discordMembers, discordOnline
    case instagramFollowers, instagramLikes, instagramComments
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .githubStars: return "Stars"
        case .githubForks: return "Forks"
        case .githubWatchers: return "Watchers"
        case .githubIssues: return "Issues"
        case .githubPullRequests: return "Pull Requests"
        case .redditSubscribers: return "Subscribers"
        case .redditTotalKarma: return "Karma"
        case .redditPostUpvotes: return "Upvotes"
        case .youtubeSubscribers: return "Subscribers"
        case .xFollowers: return "Followers"
        case .xPostLikes: return "Likes"
        case .blueskyFollowers: return "Followers"
        case .blueskyPosts: return "Posts"
        case .npmDownloads: return "Weekly Downloads"
        case .discordMembers: return "Total Members"
        case .discordOnline: return "Online Now"
        case .instagramFollowers: return "Followers"
        case .instagramLikes: return "Likes"
        case .instagramComments: return "Comments"
        }
    }

    var selectionGroup: MetricSelectionGroup {
        switch self {
        case .githubStars, .githubForks, .githubWatchers, .githubIssues, .githubPullRequests:
            return .repository
        case .redditSubscribers:
            return .subreddit
        case .redditTotalKarma:
            return .userProfile
        case .redditPostUpvotes:
            return .post
        case .youtubeSubscribers:
            return .channel
        case .xFollowers:
            return .profile
        case .xPostLikes:
            return .post
        case .blueskyFollowers, .blueskyPosts:
            return .profile
        case .npmDownloads:
            return .package
        case .discordMembers, .discordOnline:
            return .invite
        case .instagramFollowers:
            return .profile
        case .instagramLikes, .instagramComments:
            return .post
        }
    }
}

enum MetricSelectionGroup: String, Codable {
    case repository
    case subreddit
    case userProfile
    case channel
    case profile
    case post
    case package
    case invite
}
