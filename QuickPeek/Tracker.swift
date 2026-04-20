import Foundation

struct Tracker: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var urlOrID: String
    var type: MetricType
    var category: MetricCategory
    var count: Int = 0
    var lastCount: Int? = nil
    var lastUpdated: Date? = nil
    var lastErrorMessage: String? = nil
    
    var isError: Bool {
        lastErrorMessage != nil
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, urlOrID, type, category, count, lastCount, lastUpdated, lastErrorMessage
    }
    
    init(name: String, urlOrID: String, type: MetricType, category: MetricCategory) {
        self.name = name
        self.urlOrID = urlOrID
        self.type = type
        self.category = category
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        urlOrID = try container.decode(String.self, forKey: .urlOrID)
        type = try container.decode(MetricType.self, forKey: .type)
        category = try container.decodeIfPresent(MetricCategory.self, forKey: .category) ?? type.availableCategories.first ?? .githubStars
        count = try container.decodeIfPresent(Int.self, forKey: .count) ?? 0
        lastCount = try container.decodeIfPresent(Int.self, forKey: .lastCount)
        lastUpdated = try container.decodeIfPresent(Date.self, forKey: .lastUpdated)
        lastErrorMessage = try container.decodeIfPresent(String.self, forKey: .lastErrorMessage)
    }
}

enum MetricType: String, Codable, CaseIterable, Identifiable {
    case github, reddit, youtube, x, npm, discord, instagram
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .github: return "GitHub"
        case .reddit: return "Reddit"
        case .youtube: return "YouTube"
        case .x: return "X (Twitter)"
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
        case .npm: return "shippingbox.fill"
        case .discord: return "bubble.left.and.bubble.right.fill"
        case .instagram: return "camera.fill"
        }
    }
    
    var availableCategories: [MetricCategory] {
        switch self {
        case .github: return [.githubStars, .githubForks, .githubWatchers]
        case .reddit: return [.redditSubscribers, .redditTotalKarma, .redditPostUpvotes]
        case .youtube: return [.youtubeSubscribers]
        case .x: return [.xFollowers, .xPostLikes]
        case .npm: return [.npmDownloads]
        case .discord: return [.discordMembers, .discordOnline]
        case .instagram: return [.instagramFollowers, .instagramLikes, .instagramComments]
        }
    }
}

enum MetricCategory: String, Codable, CaseIterable, Identifiable {
    case githubStars, githubForks, githubWatchers
    case redditSubscribers, redditTotalKarma, redditPostUpvotes
    case youtubeSubscribers
    case xFollowers, xPostLikes
    case npmDownloads
    case discordMembers, discordOnline
    case instagramFollowers, instagramLikes, instagramComments
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .githubStars: return "Stars"
        case .githubForks: return "Forks"
        case .githubWatchers: return "Watchers"
        case .redditSubscribers: return "Subscribers"
        case .redditTotalKarma: return "Karma"
        case .redditPostUpvotes: return "Upvotes"
        case .youtubeSubscribers: return "Subscribers"
        case .xFollowers: return "Followers"
        case .xPostLikes: return "Likes"
        case .npmDownloads: return "Downloads (Week)"
        case .discordMembers: return "Members"
        case .discordOnline: return "Online"
        case .instagramFollowers: return "Followers"
        case .instagramLikes: return "Likes"
        case .instagramComments: return "Comments"
        }
    }
}
