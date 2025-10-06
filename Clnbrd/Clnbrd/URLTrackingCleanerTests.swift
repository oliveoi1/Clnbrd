//
//  URLTrackingCleanerTests.swift
//  Clnbrd
//
//  Quick tests to verify URL cleaning functionality
//  TODO: Move to proper XCTest suite
//

import Foundation

class URLTrackingCleanerTests {
    
    static func runAllTests() {
        print("🧪 Running URL Tracking Cleaner Tests...\n")
        
        testYouTube()
        testAmazon()
        testSpotify()
        testGoogle()
        testInstagram()
        testTwitter()
        testMultipleURLs()
        testGlobalTracking()
        
        print("\n✅ All tests completed!")
    }
    
    static func testYouTube() {
        print("Testing YouTube...")
        
        let input = "https://youtu.be/dQw4w9WgXcQ?si=ABC123tracking"
        let expected = "https://youtu.be/dQw4w9WgXcQ"
        let result = URLTrackingCleaner.cleanURL(input)
        
        assert(result == expected, "YouTube test failed: \(result)")
        print("✓ YouTube ?si= removed")
    }
    
    static func testAmazon() {
        print("Testing Amazon...")
        
        let input = "https://www.amazon.com/product/B08N5WRWNW/ref=sr_1_1?crid=ABC&keywords=test&qid=123&sr=8-1"
        let expected = "https://www.amazon.com/product/B08N5WRWNW"
        let result = URLTrackingCleaner.cleanURL(input)
        
        assert(result == expected, "Amazon test failed: \(result)")
        print("✓ Amazon /ref= and tracking params removed")
    }
    
    static func testSpotify() {
        print("Testing Spotify...")
        
        let input = "https://open.spotify.com/track/3n3Ppam7vgaVa1iaRUc9Lp?si=abc123tracking"
        let expected = "https://open.spotify.com/track/3n3Ppam7vgaVa1iaRUc9Lp"
        let result = URLTrackingCleaner.cleanURL(input)
        
        assert(result == expected, "Spotify test failed: \(result)")
        print("✓ Spotify ?si= removed")
    }
    
    static func testGoogle() {
        print("Testing Google...")
        
        let input = "https://www.google.com/search?q=test&gs_lcrp=abc&ei=xyz&ved=123"
        let expected = "https://www.google.com/search?q=test"
        let result = URLTrackingCleaner.cleanURL(input)
        
        assert(result == expected, "Google test failed: \(result)")
        print("✓ Google tracking removed, query kept")
    }
    
    static func testInstagram() {
        print("Testing Instagram...")
        
        let input = "https://www.instagram.com/p/ABC123/?igsh=xyz789tracking"
        let expected = "https://www.instagram.com/p/ABC123/"
        let result = URLTrackingCleaner.cleanURL(input)
        
        assert(result == expected, "Instagram test failed: \(result)")
        print("✓ Instagram ?igsh= removed")
    }
    
    static func testTwitter() {
        print("Testing Twitter/X...")
        
        let input = "https://x.com/user/status/123456?s=20&t=abc123tracking"
        let expected = "https://x.com/user/status/123456"
        let result = URLTrackingCleaner.cleanURL(input)
        
        assert(result == expected, "Twitter test failed: \(result)")
        print("✓ Twitter ?s=&t= removed")
    }
    
    static func testMultipleURLs() {
        print("Testing multiple URLs in text...")
        
        let input = """
        Check out this video: https://youtu.be/dQw4w9WgXcQ?si=tracking123
        And this product: https://www.amazon.com/product/B08N5WRWNW/ref=sr_1_1?crid=ABC
        """
        
        let result = URLTrackingCleaner.cleanURLsInText(input)
        
        assert(!result.contains("?si="), "YouTube tracking not removed from text")
        assert(!result.contains("/ref="), "Amazon tracking not removed from text")
        print("✓ Multiple URLs cleaned in text")
    }
    
    static func testGlobalTracking() {
        print("Testing global tracking parameters...")
        
        let input = "https://example.com/page?utm_source=twitter&utm_campaign=spring&fbclid=123"
        let expected = "https://example.com/page"
        let result = URLTrackingCleaner.cleanURL(input)
        
        assert(result == expected, "Global tracking test failed: \(result)")
        print("✓ UTM and Facebook tracking removed")
    }
}

