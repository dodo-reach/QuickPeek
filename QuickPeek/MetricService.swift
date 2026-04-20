import Foundation

struct MetricService {
    private static let decoder = JSONDecoder()
    
    static func fetchMetric(for tracker: Tracker, youtubeKey: String, xToken: String) async throws -> Int {
        switch tracker.category {
        case .githubStars, .githubForks, .githubWatchers:
            return try await fetchGitHub(url: tracker.urlOrID, category: tracker.category)
        case .redditSubscribers, .redditTotalKarma, .redditPostUpvotes:
            return try await fetchReddit(url: tracker.urlOrID, category: tracker.category)
        case .youtubeSubscribers:
            if !youtubeKey.isEmpty {
                return try await fetchYouTubeAPI(id: tracker.urlOrID, key: youtubeKey)
            } else {
                return try await WebScraper.fetchYouTubeSubs(channelID: tracker.urlOrID)
            }
        case .xFollowers, .xPostLikes:
            if !xToken.isEmpty {
                return try await fetchXAPI(urlOrID: tracker.urlOrID, category: tracker.category, token: xToken)
            } else {
                let username = URLCleaner.cleanXUsername(tracker.urlOrID)
                return try await WebScraper.fetchXMetric(username: username, category: tracker.category)
            }
        case .npmDownloads:
            return try await fetchNpm(packageName: tracker.urlOrID)
        case .discordMembers, .discordOnline:
            return try await fetchDiscord(inviteCode: tracker.urlOrID, category: tracker.category)
        case .instagramFollowers, .instagramLikes, .instagramComments:
            let handle = URLCleaner.cleanInstagramHandle(tracker.urlOrID)
            return try await WebScraper.fetchInstagramMetric(handle: handle, category: tracker.category)
        }
    }
    
    // MARK: - API Methods
    
    private static func fetchGitHub(url: String, category: MetricCategory) async throws -> Int {
        let repoPath = URLCleaner.cleanGitHubPath(url)
        guard let apiURL = URL(string: "https://api.github.com/repos/\(repoPath)") else { throw APIError.badURL }
        let data = try await fetchData(from: apiURL)
        let repo = try decoder.decode(GitHubRepo.self, from: data)
        switch category {
        case .githubStars: return repo.stargazers_count
        case .githubForks: return repo.forks_count
        case .githubWatchers: return repo.subscribers_count
        default: return 0
        }
    }
    
    private static func fetchReddit(url: String, category: MetricCategory) async throws -> Int {
        guard let name = URLCleaner.cleanRedditHandle(url) else { throw APIError.badURL }
        let endpoint: String
        switch category {
        case .redditSubscribers: endpoint = "r/\(name)/about.json"
        case .redditTotalKarma: endpoint = "user/\(name)/about.json"
        case .redditPostUpvotes:
            let id = url.components(separatedBy: "/comments/").last?.components(separatedBy: "/").first ?? url
            endpoint = "comments/\(id)/.json"
        default: throw APIError.badURL
        }
        
        let data = try await fetchData(from: URL(string: "https://www.reddit.com/\(endpoint)")!)
        if category == .redditSubscribers {
            return try decoder.decode(RedditSubResponse.self, from: data).data.subscribers
        } else if category == .redditTotalKarma {
            return try decoder.decode(RedditUserResponse.self, from: data).data.total_karma
        } else {
            let response = try decoder.decode([RedditPostResponse].self, from: data)
            return response.first?.data.children.first?.data.score ?? 0
        }
    }
    
    private static func fetchYouTubeAPI(id: String, key: String) async throws -> Int {
        let url = URL(string: "https://youtube.googleapis.com/youtube/v3/channels?part=statistics&id=\(id)&key=\(key)")!
        let data = try await fetchData(from: url)
        let response = try decoder.decode(YouTubeResponse.self, from: data)
        return Int(response.items.first?.statistics.subscriberCount ?? "0") ?? 0
    }
    
    private static func fetchXAPI(urlOrID: String, category: MetricCategory, token: String) async throws -> Int {
        let apiURL: URL
        if category == .xFollowers {
            let username = URLCleaner.cleanXUsername(urlOrID)
            apiURL = URL(string: "https://api.twitter.com/2/users/by/username/\(username)?user.fields=public_metrics")!
        } else {
            let id = urlOrID.components(separatedBy: "/status/").last?.components(separatedBy: "/").first ?? urlOrID
            apiURL = URL(string: "https://api.twitter.com/2/tweets/\(id.trimmingCharacters(in: .whitespacesAndNewlines))?tweet.fields=public_metrics")!
        }
        
        let data = try await fetchData(from: apiURL, token: token)
        if category == .xFollowers {
            return try decoder.decode(XUserResponse.self, from: data).data.public_metrics.followers_count
        } else {
            return try decoder.decode(XTweetResponse.self, from: data).data.public_metrics.like_count
        }
    }
    
    private static func fetchNpm(packageName: String) async throws -> Int {
        let name = URLCleaner.cleanNpmName(packageName)
        let url = URL(string: "https://api.npmjs.org/downloads/point/last-week/\(name)")!
        let data = try await fetchData(from: url)
        let response = try decoder.decode(NpmResponse.self, from: data)
        return response.downloads
    }
    
    private static func fetchDiscord(inviteCode: String, category: MetricCategory) async throws -> Int {
        let code = URLCleaner.cleanDiscordCode(inviteCode)
        let url = URL(string: "https://discord.com/api/v9/invites/\(code)?with_counts=true")!
        let data = try await fetchData(from: url)
        let response = try decoder.decode(DiscordInviteResponse.self, from: data)
        return category == .discordMembers ? response.approximate_member_count : response.approximate_presence_count
    }
    
    // MARK: - Base Fetcher
    
    private static func fetchData(from url: URL, token: String? = nil) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("QuickPeek/1.0", forHTTPHeaderField: "User-Agent")
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 15
        
        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw APIError.http(httpResponse.statusCode)
        }
        return data
    }
}
