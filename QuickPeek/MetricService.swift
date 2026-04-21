import Foundation
import OSLog

struct MetricService {
    private static let decoder = JSONDecoder()
    private static let logger = Logger(subsystem: "com.dodo-reach.QuickPeek", category: "tracking")
    
    static func fetchMetric(for urlOrID: String, category: MetricCategory, youtubeKey: String, xToken: String) async throws -> Int {
        switch category {
        case .githubStars, .githubForks, .githubWatchers, .githubIssues, .githubPullRequests:
            return try await fetchGitHub(url: urlOrID, category: category)
        case .redditSubscribers, .redditTotalKarma, .redditPostUpvotes:
            return try await fetchReddit(url: urlOrID, category: category)
        case .youtubeSubscribers:
            let identifier = URLCleaner.cleanYouTubeIdentifier(urlOrID)
            logger.info("Fetching YouTube subscribers for input=\(urlOrID, privacy: .public) normalized=\(identifier, privacy: .public) method=\(youtubeKey.isEmpty ? "scrape" : "api", privacy: .public)")
            if !youtubeKey.isEmpty {
                do {
                    return try await fetchYouTubeAPI(identifier: identifier, key: youtubeKey)
                } catch {
                    let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    logger.error("YouTube API fetch failed for normalized identifier=\(identifier, privacy: .public) error=\(message, privacy: .public). Falling back to scraper.")
                }
            }
            return try await WebScraper.fetchYouTubeSubs(identifier: identifier)
        case .xFollowers, .xPostLikes:
            if !xToken.isEmpty {
                return try await fetchXAPI(urlOrID: urlOrID, category: category, token: xToken)
            } else {
                return try await WebScraper.fetchXMetric(urlOrID: urlOrID, category: category)
            }
        case .blueskyFollowers, .blueskyPosts:
            return try await fetchBluesky(handleOrDID: urlOrID, category: category)
        case .npmDownloads:
            return try await fetchNpm(packageName: urlOrID)
        case .discordMembers, .discordOnline:
            return try await fetchDiscord(inviteCode: urlOrID, category: category)
        case .instagramFollowers, .instagramLikes, .instagramComments:
            let input = category == .instagramFollowers ? URLCleaner.cleanInstagramHandle(urlOrID) : URLCleaner.cleanInstagramPostURL(urlOrID)
            return try await WebScraper.fetchInstagramMetric(input: input, category: category)
        }
    }

    static func fetchGitHubMetrics(for urlOrID: String, categories: [MetricCategory]) async -> [MetricCategory: Result<Int, Error>] {
        let repoPath = URLCleaner.cleanGitHubPath(urlOrID)
        var results = [MetricCategory: Result<Int, Error>]()
        let uniqueCategories = Array(Set(categories))

        do {
            let repo = try await retrying("GitHub repo metadata", for: repoPath) {
                try await fetchGitHubRepo(path: repoPath)
            }

            for category in uniqueCategories {
                switch category {
                case .githubStars:
                    results[category] = .success(repo.stargazers_count)
                case .githubForks:
                    results[category] = .success(repo.forks_count)
                case .githubWatchers:
                    results[category] = .success(repo.subscribers_count)
                default:
                    break
                }
            }
        } catch {
            for category in uniqueCategories where category == .githubStars || category == .githubForks || category == .githubWatchers {
                results[category] = .failure(error)
            }
        }

        await withTaskGroup(of: (MetricCategory, Result<Int, Error>).self) { group in
            for category in uniqueCategories where category == .githubIssues || category == .githubPullRequests {
                group.addTask {
                    do {
                        let count = try await retrying("GitHub search", for: "\(repoPath)#\(category.rawValue)") {
                            try await fetchGitHubSearchCount(path: repoPath, category: category)
                        }
                        return (category, .success(count))
                    } catch {
                        do {
                            let count = try await WebScraper.fetchGitHubMetric(url: urlOrID, category: category)
                            return (category, .success(count))
                        } catch {
                            return (category, .failure(error))
                        }
                    }
                }
            }

            for await (category, result) in group {
                results[category] = result
            }
        }

        return results
    }
    
    // MARK: - API Methods
    
    private static func fetchGitHub(url: String, category: MetricCategory) async throws -> Int {
        let repoPath = URLCleaner.cleanGitHubPath(url)
        
        if category == .githubIssues || category == .githubPullRequests {
            do {
                return try await retrying("GitHub search", for: "\(repoPath)#\(category.rawValue)") {
                    try await fetchGitHubSearchCount(path: repoPath, category: category)
                }
            } catch {
                return try await WebScraper.fetchGitHubMetric(url: url, category: category)
            }
        }
        
        let repo = try await retrying("GitHub repo metadata", for: repoPath) {
            try await fetchGitHubRepo(path: repoPath)
        }
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
    
    private static func fetchYouTubeAPI(identifier: String, key: String) async throws -> Int {
        let param: String
        if identifier.hasPrefix("@") {
            let handle = String(identifier.dropFirst())
            guard let encodedHandle = handle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                throw APIError.badURL
            }
            param = "forHandle=\(encodedHandle)"
        } else {
            guard let encodedID = identifier.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                throw APIError.badURL
            }
            param = "id=\(encodedID)"
        }
        
        let url = URL(string: "https://youtube.googleapis.com/youtube/v3/channels?part=statistics&\(param)&key=\(key)")!
        let data = try await fetchData(from: url)
        let response = try decoder.decode(YouTubeResponse.self, from: data)
        if response.items.isEmpty {
            logger.error("YouTube API returned no channel items for normalized identifier=\(identifier, privacy: .public)")
            throw APIError.decodingError
        }
        
        guard let rawCount = response.items.first?.statistics.subscriberCount,
              let count = Int(rawCount) else {
            logger.error("YouTube API returned invalid subscriber count for normalized identifier=\(identifier, privacy: .public)")
            throw APIError.decodingError
        }
        
        return count
    }

    private static func fetchGitHubRepo(path: String) async throws -> GitHubRepo {
        guard let apiURL = URL(string: "https://api.github.com/repos/\(path)") else { throw APIError.badURL }
        let data = try await fetchData(from: apiURL)
        return try decoder.decode(GitHubRepo.self, from: data)
    }

    private static func fetchGitHubSearchCount(path: String, category: MetricCategory) async throws -> Int {
        let type = category == .githubIssues ? "issue" : "pr"
        let searchURLString = "https://api.github.com/search/issues?q=repo:\(path)+is:\(type)+is:open&per_page=1"
        guard let apiURL = URL(string: searchURLString) else { throw APIError.badURL }

        let data = try await fetchData(from: apiURL)
        let response = try decoder.decode(GitHubSearchResponse.self, from: data)
        return response.total_count
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

    private static func fetchBluesky(handleOrDID: String, category: MetricCategory) async throws -> Int {
        let actor = URLCleaner.cleanBlueskyHandle(handleOrDID)
        guard
            !actor.isEmpty,
            let encodedActor = actor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let url = URL(string: "https://public.api.bsky.app/xrpc/app.bsky.actor.getProfile?actor=\(encodedActor)")
        else {
            throw APIError.badURL
        }
        
        let data = try await fetchData(from: url)
        let response = try decoder.decode(BlueskyProfileResponse.self, from: data)
        switch category {
        case .blueskyFollowers:
            return response.followersCount
        case .blueskyPosts:
            return response.postsCount
        default:
            throw APIError.badURL
        }
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
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
            let remaining = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Remaining") ?? "-"
            let resource = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Resource") ?? "-"
            logger.error("HTTP request failed status=\(httpResponse.statusCode) url=\(url.absoluteString, privacy: .public) rateRemaining=\(remaining, privacy: .public) resource=\(resource, privacy: .public) retryAfter=\((retryAfter ?? "-"), privacy: .public)")

            if httpResponse.statusCode == 403 || httpResponse.statusCode == 429 {
                throw APIError.rateLimited(status: httpResponse.statusCode, retryAfter: retryAfter)
            }

            throw APIError.http(httpResponse.statusCode)
        }
        return data
    }

    private static func retrying<T>(_ operation: String, for subject: String, maxAttempts: Int = 3, action: @escaping () async throws -> T) async throws -> T {
        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                return try await action()
            } catch {
                lastError = error
                guard attempt < maxAttempts, shouldRetry(error) else { break }

                let delay = UInt64(350_000_000 * attempt)
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                logger.warning("\(operation, privacy: .public) retry attempt=\(attempt) subject=\(subject, privacy: .public) error=\(message, privacy: .public)")
                try? await Task.sleep(nanoseconds: delay)
            }
        }

        throw lastError ?? APIError.decodingError
    }

    private static func shouldRetry(_ error: Error) -> Bool {
        switch error as? APIError {
        case .decodingError:
            return true
        case .http(let status):
            return status >= 500
        case .rateLimited:
            return true
        default:
            return false
        }
    }
}
