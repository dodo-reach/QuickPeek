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
            .replacingOccurrences(of: "x.com/", with: "")
            .replacingOccurrences(of: "twitter.com/", with: "")
            .replacingOccurrences(of: "@", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "/").first ?? string
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
}
