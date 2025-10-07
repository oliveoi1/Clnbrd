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
        
        // Remove URLs
        if removeUrls {
            cleaned = cleaned.replacingOccurrences(of: "https?://[^\\s]+", with: "", options: .regularExpression)
            cleaned = cleaned.replacingOccurrences(of: "ftp://[^\\s]+", with: "", options: .regularExpression)
            cleaned = cleaned.replacingOccurrences(of: "www\\.[^\\s]+", with: "", options: .regularExpression)
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
}

