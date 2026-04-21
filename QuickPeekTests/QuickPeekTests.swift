//
//  QuickPeekTests.swift
//  QuickPeekTests
//
//  Created by Edoardo Dodorico on 20/04/26.
//

import Testing
@testable import QuickPeek

struct QuickPeekTests {

    @Test func cleanYouTubeIdentifierKeepsChannelID() async throws {
        #expect(URLCleaner.cleanYouTubeIdentifier("UCX6OQ3DkcsbYNE6H8uQQuVA") == "UCX6OQ3DkcsbYNE6H8uQQuVA")
        #expect(URLCleaner.cleanYouTubeIdentifier("https://www.youtube.com/channel/UCX6OQ3DkcsbYNE6H8uQQuVA") == "UCX6OQ3DkcsbYNE6H8uQQuVA")
    }
    
    @Test func cleanYouTubeIdentifierKeepsHandle() async throws {
        #expect(URLCleaner.cleanYouTubeIdentifier("@MKBHD") == "@MKBHD")
        #expect(URLCleaner.cleanYouTubeIdentifier("https://www.youtube.com/@MKBHD") == "@MKBHD")
    }

    @Test func extractYouTubeVideoIDSupportsWatchLinksAndShortLinks() async throws {
        #expect(URLCleaner.extractYouTubeVideoID("https://www.youtube.com/watch?v=dQw4w9WgXcQ") == "dQw4w9WgXcQ")
        #expect(URLCleaner.extractYouTubeVideoID("https://youtu.be/dQw4w9WgXcQ?t=43") == "dQw4w9WgXcQ")
        #expect(URLCleaner.extractYouTubeVideoID("https://www.youtube.com/shorts/dQw4w9WgXcQ") == "dQw4w9WgXcQ")
    }
    
    @Test func youTubeChannelURLBuildsCorrectRoute() async throws {
        #expect(URLCleaner.youTubeChannelURL(from: "@MKBHD") == "https://www.youtube.com/@MKBHD")
        #expect(URLCleaner.youTubeChannelURL(from: "UCX6OQ3DkcsbYNE6H8uQQuVA") == "https://www.youtube.com/channel/UCX6OQ3DkcsbYNE6H8uQQuVA")
    }
    
    @Test func parseRoundedCountHandlesSubscriberLabels() async throws {
        #expect(WebScraper.parseRoundedCount("15.4K subscribers") == 15_400)
        #expect(WebScraper.parseRoundedCount("1,23 M iscritti") == 1_230_000)
        #expect(WebScraper.parseRoundedCount("1,54\u{00A0}Mln di iscritti") == 1_540_000)
        #expect(WebScraper.parseRoundedCount("1,54\u{202F}Mln di iscritti") == 1_540_000)
    }

    @Test func cleanBlueskyHandleSupportsProfileURLsAndHandles() async throws {
        #expect(URLCleaner.cleanBlueskyHandle("@openai.com") == "openai.com")
        #expect(URLCleaner.cleanBlueskyHandle("openai.com") == "openai.com")
        #expect(URLCleaner.cleanBlueskyHandle("https://bsky.app/profile/openai.com") == "openai.com")
        #expect(URLCleaner.cleanBlueskyHandle("did:plc:abc123") == "did:plc:abc123")
    }

    @Test func cleanTikTokHandleSupportsProfileInputs() async throws {
        #expect(URLCleaner.cleanTikTokHandle("@scout2015") == "scout2015")
        #expect(URLCleaner.cleanTikTokHandle("https://www.tiktok.com/@scout2015") == "scout2015")
        #expect(URLCleaner.cleanTikTokHandle("https://www.tiktok.com/embed/@scout2015") == "scout2015")
    }

    @Test func extractTikTokVideoIDSupportsVideoAndEmbedInputs() async throws {
        #expect(URLCleaner.extractTikTokVideoID("https://www.tiktok.com/@scout2015/video/6718335390845095173") == "6718335390845095173")
        #expect(URLCleaner.extractTikTokVideoID("https://www.tiktok.com/embed/6718335390845095173") == "6718335390845095173")
        #expect(URLCleaner.extractTikTokVideoID("6718335390845095173") == "6718335390845095173")
    }

    @Test func trackerIdentityKeyKeepsSourcesSeparatedForSameHandle() async throws {
        let xKey = TrackerViewModel.trackerIdentityKey(type: .x, input: "@openai", categories: [.xFollowers])
        let tikTokKey = TrackerViewModel.trackerIdentityKey(type: .tiktok, input: "@openai", categories: [.tiktokFollowers])

        #expect(xKey != tikTokKey)
    }

    @Test func trackerIdentityKeyNormalizesEquivalentVideoInputs() async throws {
        let shortURL = TrackerViewModel.trackerIdentityKey(
            type: .youtube,
            input: "https://youtu.be/dQw4w9WgXcQ?t=43",
            categories: [.youtubeVideoViews]
        )
        let watchURL = TrackerViewModel.trackerIdentityKey(
            type: .youtube,
            input: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
            categories: [.youtubeVideoLikes]
        )
        let tikTokURL = TrackerViewModel.trackerIdentityKey(
            type: .tiktok,
            input: "https://www.tiktok.com/@scout2015/video/6718335390845095173",
            categories: [.tiktokVideoViews]
        )
        let tikTokEmbed = TrackerViewModel.trackerIdentityKey(
            type: .tiktok,
            input: "https://www.tiktok.com/embed/6718335390845095173",
            categories: [.tiktokVideoLikes]
        )

        #expect(shortURL == watchURL)
        #expect(tikTokURL == tikTokEmbed)
    }

}
