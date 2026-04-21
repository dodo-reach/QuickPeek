import Foundation

// MARK: - Generic
enum APIError: LocalizedError {
    case badURL
    case missingKey(String)
    case http(Int)
    case rateLimited(status: Int, retryAfter: String?)
    case sourceFormatChanged(source: String, detail: String)
    case incompleteResponse(source: String, detail: String)
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .badURL: return "Invalid URL or ID"
        case .missingKey(let platform): return "Missing API Key for \(platform)"
        case .http(let status): return "Server error: \(status)"
        case .rateLimited(let status, let retryAfter):
            if let retryAfter, !retryAfter.isEmpty {
                return "Rate limited (\(status)). Retry after \(retryAfter)s"
            }
            return "Rate limited (\(status))"
        case .sourceFormatChanged(let source, let detail):
            return "\(source) format changed: \(detail)"
        case .incompleteResponse(let source, let detail):
            return "\(source) response incomplete: \(detail)"
        case .decodingError: return "Failed to parse server response"
        }
    }
}

// MARK: - GitHub
struct GitHubRepo: Codable {
    let stargazers_count: Int
    let forks_count: Int
    let subscribers_count: Int
}

struct GitHubSearchResponse: Codable {
    let total_count: Int
}

// MARK: - Reddit
struct RedditSubResponse: Codable {
    struct DataObj: Codable { let subscribers: Int }
    let data: DataObj
}

struct RedditUserResponse: Codable {
    struct DataObj: Codable { let total_karma: Int }
    let data: DataObj
}

struct RedditPostResponse: Codable {
    struct DataObj: Codable {
        struct Child: Codable {
            struct ChildData: Codable { let score: Int }
            let data: ChildData
        }
        let children: [Child]
    }
    let data: DataObj
}

// MARK: - X (Twitter)
struct XUserResponse: Codable {
    struct DataObj: Codable {
        struct Metrics: Codable { let followers_count: Int }
        let public_metrics: Metrics
    }
    let data: DataObj
}

struct XTweetResponse: Codable {
    struct DataObj: Codable {
        struct Metrics: Codable { let like_count: Int }
        let public_metrics: Metrics
    }
    let data: DataObj
}

// MARK: - Bluesky
struct BlueskyProfileResponse: Codable {
    let followersCount: Int
    let postsCount: Int
}

// MARK: - YouTube
struct YouTubeResponse: Codable {
    struct Item: Codable {
        struct Stats: Codable { let subscriberCount: String }
        let statistics: Stats
    }
    let items: [Item]
}

// MARK: - npm
struct NpmResponse: Codable {
    let downloads: Int
}

// MARK: - Discord
struct DiscordInviteResponse: Codable {
    let approximate_member_count: Int
    let approximate_presence_count: Int
}

// MARK: - Instagram
struct InstagramProfileResponse: Codable {
    struct DataObj: Codable {
        struct User: Codable {
            struct EdgeFollowers: Codable { let count: Int }
            let edge_followed_by: EdgeFollowers
        }
        let user: User
    }
    let data: DataObj
}
