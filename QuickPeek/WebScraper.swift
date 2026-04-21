import Foundation
import OSLog

struct WebScraper {
    private static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    private static let logger = Logger(subsystem: "com.dodo-reach.QuickPeek", category: "tracking")
    private static let youTubeConsentCookie = "SOCS=CAI"
    private static let youTubeAcceptLanguage = "en-US,en;q=0.9,it-IT;q=0.8,it;q=0.7"
    private static let diagnosticsDirectory = {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return baseURL
            .appendingPathComponent("QuickPeek", isDirectory: true)
            .appendingPathComponent("Diagnostics", isDirectory: true)
    }()
    
    static func fetchYouTubeSubs(identifier: String) async throws -> Int {
        try await retryingYouTube(identifier: identifier) {
            let html = try await fetchYouTubeHTML(identifier: identifier)
            let urlString = URLCleaner.youTubeChannelURL(from: identifier)

            if let count = try? await fetchYouTubeSubsFromStructuredData(html: html) {
                return count
            }

            let patterns = [
                "\"subscriberCountText\":\\{\"simpleText\":\"([^\"]+)\"",
                "\"subscriberCountText\":\\{.*?\"runs\":\\[\\{\"text\":\"([^\"]+)\"",
                "\"subscriberCountText\":\\{.*?\"accessibility\":\\{.*?\"label\":\"([^\"]+)\"",
                "\"subscriberCountText\":\\{.*?\"accessibilityData\":\\{.*?\"label\":\"([^\"]+)\"",
                "subscriberCountText.*?label\\\\?\":\\\\?\"([^\"]+?(?:subscribers|iscritti))",
                "<meta\\s+property=\"og:description\"\\s+content=\"([^\"]+?(?:subscribers|iscritti)[^\"]*)\""
            ]

            for pattern in patterns {
                if let count = try? parseCount(from: html, pattern: pattern) {
                    return count
                }
            }

            let snapshotPath = persistYouTubeDiagnosticSnapshot(
                identifier: identifier,
                stage: "fallback_html_missing_count",
                html: html
            )
            logger.error("Failed to parse YouTube subscriber count for normalized identifier=\(identifier, privacy: .public) url=\(urlString, privacy: .public) snippet=\(html.prefix(800), privacy: .public)")
            throw APIError.sourceFormatChanged(source: "YouTube", detail: "subscriber count missing from fallback HTML [snapshot: \(snapshotPath.path)]")
        }
    }

    static func fetchYouTubeVideoMetric(videoID: String, category: MetricCategory) async throws -> Int {
        guard !videoID.isEmpty else { throw APIError.badURL }
        guard let url = URL(string: "https://www.youtube.com/watch?v=\(videoID)") else { throw APIError.badURL }

        let headers = [
            "Accept-Language": youTubeAcceptLanguage,
            "Cookie": youTubeConsentCookie,
            "Referer": "https://www.youtube.com/"
        ]
        let html = try await fetchHTML(from: url, headers: headers)

        if isYouTubeConsentPage(html) {
            throw APIError.incompleteResponse(source: "YouTube", detail: "consent wall or anti-bot page on watch page")
        }

        let patterns: [String]
        switch category {
        case .youtubeVideoViews:
            patterns = [
                "itemprop=\"interactionType\" content=\"https://schema\\.org/WatchAction\".*?itemprop=\"userInteractionCount\" content=\"([0-9]+)\"",
                "\"viewCount\":\"([0-9]+)\""
            ]
        case .youtubeVideoLikes:
            patterns = [
                "itemprop=\"interactionType\" content=\"https://schema\\.org/LikeAction\".*?itemprop=\"userInteractionCount\" content=\"([0-9]+)\"",
                "\"likeCount\":\"([0-9]+)\""
            ]
        default:
            throw APIError.badURL
        }

        for pattern in patterns {
            if let count = try? parseInteger(from: html, pattern: pattern) {
                return count
            }
        }

        throw APIError.sourceFormatChanged(source: "YouTube", detail: "video metric missing from public watch page")
    }
    
    static func fetchGitHubMetric(url: String, category: MetricCategory) async throws -> Int {
        let path = URLCleaner.cleanGitHubPath(url)
        guard let url = URL(string: "https://github.com/\(path)") else { throw APIError.badURL }
        let html = try await fetchHTML(from: url)
        
        let pattern: String
        switch category {
        case .githubIssues: pattern = "Issues\\s+([0-9.,KMB+]+)"
        case .githubPullRequests: pattern = "Pull requests\\s+([0-9.,KMB+]+)"
        default: throw APIError.badURL
        }
        
        return try parseCount(from: html, pattern: pattern)
    }
    
    static func fetchXMetric(urlOrID: String, category: MetricCategory) async throws -> Int {
        if category == .xFollowers {
            let username = URLCleaner.cleanXUsername(urlOrID)
            guard let url = URL(string: "https://x.com/\(username)") else { throw APIError.badURL }
            let html = try await fetchHTML(from: url)
            let pattern = "\"followers_count\":([0-9]+)"
            return try parseCount(from: html, pattern: pattern)
        } else if category == .xPostLikes {
            let tweetID = URLCleaner.extractXTweetID(urlOrID)
            let tweetURL = "https://x.com/x/status/\(tweetID)"
            guard let url = URL(string: tweetURL) else { throw APIError.badURL }
            
            // X often requires a browser-like User Agent to show metadata
            let html = try await fetchHTML(from: url)
            
            // Pattern for likes in embedded JSON or meta tags
            // Usually found in script tags like: "favorite_count":12345
            let patterns = [
                "\"favorite_count\":([0-9]+)",
                "\"favorite_count\":\\s*([0-9]+)",
                "\\\"favorite_count\\\":([0-9]+)",
                "([0-9.,KMB]+) Likes"
            ]
            
            for pattern in patterns {
                if let count = try? parseCount(from: html, pattern: pattern) {
                    return count
                }
            }
            
            throw APIError.decodingError
        } else {
            throw APIError.badURL
        }
    }
    
    static func fetchInstagramMetric(input: String, category: MetricCategory) async throws -> Int {
        // Try exact count first for followers
        if category == .instagramFollowers {
            if let count = try? await fetchInstagramExactCount(handle: input) {
                return count
            }
        }
        
        let urlString = category == .instagramFollowers ? "https://www.instagram.com/\(input)/" : input
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

    static func fetchTikTokMetric(input: String, category: MetricCategory) async throws -> Int {
        let embedURLString: String
        let keyPathRoot: String

        switch category {
        case .tiktokFollowers, .tiktokTotalLikes:
            guard !URLCleaner.cleanTikTokHandle(input).isEmpty else { throw APIError.badURL }
            embedURLString = URLCleaner.tikTokProfileEmbedURL(from: input)
            keyPathRoot = "userInfo"
        case .tiktokVideoViews, .tiktokVideoLikes:
            guard !URLCleaner.extractTikTokVideoID(input).isEmpty else { throw APIError.badURL }
            embedURLString = URLCleaner.tikTokVideoEmbedURL(from: input)
            keyPathRoot = "itemInfos"
        default:
            throw APIError.badURL
        }

        guard let url = URL(string: embedURLString) else { throw APIError.badURL }
        let html = try await fetchHTML(from: url)
        let state = try extractTikTokFrontityState(from: html)

        let scope = findValue(forKey: keyPathRoot, in: state) ?? state
        let key: String

        switch category {
        case .tiktokFollowers:
            key = "followerCount"
        case .tiktokTotalLikes:
            key = "heartCount"
        case .tiktokVideoViews:
            key = "playCount"
        case .tiktokVideoLikes:
            key = "diggCount"
        default:
            throw APIError.badURL
        }

        if let count = integerValue(forKey: key, in: scope) {
            return count
        }

        throw APIError.sourceFormatChanged(source: "TikTok", detail: "metric \(key) missing from public embed page")
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
            logger.error("HTML fetch failed status=\((response as? HTTPURLResponse)?.statusCode ?? 500) url=\(url.absoluteString, privacy: .public)")
            throw APIError.http((response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        
        guard let html = String(data: data, encoding: .utf8) else {
            throw APIError.decodingError
        }
        return html
    }

    private static func fetchYouTubeHTML(identifier: String) async throws -> String {
        let baseURLString = URLCleaner.youTubeChannelURL(from: identifier)
        guard var components = URLComponents(string: baseURLString) else {
            throw APIError.badURL
        }
        
        var queryItems = components.queryItems ?? []
        queryItems.append(contentsOf: [
            URLQueryItem(name: "ucbcb", value: "1"),
            URLQueryItem(name: "cbrd", value: "1"),
            URLQueryItem(name: "hl", value: "en"),
            URLQueryItem(name: "persist_hl", value: "1")
        ])
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw APIError.badURL
        }
        
        let headers = [
            "Accept-Language": youTubeAcceptLanguage,
            "Cookie": youTubeConsentCookie,
            "Referer": "https://www.youtube.com/"
        ]
        
        let html = try await fetchHTML(from: url, headers: headers)
        if isYouTubeConsentPage(html) {
            let snapshotPath = persistYouTubeDiagnosticSnapshot(
                identifier: identifier,
                stage: "consent_or_antibot",
                html: html
            )
            logger.error("YouTube returned consent wall for normalized identifier=\(identifier, privacy: .public) url=\(url.absoluteString, privacy: .public)")
            throw APIError.incompleteResponse(source: "YouTube", detail: "consent wall or anti-bot page [snapshot: \(snapshotPath.path)]")
        }
        
        return html
    }
    
    private static func fetchInstagramExactCount(handle: String) async throws -> Int {
        let url = URL(string: "https://i.instagram.com/api/v1/users/web_profile_info/?username=\(handle)")!
        let data = try await fetchDataWithMobileHeaders(from: url)
        let response = try JSONDecoder().decode(InstagramProfileResponse.self, from: data)
        return response.data.user.edge_followed_by.count
    }
    
    private static func fetchYouTubeSubsFromStructuredData(html: String) async throws -> Int {
        guard
            let apiKey = firstMatch(in: html, pattern: "\"INNERTUBE_API_KEY\":\"([^\"]+)\""),
            let clientVersion = firstMatch(in: html, pattern: "\"INNERTUBE_CLIENT_VERSION\":\"([^\"]+)\""),
            let browseID = firstMatch(in: html, pattern: "<meta itemprop=\"identifier\" content=\"([^\"]+)\"")
                ?? firstMatch(in: html, pattern: "\"browseId\":\"([^\"]+)\"")
        else {
            let snapshotPath = persistYouTubeDiagnosticSnapshot(
                identifier: "unknown",
                stage: "structured_data_bootstrap_missing",
                html: html
            )
            throw APIError.incompleteResponse(source: "YouTube", detail: "missing API key, client version, or browse id [snapshot: \(snapshotPath.path)]")
        }
        
        let payload: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB",
                    "clientVersion": clientVersion,
                    "hl": "it",
                    "gl": "IT"
                ]
            ],
            "browseId": browseID
        ]
        
        let data = try JSONSerialization.data(withJSONObject: payload)
        let url = URL(string: "https://www.youtube.com/youtubei/v1/browse?key=\(apiKey)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(youTubeAcceptLanguage, forHTTPHeaderField: "Accept-Language")
        request.setValue(youTubeConsentCookie, forHTTPHeaderField: "Cookie")
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue("https://www.youtube.com/", forHTTPHeaderField: "Referer")
        request.timeoutInterval = 15
        
        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.http((response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        
        let json = try JSONSerialization.jsonObject(with: responseData)
        
        if let count = extractYouTubeSubscriberCount(from: json) {
            return count
        }
        
        let snapshotPath = persistYouTubeDiagnosticSnapshot(
            identifier: browseID,
            stage: "structured_data_missing_count",
            html: html,
            jsonObject: json
        )
        throw APIError.sourceFormatChanged(source: "YouTube", detail: "subscriber count not found in structured data [snapshot: \(snapshotPath.path)]")
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
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else {
            throw APIError.decodingError
        }
        
        let value = parseRoundedCount(String(html[range]))
        if value == 0 {
            throw APIError.decodingError
        }
        
        return value
    }

    private static func parseInteger(from html: String, pattern: String) throws -> Int {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else {
            throw APIError.decodingError
        }

        let cleaned = String(html[range]).replacingOccurrences(of: ",", with: "")
        guard let value = Int(cleaned), value >= 0 else {
            throw APIError.decodingError
        }

        return value
    }
    
    static func parseRoundedCount(_ string: String) -> Int {
        let normalizedWhitespace = string.unicodeScalars.map { scalar in
            scalar.properties.isWhitespace ? " " : String(scalar)
        }.joined()
        
        var cleaned = normalizedWhitespace.lowercased()
            .replacingOccurrences(of: " subscribers", with: "")
            .replacingOccurrences(of: " iscritti", with: "")
            .replacingOccurrences(of: " subscriber", with: "")
            .replacingOccurrences(of: " abbonati", with: "")
            .replacingOccurrences(of: " abonnés", with: "")
            .replacingOccurrences(of: " milioni di", with: "m")
            .replacingOccurrences(of: " milioni", with: "m")
            .replacingOccurrences(of: " mln di", with: "m")
            .replacingOccurrences(of: " mln", with: "m")
            .replacingOccurrences(of: " mila", with: "k")
            .replacingOccurrences(of: " follower", with: "")
            .replacingOccurrences(of: " followers", with: "")
            .replacingOccurrences(of: " likes", with: "")
            .replacingOccurrences(of: " mi piace", with: "")
            .replacingOccurrences(of: " ", with: "")
        
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
    
    private static func firstMatch(in string: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)),
              let range = Range(match.range(at: 1), in: string) else {
            return nil
        }
        
        return String(string[range])
    }
    
    private static func findStringValue(forKey key: String, in object: Any) -> String? {
        if let dictionary = object as? [String: Any] {
            if let value = dictionary[key] as? String {
                return value
            }
            
            for value in dictionary.values {
                if let match = findStringValue(forKey: key, in: value) {
                    return match
                }
            }
        } else if let array = object as? [Any] {
            for value in array {
                if let match = findStringValue(forKey: key, in: value) {
                    return match
                }
            }
        }
        
        return nil
    }

    private static func integerValue(forKey key: String, in object: Any) -> Int? {
        guard let value = findValue(forKey: key, in: object) else { return nil }
        if let intValue = value as? Int {
            return intValue
        }
        if let doubleValue = value as? Double {
            return Int(doubleValue)
        }
        if let stringValue = value as? String {
            return Int(stringValue.replacingOccurrences(of: ",", with: ""))
        }
        return nil
    }

    private static func extractYouTubeSubscriberCount(from object: Any) -> Int? {
        if
            let pageHeader = findValue(forKey: "pageHeaderViewModel", in: object),
            let count = extractYouTubeSubscriberCount(fromPageHeader: pageHeader)
        {
            return count
        }

        if let count = extractYouTubeSubscriberCountFromKnownKeys(in: object) {
            return count
        }

        return nil
    }

    private static func extractYouTubeSubscriberCount(fromPageHeader object: Any) -> Int? {
        if let metadata = findValue(forKey: "metadata", in: object) {
            if let count = extractYouTubeSubscriberCountFromKnownKeys(in: metadata) {
                return count
            }
        }

        return extractYouTubeSubscriberCountFromKnownKeys(in: object)
    }

    private static func extractYouTubeSubscriberCountFromKnownKeys(in object: Any) -> Int? {
        if let text = findCountText(in: object, preferredKeys: ["subscriberCountText", "accessibilityLabel", "content", "simpleText", "label"]) {
            let count = parseRoundedCount(text)
            if count > 0 {
                return count
            }
        }

        return nil
    }

    private static func findCountText(in object: Any, preferredKeys: [String]) -> String? {
        if let dictionary = object as? [String: Any] {
            for key in preferredKeys {
                if let rawValue = dictionary[key] {
                    if let match = extractSubscriberText(from: rawValue) {
                        return match
                    }
                }
            }

            for value in dictionary.values {
                if let match = findCountText(in: value, preferredKeys: preferredKeys) {
                    return match
                }
            }
        } else if let array = object as? [Any] {
            for value in array {
                if let match = findCountText(in: value, preferredKeys: preferredKeys) {
                    return match
                }
            }
        }

        return nil
    }

    private static func extractSubscriberText(from value: Any) -> String? {
        if let string = value as? String, looksLikeSubscriberCount(string) {
            return string
        }

        if let dictionary = value as? [String: Any] {
            if let content = dictionary["content"] as? String, looksLikeSubscriberCount(content) {
                return content
            }

            if let simpleText = dictionary["simpleText"] as? String, looksLikeSubscriberCount(simpleText) {
                return simpleText
            }

            if let label = dictionary["label"] as? String, looksLikeSubscriberCount(label) {
                return label
            }

            if let accessibilityLabel = dictionary["accessibilityLabel"] as? String, looksLikeSubscriberCount(accessibilityLabel) {
                return accessibilityLabel
            }

            for nestedValue in dictionary.values {
                if let match = extractSubscriberText(from: nestedValue) {
                    return match
                }
            }
        }

        if let array = value as? [Any] {
            for nestedValue in array {
                if let match = extractSubscriberText(from: nestedValue) {
                    return match
                }
            }
        }

        return nil
    }

    private static func looksLikeSubscriberCount(_ string: String) -> Bool {
        let lowercased = string.lowercased()
        return lowercased.contains("subscriber")
            || lowercased.contains("iscritt")
            || lowercased.contains("abbonat")
            || lowercased.contains("abonn")
    }
    
    private static func findValue(forKey key: String, in object: Any) -> Any? {
        if let dictionary = object as? [String: Any] {
            if let value = dictionary[key] {
                return value
            }
            
            for value in dictionary.values {
                if let match = findValue(forKey: key, in: value) {
                    return match
                }
            }
        } else if let array = object as? [Any] {
            for value in array {
                if let match = findValue(forKey: key, in: value) {
                    return match
                }
            }
        }
        
        return nil
    }

    private static func extractTikTokFrontityState(from html: String) throws -> [String: Any] {
        guard let jsonString = firstMatch(
            in: html,
            pattern: "<script id=\"__FRONTITY_CONNECT_STATE__\" type=\"application/json\">(.*?)</script>"
        ) else {
            throw APIError.incompleteResponse(source: "TikTok", detail: "missing embedded state")
        }

        let data = Data(jsonString.utf8)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.decodingError
        }

        return object
    }

    private static func isYouTubeConsentPage(_ html: String) -> Bool {
        html.contains("consent.youtube.com")
            || html.contains("Before you continue to YouTube")
            || html.contains("Prima di continuare su YouTube")
            || html.contains("window['ppConfig']")
    }

    private static func persistYouTubeDiagnosticSnapshot(identifier: String, stage: String, html: String, jsonObject: Any? = nil) -> URL {
        try? FileManager.default.createDirectory(at: diagnosticsDirectory, withIntermediateDirectories: true)

        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let sanitizedIdentifier = identifier
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "@", with: "at_")
        let fileURL = diagnosticsDirectory.appendingPathComponent("youtube_\(stage)_\(sanitizedIdentifier)_\(timestamp).log")

        let summary = youTubeDiagnosticSummary(html: html, jsonObject: jsonObject)
        try? summary.write(to: fileURL, atomically: true, encoding: .utf8)

        logger.error("Saved YouTube diagnostic snapshot stage=\(stage, privacy: .public) identifier=\(identifier, privacy: .public) path=\(fileURL.path, privacy: .public)")
        return fileURL
    }

    private static func youTubeDiagnosticSummary(html: String, jsonObject: Any?) -> String {
        let flags = [
            "hasSubscriberCountText": html.contains("subscriberCountText"),
            "hasBrowseId": html.contains("\"browseId\"") || html.contains("itemprop=\"identifier\""),
            "hasInnertubeKey": html.contains("\"INNERTUBE_API_KEY\""),
            "hasClientVersion": html.contains("\"INNERTUBE_CLIENT_VERSION\""),
            "hasConsentMarker": isYouTubeConsentPage(html),
            "hasOgDescription": html.contains("og:description")
        ]

        let htmlSnippets = [
            diagnosticSnippet(in: html, around: "\"subscriberCountText\""),
            diagnosticSnippet(in: html, around: "\"INNERTUBE_API_KEY\""),
            diagnosticSnippet(in: html, around: "\"browseId\""),
            diagnosticSnippet(in: html, around: "itemprop=\"identifier\""),
            diagnosticSnippet(in: html, around: "og:description")
        ].compactMap { $0 }

        var sections = [String]()
        sections.append("Flags")
        sections.append(flags.map { "\($0.key)=\($0.value)" }.joined(separator: "\n"))

        if !htmlSnippets.isEmpty {
            sections.append("HTML snippets")
            sections.append(htmlSnippets.joined(separator: "\n\n---\n\n"))
        }

        if let jsonObject {
            sections.append("JSON snippets")
            sections.append(jsonDiagnosticSummary(jsonObject))
        }

        return sections.joined(separator: "\n\n")
    }

    private static func diagnosticSnippet(in source: String, around needle: String, radius: Int = 260) -> String? {
        guard let range = source.range(of: needle) else { return nil }
        let lowerBound = source.index(range.lowerBound, offsetBy: -radius, limitedBy: source.startIndex) ?? source.startIndex
        let upperBound = source.index(range.upperBound, offsetBy: radius, limitedBy: source.endIndex) ?? source.endIndex
        return String(source[lowerBound..<upperBound])
    }

    private static func jsonDiagnosticSummary(_ object: Any) -> String {
        var lines = [String]()

        if let subscriberText = findStringValue(forKey: "subscriberCountText", in: object) {
            lines.append("subscriberCountText=\(subscriberText)")
        } else {
            lines.append("subscriberCountText=<missing>")
        }

        if let metadataRows = findValue(forKey: "metadataRows", in: object) {
            lines.append("metadataRows=\(String(describing: metadataRows).prefix(1200))")
        } else {
            lines.append("metadataRows=<missing>")
        }

        if let header = findValue(forKey: "pageHeaderViewModel", in: object) {
            lines.append("pageHeaderViewModel=\(String(describing: header).prefix(1200))")
        }

        return lines.joined(separator: "\n")
    }

    private static func retryingYouTube<T>(identifier: String, maxAttempts: Int = 3, action: @escaping () async throws -> T) async throws -> T {
        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                return try await action()
            } catch {
                lastError = error
                guard attempt < maxAttempts, shouldRetryYouTube(error) else { break }

                let delay = UInt64(400_000_000 * attempt)
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                logger.warning("YouTube retry attempt=\(attempt) identifier=\(identifier, privacy: .public) error=\(message, privacy: .public)")
                try? await Task.sleep(nanoseconds: delay)
            }
        }

        throw lastError ?? APIError.decodingError
    }

    private static func shouldRetryYouTube(_ error: Error) -> Bool {
        switch error as? APIError {
        case .decodingError:
            return true
        case .http(let status):
            return status >= 500 || status == 429
        case .rateLimited:
            return true
        default:
            return false
        }
    }
}
