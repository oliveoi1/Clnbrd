import Foundation

/// Model for custom find/replace rules
struct CustomRule: Codable {
    let find: String
    let replace: String
}

/// Handles all text cleaning operations including AI watermark removal, formatting cleanup, and URL cleaning
class CleaningRules {
    // Basic formatting rules
    var removeEmdashes = true
    var replaceEmdashWith = ", "
    var normalizeSpaces = true
    var removeZeroWidthChars = true
    var normalizeLineBreaks = true
    var removeTrailingSpaces = true
    var convertSmartQuotes = true
    var removeEmojis = false
    
    // High-priority cleaning rules
    var removeExtraLineBreaks = true
    var removeLeadingTrailingWhitespace = true
    var removeUrls = true
    var removeHtmlTags = true
    var removeExtraPunctuation = true
    
    // URL tracking removal
    var removeUrlTracking = true
    
    // Custom user-defined rules
    var customRules: [CustomRule] = []
    
    /// Apply all enabled cleaning rules to the provided text
    /// - Parameter text: The original text to clean
    /// - Returns: Cleaned text with all enabled rules applied
    func apply(to text: String) -> String {
        var cleaned = text
        
        // Remove emojis FIRST (if enabled)
        if removeEmojis {
            cleaned = cleaned.unicodeScalars.filter { scalar in
                // Keep if it's NOT an emoji
                !(scalar.properties.isEmoji ||
                  scalar.properties.isEmojiPresentation ||
                  scalar.properties.isEmojiModifier ||
                  scalar.properties.isEmojiModifierBase ||
                  (0x1F300...0x1F9FF).contains(scalar.value) || // Emoji blocks
                  (0x2600...0x26FF).contains(scalar.value) ||   // Misc symbols
                  (0x2700...0x27BF).contains(scalar.value))     // Dingbats
            }.map { String($0) }.joined()
        }
        
        // Apply custom find/replace rules
        for rule in customRules {
            if !rule.find.isEmpty {
                cleaned = cleaned.replacingOccurrences(of: rule.find, with: rule.replace)
            }
        }
        
        // Remove AI watermarks and hidden Unicode characters
        if removeZeroWidthChars {
            cleaned = removeAIWatermarks(from: cleaned)
        }
        
        // Em dashes and en dashes
        if removeEmdashes {
            cleaned = cleaned.replacingOccurrences(of: "—", with: replaceEmdashWith)
            cleaned = cleaned.replacingOccurrences(of: "–", with: replaceEmdashWith)
        }
        
        // Smart quotes to regular quotes
        if convertSmartQuotes {
            cleaned = cleaned.replacingOccurrences(of: "\u{201C}", with: "\"")
            cleaned = cleaned.replacingOccurrences(of: "\u{201D}", with: "\"")
            cleaned = cleaned.replacingOccurrences(of: "\u{2018}", with: "'")
            cleaned = cleaned.replacingOccurrences(of: "\u{2019}", with: "'")
        }
        
        // Normalize multiple spaces to single space
        if normalizeSpaces {
            cleaned = cleaned.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        }
        
        // Normalize line breaks
        if normalizeLineBreaks {
            cleaned = cleaned.replacingOccurrences(of: "\r\n", with: "\n")
            cleaned = cleaned.replacingOccurrences(of: "\r", with: "\n")
        }
        
        // Remove trailing spaces before line breaks
        if removeTrailingSpaces {
            cleaned = cleaned.replacingOccurrences(of: " +\n", with: "\n", options: .regularExpression)
        }
        
        // Remove extra line breaks (3+ → 2)
        if removeExtraLineBreaks {
            cleaned = cleaned.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        }
        
        // Remove leading/trailing whitespace from each line
        if removeLeadingTrailingWhitespace {
            let lines = cleaned.components(separatedBy: "\n")
            cleaned = lines.map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: "\n")
        }
        
        // Remove URL tracking parameters (before removing protocols)
        if removeUrlTracking {
            cleaned = removeURLTracking(from: cleaned)
        }
        
        // Remove URL protocols (strip https://, http://, ftp://, www. but keep domain visible)
        if removeUrls {
            cleaned = cleaned.replacingOccurrences(of: "https?://", with: "", options: .regularExpression)
            cleaned = cleaned.replacingOccurrences(of: "ftp://", with: "", options: .regularExpression)
            cleaned = cleaned.replacingOccurrences(of: "www\\.", with: "", options: .regularExpression)
        }
        
        // Remove HTML tags and entities
        if removeHtmlTags {
            cleaned = cleaned.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            cleaned = cleaned.replacingOccurrences(of: "&[a-zA-Z0-9#]+;", with: "", options: .regularExpression)
        }
        
        // Remove excessive punctuation
        if removeExtraPunctuation {
            cleaned = cleaned.replacingOccurrences(of: "([.!?]){2,}", with: "$1", options: .regularExpression)
            cleaned = cleaned.replacingOccurrences(of: "([,;:]){2,}", with: "$1", options: .regularExpression)
            cleaned = cleaned.replacingOccurrences(of: "([-]){3,}", with: "---", options: .regularExpression)
        }
        
        return cleaned
    }
    
    /// Remove AI-generated watermarks and hidden Unicode characters
    /// - Parameter text: Text to clean
    /// - Returns: Text with all invisible characters removed
    private func removeAIWatermarks(from text: String) -> String {
        var cleaned = text
        
        // Zero-width characters (common AI watermarks)
        cleaned = cleaned.replacingOccurrences(of: "\u{200B}", with: "") // Zero Width Space
        cleaned = cleaned.replacingOccurrences(of: "\u{200C}", with: "") // Zero Width Non-Joiner
        cleaned = cleaned.replacingOccurrences(of: "\u{200D}", with: "") // Zero Width Joiner
        cleaned = cleaned.replacingOccurrences(of: "\u{FEFF}", with: "") // Zero Width No-Break Space
        cleaned = cleaned.replacingOccurrences(of: "\u{2060}", with: "") // Word Joiner
        cleaned = cleaned.replacingOccurrences(of: "\u{2061}", with: "") // Function Application
        cleaned = cleaned.replacingOccurrences(of: "\u{2062}", with: "") // Invisible Times
        cleaned = cleaned.replacingOccurrences(of: "\u{2063}", with: "") // Invisible Separator
        cleaned = cleaned.replacingOccurrences(of: "\u{2064}", with: "") // Invisible Plus
        
        // Variation selectors (emoji modifiers)
        for i in 0xFE00...0xFE0F {
            if let scalar = Unicode.Scalar(i) {
                cleaned = cleaned.replacingOccurrences(of: String(scalar), with: "")
            }
        }
        
        // Other invisible characters
        cleaned = cleaned.replacingOccurrences(of: "\u{180E}", with: "") // Mongolian Vowel Separator
        cleaned = cleaned.replacingOccurrences(of: "\u{034F}", with: "") // Combining Grapheme Joiner
        cleaned = cleaned.replacingOccurrences(of: "\u{00AD}", with: "") // Soft Hyphen
        
        return cleaned
    }
    
    /// Remove tracking parameters from URLs (UTM, platform-specific tracking)
    /// - Parameter text: Text containing URLs
    /// - Returns: Text with cleaned URLs (tracking parameters removed)
    private func removeURLTracking(from text: String) -> String {
        // Find all URLs in the text using a comprehensive regex
        let urlPattern = "(https?://[^\\s]+|www\\.[^\\s]+)"
        guard let regex = try? NSRegularExpression(pattern: urlPattern, options: []) else {
            return text
        }
        
        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        
        var cleaned = text
        
        // Process matches in reverse to maintain string indices
        for match in matches.reversed() {
            let urlString = nsText.substring(with: match.range)
            if let cleanedURL = cleanURL(urlString) {
                cleaned = (cleaned as NSString).replacingCharacters(in: match.range, with: cleanedURL)
            }
        }
        
        return cleaned
    }
    
    /// Clean a single URL by removing tracking parameters
    /// - Parameter urlString: The URL string to clean
    /// - Returns: Cleaned URL string, or nil if URL cannot be parsed
    private func cleanURL(_ urlString: String) -> String? {
        // Ensure URL has a scheme
        var fullURL = urlString
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            fullURL = "https://" + urlString
        }
        
        guard var components = URLComponents(string: fullURL) else {
            return nil
        }
        
        let host = components.host?.lowercased() ?? ""
        
        // Remove tracking query parameters based on platform
        if let queryItems = components.queryItems {
            var filteredItems = queryItems
            
            // Universal tracking parameters (all platforms)
            let universalTracking = [
                "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
                "utm_id", "utm_source_platform", "utm_creative_format", "utm_marketing_tactic"
            ]
            
            // Platform-specific tracking parameters
            let platformTracking: [String: [String]] = [
                "youtube.com": ["si", "feature", "app", "source_ve_path", "gclid"],
                "youtu.be": ["si", "feature", "app", "gclid"],
                "open.spotify.com": ["si", "context", "nd"],
                "spotify.com": ["si", "context", "nd"],
                "amazon.com": ["crid", "dib", "dib_tag", "keywords", "qid", "sprefix", "sr",
                               "pd_rd_w", "pf_rd_s", "pf_rd_p", "pf_rd_t", "pf_rd_i",
                               "pf_rd_m", "pf_rd_r", "pd_rd_wg", "pd_rd_r", "linkCode",
                               "tag", "linkId", "geniuslink", "ref", "ref_", "content-id",
                               "psc", "th"],
                "google.com": ["gs_lcrp", "gs_lp", "sca_esv", "ei", "iflsig", "sclient",
                               "rlz", "bih", "biw", "dpr", "ved", "sa", "fbs", "source",
                               "sourceid", "gclid", "gclsrc"],
                "instagram.com": ["igsh", "igshid", "img_index"],
                "x.com": ["s", "t", "ref_src", "ref_url"],
                "twitter.com": ["s", "t", "ref_src", "ref_url"],
                "walmart.com": ["from", "sid", "athbdg", "athancid", "athcpid", "athena"],
                "facebook.com": ["fbclid", "mibextid"],
                "tiktok.com": ["_r", "_t", "is_from_webapp", "sender_device"]
            ]
            
            // Get platform-specific tracking params
            var trackingParams = Set(universalTracking)
            for (domain, params) in platformTracking {
                if host.contains(domain) {
                    trackingParams.formUnion(params)
                }
            }
            
            // Filter out tracking parameters
            filteredItems = filteredItems.filter { item in
                !trackingParams.contains(item.name.lowercased())
            }
            
            // Update query items (or remove if empty)
            components.queryItems = filteredItems.isEmpty ? nil : filteredItems
        }
        
        // Remove Amazon /ref= path segments
        if host.contains("amazon.com") && components.path.contains("/ref=") {
            if let refRange = components.path.range(of: "/ref=") {
                components.path = String(components.path[..<refRange.lowerBound])
            }
        }
        
        // Return cleaned URL (remove scheme if original didn't have it)
        guard let cleanedURL = components.string else {
            return urlString
        }
        
        if urlString.hasPrefix("www.") {
            return cleanedURL.replacingOccurrences(of: "https://", with: "")
        }
        
        return cleanedURL
    }
}

