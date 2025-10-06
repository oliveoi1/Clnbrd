//
//  URLTrackingCleaner.swift
//  Clnbrd
//
//  Created by Allan Alomes on 10/6/2025.
//  Removes tracking parameters and affiliate cruft from URLs
//

import Foundation

class URLTrackingCleaner {
    
    // MARK: - Configuration
    
    /// Global tracking parameters that apply to all URLs
    private static let globalTrackingParams: Set<String> = [
        // UTM tracking (universal)
        "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
        "utm_id", "utm_source_platform", "utm_creative_format", "utm_marketing_tactic",
        
        // Facebook tracking
        "fbclid", "fb_action_ids", "fb_action_types", "fb_source", "fb_ref",
        
        // Google tracking
        "gclid", "gclsrc", "dclid",
        
        // Other common trackers
        "mc_cid", "mc_eid", // MailChimp
        "_hsenc", "_hsmi", // HubSpot
        "mkt_tok", // Marketo
        "vero_id", // Vero
        "msclkid", // Microsoft/Bing
    ]
    
    /// Site-specific tracking rules
    private static let siteSpecificRules: [String: URLCleaningRule] = [
        // YouTube
        "youtube.com": URLCleaningRule(
            removeParams: ["feature", "si", "app"],
            keepParams: ["v", "list", "t"]
        ),
        "youtu.be": URLCleaningRule(
            removeParams: ["si", "feature"],
            keepParams: nil
        ),
        
        // Spotify
        "open.spotify.com": URLCleaningRule(
            removeParams: ["si", "context"],
            keepParams: nil
        ),
        
        // Amazon
        "amazon.com": URLCleaningRule(
            removeParams: [
                "crid", "dib", "dib_tag", "keywords", "qid", "sprefix", "sr",
                "pd_rd_w", "pf_rd_s", "pf_rd_p", "pf_rd_t", "pf_rd_i", "pf_rd_m",
                "pf_rd_r", "pd_rd_wg", "pd_rd_r", "linkCode", "tag", "linkId",
                "geniuslink", "ref", "ref_", "content-id", "psc", "th", "ascsubtag"
            ],
            keepParams: nil,
            pathPatterns: ["/ref=": ""] // Remove /ref= from path
        ),
        
        // Google
        "google.com": URLCleaningRule(
            removeParams: [
                "gs_lcrp", "gs_lp", "sca_esv", "ei", "iflsig", "sclient",
                "rlz", "bih", "biw", "dpr", "ved", "sa", "fbs", "source",
                "sourceid", "aqs", "oq", "gs_lp"
            ],
            keepParams: ["q", "tbm", "tbs"] // Keep search query and filters
        ),
        
        // Instagram
        "instagram.com": URLCleaningRule(
            removeParams: ["igshid", "igsh"],
            keepParams: nil
        ),
        
        // Twitter/X
        "twitter.com": URLCleaningRule(
            removeParams: ["s", "t", "ref_src", "ref_url"],
            keepParams: nil
        ),
        "x.com": URLCleaningRule(
            removeParams: ["s", "t", "ref_src", "ref_url"],
            keepParams: nil
        ),
        
        // Walmart
        "walmart.com": URLCleaningRule(
            removeParams: ["from", "sid", "athbdg", "athancid", "athcpid"],
            keepParams: nil
        ),
        
        // TikTok
        "tiktok.com": URLCleaningRule(
            removeParams: ["is_copy_url", "is_from_webapp", "_r"],
            keepParams: nil
        ),
    ]
    
    // MARK: - Cleaning Methods
    
    /// Clean tracking parameters from a URL string
    static func cleanURL(_ urlString: String) -> String {
        guard let url = URL(string: urlString),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return urlString
        }
        
        var cleanedComponents = components
        
        // Get the domain (host)
        guard let host = components.host else {
            return urlString
        }
        
        // Find matching rule for this domain
        let matchingDomain = siteSpecificRules.keys.first { host.hasSuffix($0) }
        let rule = matchingDomain.flatMap { siteSpecificRules[$0] }
        
        // Clean query parameters
        if let queryItems = components.queryItems, !queryItems.isEmpty {
            let cleanedItems = cleanQueryItems(queryItems, rule: rule)
            cleanedComponents.queryItems = cleanedItems.isEmpty ? nil : cleanedItems
        }
        
        // Clean path if rule specifies path patterns
        if let pathPatterns = rule?.pathPatterns {
            cleanedComponents.path = cleanPath(components.path, patterns: pathPatterns)
        }
        
        return cleanedComponents.url?.absoluteString ?? urlString
    }
    
    /// Clean all URLs found in text
    static func cleanURLsInText(_ text: String) -> String {
        // Detect URLs using a simple regex pattern
        let pattern = #"https?://[^\s<>"{}|\\^`\[\]]+"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text
        }
        
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var cleanedText = text
        
        // Find all matches in reverse order to maintain string indices
        let matches = regex.matches(in: text, range: range).reversed()
        
        for match in matches {
            if let range = Range(match.range, in: text) {
                let urlString = String(text[range])
                let cleanedURL = cleanURL(urlString)
                
                if cleanedURL != urlString {
                    let nsRange = NSRange(range, in: cleanedText)
                    cleanedText = (cleanedText as NSString).replacingCharacters(in: nsRange, with: cleanedURL)
                }
            }
        }
        
        return cleanedText
    }
    
    // MARK: - Helper Methods
    
    private static func cleanQueryItems(_ items: [URLQueryItem], rule: URLCleaningRule?) -> [URLQueryItem] {
        return items.filter { item in
            let name = item.name.lowercased()
            
            // If there's a keepParams list, only keep those
            if let keepParams = rule?.keepParams {
                return keepParams.contains(name)
            }
            
            // Remove global tracking params
            if globalTrackingParams.contains(name) {
                return false
            }
            
            // Remove site-specific params
            if let removeParams = rule?.removeParams, removeParams.contains(name) {
                return false
            }
            
            return true
        }
    }
    
    private static func cleanPath(_ path: String, patterns: [String: String]) -> String {
        var cleanedPath = path
        
        for (pattern, replacement) in patterns {
            if let range = cleanedPath.range(of: pattern) {
                // Remove everything from the pattern onwards
                cleanedPath = String(cleanedPath[..<range.lowerBound]) + replacement
            }
        }
        
        return cleanedPath
    }
}

// MARK: - Supporting Types

struct URLCleaningRule {
    /// Parameters to explicitly remove (site-specific)
    let removeParams: Set<String>?
    
    /// Parameters to keep (if specified, only these are kept, others are removed)
    let keepParams: Set<String>?
    
    /// Patterns to remove from the path
    let pathPatterns: [String: String]?
    
    init(removeParams: [String]? = nil, 
         keepParams: [String]? = nil,
         pathPatterns: [String: String]? = nil) {
        self.removeParams = removeParams.map { Set($0.map { $0.lowercased() }) }
        self.keepParams = keepParams.map { Set($0.map { $0.lowercased() }) }
        self.pathPatterns = pathPatterns
    }
}

