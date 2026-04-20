import Foundation

struct WebScraper {
    private static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    
    static func fetchYouTubeSubs(channelID: String) async throws -> Int {
        let urlString = channelID.hasPrefix("@") ? "https://www.youtube.com/\(channelID)" : "https://www.youtube.com/channel/\(channelID)"
        guard let url = URL(string: urlString) else { throw APIError.badURL }
        
        let html = try await fetchHTML(from: url)
        
        // Pattern: "subscriberCountText":{"simpleText":"1.23M subscribers"}
        let pattern = "\"subscriberCountText\":\\{\"simpleText\":\"([^\"]+)\"\\}"
        return try parseCount(from: html, pattern: pattern)
    }
    
    static func fetchXMetric(username: String, category: MetricCategory) async throws -> Int {
        if category == .xFollowers {
            guard let url = URL(string: "https://x.com/\(username)") else { throw APIError.badURL }
            let html = try await fetchHTML(from: url)
            let pattern = "\"followers_count\":([0-9]+)"
            return try parseCount(from: html, pattern: pattern)
        } else {
            // Liked tweets usually require a more specialized syndication endpoint
            throw APIError.http(403)
        }
    }
    
    static func fetchInstagramMetric(handle: String, category: MetricCategory) async throws -> Int {
        // Try exact count first for followers
        if category == .instagramFollowers {
            if let count = try? await fetchInstagramExactCount(handle: handle) {
                return count
            }
        }
        
        let urlString = "https://www.instagram.com/\(handle)/"
        guard let url = URL(string: urlString) else { throw APIError.badURL }
        
        let html = try await fetchHTML(from: url, headers: ["User-Agent": "facebookexternalhit/1.1"])
        
        let pattern: String
        switch category {
        case .instagramFollowers: pattern = "([0-9.,KMB]+) Followers"
        case .instagramLikes: pattern = "([0-9.,KMB]+) likes"
        case .instagramComments: pattern = "([0-9.,KMB]+) comments"
        default: throw APIError.badURL
        }
        
        return try parseCount(from: html, pattern: pattern)
    }
    
    // MARK: - Helpers
    
    private static func fetchHTML(from url: URL, headers: [String: String] = [:]) async throws -> String {
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.timeoutInterval = 15
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.http((response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        
        guard let html = String(data: data, encoding: .utf8) else {
            throw APIError.decodingError
        }
        return html
    }
    
    private static func fetchInstagramExactCount(handle: String) async throws -> Int {
        let url = URL(string: "https://i.instagram.com/api/v1/users/web_profile_info/?username=\(handle)")!
        let data = try await fetchDataWithMobileHeaders(from: url)
        let response = try JSONDecoder().decode(InstagramProfileResponse.self, from: data)
        return response.data.user.edge_followed_by.count
    }
    
    private static func fetchDataWithMobileHeaders(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("936619743392459", forHTTPHeaderField: "X-IG-App-ID")
        request.setValue("198387", forHTTPHeaderField: "X-ASBD-ID")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.http((response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        return data
    }
    
    private static func parseCount(from html: String, pattern: String) throws -> Int {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else {
            throw APIError.decodingError
        }
        
        return parseRoundedCount(String(html[range]))
    }
    
    static func parseRoundedCount(_ string: String) -> Int {
        var cleaned = string.lowercased()
            .replacingOccurrences(of: " subscribers", with: "")
            .replacingOccurrences(of: " iscritti", with: "")
            .replacingOccurrences(of: " follower", with: "")
            .replacingOccurrences(of: " followers", with: "")
            .replacingOccurrences(of: " likes", with: "")
            .replacingOccurrences(of: " mi piace", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: " ", with: "") // non-breaking space
        
        let hasMultiplier = cleaned.contains("k") || cleaned.contains("m") || cleaned.contains("b")
        
        if hasMultiplier {
            cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
            let multiplier: Double
            if cleaned.contains("b") { multiplier = 1_000_000_000; cleaned = cleaned.replacingOccurrences(of: "b", with: "") }
            else if cleaned.contains("m") { multiplier = 1_000_000; cleaned = cleaned.replacingOccurrences(of: "m", with: "") }
            else if cleaned.contains("k") { multiplier = 1_000; cleaned = cleaned.replacingOccurrences(of: "k", with: "") }
            else { multiplier = 1 }
            
            if let val = Double(cleaned) { return Int(val * multiplier) }
        } else {
            cleaned = cleaned.replacingOccurrences(of: ".", with: "")
            cleaned = cleaned.replacingOccurrences(of: ",", with: "")
            if let val = Int(cleaned) { return val }
        }
        
        return 0
    }
}
