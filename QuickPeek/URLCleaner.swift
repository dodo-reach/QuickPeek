import Foundation

struct URLCleaner {
    static func cleanGitHubPath(_ url: String) -> String {
        return url.replacingOccurrences(of: "https://", with: "")
                  .replacingOccurrences(of: "github.com/", with: "")
                  .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    static func cleanRedditHandle(_ url: String) -> String? {
        let cleaned = url.lowercased()
        if let sub = cleaned.components(separatedBy: "/r/").last?.components(separatedBy: "/").first {
            return sub
        }
        if let user = cleaned.components(separatedBy: "/user/").last?.components(separatedBy: "/").first ??
                      cleaned.components(separatedBy: "/u/").last?.components(separatedBy: "/").first {
            return user
        }
        return nil
    }
    
    static func cleanXUsername(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "x.com/", with: "")
            .replacingOccurrences(of: "twitter.com/", with: "")
            .replacingOccurrences(of: "@", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "/").first ?? string
    }

    static func cleanBlueskyHandle(_ string: String) -> String {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        
        if trimmed.hasPrefix("did:") {
            return trimmed
        }
        
        let cleaned = trimmed
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "bsky.app/profile/", with: "")
            .replacingOccurrences(of: "staging.bsky.app/profile/", with: "")
            .replacingOccurrences(of: "@", with: "")
        
        return cleaned
            .components(separatedBy: "/")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? trimmed
    }
    
    static func extractXTweetID(_ urlOrID: String) -> String {
        if let id = urlOrID.components(separatedBy: "/status/").last?.components(separatedBy: "?").first {
            return id
        }
        return urlOrID.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    static func cleanYouTubeIdentifier(_ string: String) -> String {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        
        if trimmed.hasPrefix("@") {
            return trimmed
        }
        
        let cleaned = trimmed
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "m.youtube.com/", with: "")
            .replacingOccurrences(of: "www.youtube.com/", with: "")
            .replacingOccurrences(of: "youtube.com/", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        if cleaned.hasPrefix("@") {
            return cleaned.components(separatedBy: "/").first ?? cleaned
        }
        
        if let handle = extractYouTubePathComponent(in: cleaned, marker: "@") {
            return "@\(handle)"
        }
        
        if let channelID = extractYouTubePathComponent(in: cleaned, marker: "channel/") {
            return channelID
        }
        
        let firstComponent = cleaned.components(separatedBy: "/").first ?? cleaned
        if firstComponent.hasPrefix("UC") {
            return firstComponent
        }
        
        if let customPath = extractYouTubePathComponent(in: cleaned, marker: "c/") ??
            extractYouTubePathComponent(in: cleaned, marker: "user/") {
            return "@\(customPath)"
        }
        
        if firstComponent.isEmpty {
            return ""
        }
        
        return "@\(firstComponent)"
    }

    static func extractYouTubeVideoID(_ string: String) -> String {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        if let components = URLComponents(string: trimmed), let host = components.host?.lowercased() {
            if host.contains("youtu.be") {
                return components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            }

            if host.contains("youtube.com") {
                if let id = components.queryItems?.first(where: { $0.name == "v" })?.value {
                    return id
                }

                let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                if path.hasPrefix("shorts/") {
                    return String(path.dropFirst("shorts/".count)).components(separatedBy: "/").first ?? ""
                }
                if path.hasPrefix("embed/") {
                    return String(path.dropFirst("embed/".count)).components(separatedBy: "/").first ?? ""
                }
            }
        }

        let candidate = trimmed
            .components(separatedBy: "?")
            .first?
            .components(separatedBy: "#")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? trimmed

        if candidate.contains("/") || candidate.hasPrefix("@") || candidate.uppercased().hasPrefix("UC") {
            return ""
        }

        return candidate
    }

    static func isYouTubeVideoInput(_ string: String) -> Bool {
        let lowercased = string.lowercased()
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return lowercased.contains("youtube.com/watch")
            || lowercased.contains("youtu.be/")
            || lowercased.contains("youtube.com/shorts/")
            || lowercased.contains("youtube.com/embed/")
            || (!trimmed.contains("/") && !trimmed.hasPrefix("@") && !trimmed.uppercased().hasPrefix("UC") && trimmed.count == 11)
    }
    
    static func youTubeChannelURL(from string: String) -> String {
        let identifier = cleanYouTubeIdentifier(string)
        
        if identifier.hasPrefix("@") {
            return "https://www.youtube.com/\(identifier)"
        }
        
        if identifier.hasPrefix("UC") {
            return "https://www.youtube.com/channel/\(identifier)"
        }
        
        return "https://www.youtube.com/@\(identifier)"
    }
    
    static func cleanNpmName(_ packageName: String) -> String {
        return packageName.replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "www.npmjs.com/package/", with: "")
            .replacingOccurrences(of: "npmjs.com/package/", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    static func cleanDiscordCode(_ inviteCode: String) -> String {
        return inviteCode.replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "discord.gg/", with: "")
            .replacingOccurrences(of: "discord.com/invite/", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    static func cleanInstagramHandle(_ urlOrID: String) -> String {
        return urlOrID.replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "www.instagram.com/", with: "")
            .replacingOccurrences(of: "instagram.com/", with: "")
            .replacingOccurrences(of: "@", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "/").first ?? ""
    }

    static func cleanInstagramPostURL(_ urlOrID: String) -> String {
        let trimmed = urlOrID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        if trimmed.contains("instagram.com/") {
            return trimmed
        }

        return "https://www.instagram.com/p/\(trimmed)"
    }

    static func isInstagramPostURL(_ urlOrID: String) -> Bool {
        let lowercased = urlOrID.lowercased()
        return lowercased.contains("instagram.com/p/")
            || lowercased.contains("instagram.com/reel/")
            || lowercased.contains("instagram.com/reels/")
    }

    static func cleanTikTokHandle(_ urlOrID: String) -> String {
        let trimmed = urlOrID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let cleaned = trimmed
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.tiktok.com/", with: "")
            .replacingOccurrences(of: "m.tiktok.com/", with: "")
            .replacingOccurrences(of: "tiktok.com/", with: "")
            .replacingOccurrences(of: "embed/@", with: "")
            .replacingOccurrences(of: "@", with: "")

        return cleaned
            .components(separatedBy: "/")
            .first?
            .components(separatedBy: "?")
            .first?
            .components(separatedBy: "#")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? trimmed
    }

    static func extractTikTokVideoID(_ urlOrID: String) -> String {
        let trimmed = urlOrID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        if let range = trimmed.range(of: "/video/") {
            let suffix = trimmed[range.upperBound...]
            return suffix
                .components(separatedBy: "/")
                .first?
                .components(separatedBy: "?")
                .first?
                .components(separatedBy: "#")
                .first ?? trimmed
        }

        if let range = trimmed.range(of: "/embed/") {
            let suffix = trimmed[range.upperBound...]
            let component = suffix
                .components(separatedBy: "/")
                .first?
                .components(separatedBy: "?")
                .first?
                .components(separatedBy: "#")
                .first ?? trimmed
            if !component.hasPrefix("@") {
                return component
            }
        }

        let candidate = trimmed
            .components(separatedBy: "?")
            .first?
            .components(separatedBy: "#")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? trimmed

        return candidate.allSatisfy(\.isNumber) ? candidate : ""
    }

    static func isTikTokVideoInput(_ urlOrID: String) -> Bool {
        let lowercased = urlOrID.lowercased()
        return lowercased.contains("/video/")
            || (lowercased.contains("/embed/") && !lowercased.contains("/embed/@"))
            || urlOrID.trimmingCharacters(in: .whitespacesAndNewlines).allSatisfy(\.isNumber)
    }

    static func tikTokProfileURL(from string: String) -> String {
        "https://www.tiktok.com/@\(cleanTikTokHandle(string))"
    }

    static func tikTokProfileEmbedURL(from string: String) -> String {
        "https://www.tiktok.com/embed/@\(cleanTikTokHandle(string))"
    }

    static func tikTokVideoURL(from string: String) -> String {
        "https://www.tiktok.com/embed/\(extractTikTokVideoID(string))"
    }

    static func tikTokVideoEmbedURL(from string: String) -> String {
        tikTokVideoURL(from: string)
    }
    
    private static func extractYouTubePathComponent(in string: String, marker: String) -> String? {
        guard let range = string.range(of: marker) else { return nil }
        let suffix = string[range.upperBound...]
        let component = suffix.components(separatedBy: "/").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return component.isEmpty ? nil : component
    }
}
