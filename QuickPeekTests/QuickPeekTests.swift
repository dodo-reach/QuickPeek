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

}
