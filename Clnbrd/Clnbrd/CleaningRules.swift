import Foundation

/// Model for custom find/replace rules
struct CustomRule: Codable {
    let find: String
    let replace: String
}

/// Handles all text cleaning operations including AI watermark removal, formatting cleanup, and URL cleaning
class CleaningRules: Codable {
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
    
    init() {
        // Default initializer - all properties have default values
    }
    
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
        for rule in customRules where !rule.find.isEmpty {
            cleaned = cleaned.replacingOccurrences(of: rule.find, with: rule.replace)
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
        // Parse and validate URL
        guard var components = parseAndValidateURL(urlString) else {
            return nil
        }
        
        let host = components.host?.lowercased() ?? ""
        
        // Remove tracking parameters
        removeTrackingParameters(from: &components, host: host)
        
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
    
    // MARK: - URL Cleaning Helper Methods
    
    private func parseAndValidateURL(_ urlString: String) -> URLComponents? {
        // Ensure URL has a scheme
        var fullURL = urlString
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            fullURL = "https://" + urlString
        }
        
        return URLComponents(string: fullURL)
    }
    
    private func removeTrackingParameters(from components: inout URLComponents, host: String) {
        guard let queryItems = components.queryItems else { return }
        
        var filteredItems = queryItems
        
        // Universal tracking parameters (all platforms)
        let universalTracking = [
                // UTM Parameters (Google Analytics)
                "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
                "utm_name", "utm_id", "utm_source_platform", "utm_creative_format", "utm_marketing_tactic",
                
                // Social Media Click IDs
                "fbclid", "igshid", "ig_rid", "twclid", "li_source", "li_fat_id",
                "ttclid", "snapchatclid", "pnclid",
                
                // Search Engine Click IDs
                "gclid", "gclsrc", "dclid", "gbraid", "wbraid", "msclkid", "yclid",
                
                // Email Marketing
                "mc_cid", "mc_eid", "_hsenc", "_hsmi", "vero_id", "vero_conv",
                "nr_email_referer", "ck_subscriber_id",
                
                // Affiliate & Referral
                "ref", "referrer", "reference", "refer", "source", "affiliate_id",
                "aff_id", "aff_sub", "aff_sub2", "partner", "pcid", "wickedid",
                
                // Session & Analytics
                "_ga", "_gl", "_ke", "sessionid", "sid", "ssid", "session_id",
                
                // Mobile App Tracking
                "gf_campaign", "af_dp", "af_source", "af_c_id", "af_adset", "af_ad",
                "af_siteid", "pid", "c",
                
                // Marketing Automation
                "mbid", "trk_contact", "trk_msg", "trk_module", "trk_sid",
                "mkt_tok", "elqTrackId", "elqTrack", "assetType", "assetId",
                "recipientId", "campaignId",
                
                // Ad Networks
                "zanpid", "kclickid", "adgroupid", "adid", "campaignid", "guccounter",
                "soc_src", "soc_trk",
                
                // Adobe/Omniture
                "s_cid", "s_kwcid", "s_tnt", "sc_campaign", "sc_channel", "sc_content",
                "sc_geo", "sc_outcome",
                
                // Matomo/Piwik
                "mtm_campaign", "mtm_keyword", "mtm_source", "mtm_medium", "mtm_content",
                "mtm_cid", "mtm_group", "mtm_placement", "pk_campaign", "pk_kwd",
                "pk_keyword", "pk_source", "pk_medium", "pk_content", "pk_cid",
                
                // Yahoo/Verizon Media
                "ylid", "yclid", "_openstat",
                
                // Misc Common Trackers
                "ncid", "vgo_ee", "ml_subscriber", "ml_subscriber_hash",
                "oft_id", "oft_k", "oft_lk", "oft_d", "oft_c", "oft_ck", "oft_ids", "oft_sk",
                "oly_anon_id", "oly_enc_id", "rb_clickid", "hmb_campaign", "hmb_medium",
                "hmb_source", "mbsy", "mbsy_source", "redirect_log_mongo_id",
                "redirect_mongo_id", "sb_referer_host", "mkwid", "trackingId",
                
                // WeChat/Chinese Platforms
                "srcid", "isappinstalled", "nsukey",
                
                // Reddit
                "share_id", "share", "trc_click_source",
                
                // Mobile & App
                "_branch_match_id", "_branch_referrer",
                
                // Newsletter & Content
                "goal", "token", "subscriber",
                
                // General Tracking Patterns
                "click_id", "clickid", "tracking_id", "trackid", "tracker",
                "cid", "eid", "mid", "tid", "vid", "uid"
            ]
            
            // Platform-specific tracking parameters (in addition to universal tracking)
            let platformTracking: [String: [String]] = [
                "youtube.com": ["si", "feature", "app", "source_ve_path"],
                "youtu.be": ["si", "feature", "app"],
                "open.spotify.com": ["si", "context", "nd"],
                "spotify.com": ["si", "context", "nd"],
                "amazon.com": ["_encoding", "keywords", "qid", "sprefix", "sr", "th", "psc",
                               "crid", "dib", "dib_tag",
                               "pf_rd_r", "pf_rd_p", "pf_rd_m", "pf_rd_s", "pf_rd_t", "pf_rd_i",
                               "pd_rd_r", "pd_rd_w", "pd_rd_wg"],
                "google.com": ["gs_lcrp", "gs_lp", "sca_esv", "ei", "iflsig", "sclient",
                               "rlz", "bih", "biw", "dpr", "ved", "sa", "fbs"],
                "instagram.com": ["igsh", "igshid", "ig_rid", "img_index"],
                "x.com": ["s", "t", "ref_src", "ref_url"],
                "twitter.com": ["s", "t", "ref_src", "ref_url"],
                "walmart.com": ["athbdg", "athancid", "athcpid", "athena"],
                "facebook.com": ["mibextid"],
                "tiktok.com": ["_r", "_t", "is_from_webapp", "sender_device"],
                "reddit.com": ["share_id", "trc_click_source"],
                "linkedin.com": ["li_source", "li_fat_id"],
                "wechat.com": ["srcid", "isappinstalled", "nsukey", "from"],
                "pinterest.com": ["pnclid"],
                "snapchat.com": ["snapchatclid"]
            ]
            
            // Get platform-specific tracking params
            var trackingParams = Set(universalTracking)
            for (domain, params) in platformTracking where host.contains(domain) {
                trackingParams.formUnion(params)
            }
            
            // Filter out tracking parameters
            filteredItems = filteredItems.filter { item in
                !trackingParams.contains(item.name.lowercased())
            }
            
            // Update query items (or remove if empty)
            components.queryItems = filteredItems.isEmpty ? nil : filteredItems
        }
    
    // MARK: - Codable Implementation
    
    enum CodingKeys: String, CodingKey {
        case removeEmdashes, replaceEmdashWith, normalizeSpaces, removeZeroWidthChars
        case normalizeLineBreaks, removeTrailingSpaces, convertSmartQuotes, removeEmojis
        case removeExtraLineBreaks, removeLeadingTrailingWhitespace, removeUrlTracking
        case removeUrls, removeHtmlTags, removeExtraPunctuation, customRules
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        removeEmdashes = try container.decode(Bool.self, forKey: .removeEmdashes)
        replaceEmdashWith = try container.decode(String.self, forKey: .replaceEmdashWith)
        normalizeSpaces = try container.decode(Bool.self, forKey: .normalizeSpaces)
        removeZeroWidthChars = try container.decode(Bool.self, forKey: .removeZeroWidthChars)
        normalizeLineBreaks = try container.decode(Bool.self, forKey: .normalizeLineBreaks)
        removeTrailingSpaces = try container.decode(Bool.self, forKey: .removeTrailingSpaces)
        convertSmartQuotes = try container.decode(Bool.self, forKey: .convertSmartQuotes)
        removeEmojis = try container.decode(Bool.self, forKey: .removeEmojis)
        removeExtraLineBreaks = try container.decode(Bool.self, forKey: .removeExtraLineBreaks)
        removeLeadingTrailingWhitespace = try container.decode(Bool.self, forKey: .removeLeadingTrailingWhitespace)
        removeUrlTracking = try container.decode(Bool.self, forKey: .removeUrlTracking)
        removeUrls = try container.decode(Bool.self, forKey: .removeUrls)
        removeHtmlTags = try container.decode(Bool.self, forKey: .removeHtmlTags)
        removeExtraPunctuation = try container.decode(Bool.self, forKey: .removeExtraPunctuation)
        customRules = try container.decode([CustomRule].self, forKey: .customRules)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(removeEmdashes, forKey: .removeEmdashes)
        try container.encode(replaceEmdashWith, forKey: .replaceEmdashWith)
        try container.encode(normalizeSpaces, forKey: .normalizeSpaces)
        try container.encode(removeZeroWidthChars, forKey: .removeZeroWidthChars)
        try container.encode(normalizeLineBreaks, forKey: .normalizeLineBreaks)
        try container.encode(removeTrailingSpaces, forKey: .removeTrailingSpaces)
        try container.encode(convertSmartQuotes, forKey: .convertSmartQuotes)
        try container.encode(removeEmojis, forKey: .removeEmojis)
        try container.encode(removeExtraLineBreaks, forKey: .removeExtraLineBreaks)
        try container.encode(removeLeadingTrailingWhitespace, forKey: .removeLeadingTrailingWhitespace)
        try container.encode(removeUrlTracking, forKey: .removeUrlTracking)
        try container.encode(removeUrls, forKey: .removeUrls)
        try container.encode(removeHtmlTags, forKey: .removeHtmlTags)
        try container.encode(removeExtraPunctuation, forKey: .removeExtraPunctuation)
        try container.encode(customRules, forKey: .customRules)
    }
}
