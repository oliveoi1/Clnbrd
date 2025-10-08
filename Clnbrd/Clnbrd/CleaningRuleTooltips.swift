import Foundation

/// Centralized tooltip definitions for all cleaning rules
/// Provides consistent, example-rich descriptions for the Settings UI
struct CleaningRuleTooltips {
    
    // MARK: - Basic Text Cleaning Rules
    
    static let removeZeroWidthChars = """
    Removes invisible AI watermarks and hidden Unicode.
    
    Example:
      Before: "Hello\u{200B}World" (has invisible space)
      After:  "HelloWorld"
    
    Removes: Zero-width spaces, joiners, variation selectors
    """
    
    static let removeEmdashes = """
    Replaces em-dashes with commas.
    
    Example:
      Before: "Hello—world"
      After:  "Hello, world"
    
    Also removes: En-dashes (–)
    """
    
    static let normalizeSpaces = """
    Converts multiple consecutive spaces to one.
    
    Example:
      Before: "Hello    world"
      After:  "Hello world"
    
    Perfect for: Cleaning up copied text from PDFs
    """
    
    static let convertSmartQuotes = """
    Converts curly quotes to standard quotes.
    
    Example:
      Before: "Hello 'world'"
      After:  "Hello 'world'"
    
    Converts: " " → " and ' ' → '
    """
    
    static let normalizeLineBreaks = """
    Converts all line break types to standard Unix format.
    
    Example:
      Before: "Line1\\r\\nLine2" (Windows)
      After:  "Line1\\nLine2" (Unix)
    
    Also fixes: Mac Classic (\\r) and mixed line endings
    """
    
    static let removeTrailingSpaces = """
    Removes spaces at the end of each line.
    
    Example:
      Before: "Hello world   \\n"
      After:  "Hello world\\n"
    
    Useful for: Code, markdown, and clean text formatting
    """
    
    static let removeEmojis = """
    Removes all emoji characters.
    
    Example:
      Before: "Hello 🌎 world! 🎉"
      After:  "Hello  world! "
    
    Removes: All Unicode emoji blocks and emoji modifiers
    """
    
    // MARK: - Advanced Cleaning Rules
    
    static let removeExtraLineBreaks = """
    Limits consecutive line breaks to 2 maximum.
    
    Example:
      Before: "Para1\\n\\n\\n\\n\\nPara2"
      After:  "Para1\\n\\nPara2"
    
    Perfect for: Cleaning up copied articles and documents
    """
    
    static let removeLeadingTrailingWhitespace = """
    Trims spaces and tabs from start and end of text.
    
    Example:
      Before: "   Hello world   "
      After:  "Hello world"
    
    Also removes: Leading/trailing tabs and other whitespace
    """
    
    static let removeUrlTracking = """
    Strips tracking from URLs (150+ parameters!).
    
    Examples:
      Before: "https://youtu.be/VIDEO?si=xyz123"
      After:  "https://youtu.be/VIDEO"
    
      Before: "https://amazon.com/product/ref=abc?tag=aff&keywords=test"
      After:  "https://amazon.com/product"
    
      Before: "https://example.com/page?utm_source=twitter&page=2"
      After:  "https://example.com/page?page=2"
    
    Removes: UTM parameters, fbclid, gclid, igshid, ttclid,
    Amazon /ref= paths, and 150+ other tracking parameters
    from 18+ platforms!
    
    Preserves: Legitimate query parameters (q, page, id, v, etc.)
    
    💡 Tip: Use BOTH "Remove URL tracking" and "Remove URL protocols"
    to get the cleanest URLs for spreadsheets!
    
    Combined result:
      Before: "https://youtu.be/VIDEO?si=xyz123"
      After:  "youtu.be/VIDEO" (tracking + protocol removed!)
    """
    
    static let removeUrls = """
    Strips URL protocols but keeps domain visible.
    
    Examples:
      Before: "Check out https://example.com and www.test.com"
      After:  "Check out example.com and test.com"
    
      Before: "Visit https://github.com/user/repo"
      After:  "Visit github.com/user/repo"
    
    Removes: https://, http://, ftp://, www.
    Keeps: Domain and path visible
    
    Perfect for: Excel/Sheets paste values!
    Excel's ⌘⇧V keeps hyperlinks, Clnbrd removes them.
    """
    
    static let removeHtmlTags = """
    Removes HTML markup and entities.
    
    Example:
      Before: "<b>Hello</b> &nbsp; world!"
      After:  "Hello  world!"
    
      Before: "<p>Text</p><br>"
      After:  "Text"
    
    Removes: All HTML tags (<tag>) and entities (&entity;)
    """
    
    static let removeExtraPunctuation = """
    Removes excessive punctuation.
    
    Example:
      Before: "What!?!?!? Really???"
      After:  "What!? Really?"
    
      Before: "Wait........."
      After:  "Wait."
    
    Cleans: Multiple periods, exclamation marks, question marks
    """
    
    // MARK: - Rule Verification
    
    /// Returns all tooltip properties for validation
    static var allTooltips: [String: String] {
        return [
            "removeZeroWidthChars": removeZeroWidthChars,
            "removeEmdashes": removeEmdashes,
            "normalizeSpaces": normalizeSpaces,
            "convertSmartQuotes": convertSmartQuotes,
            "normalizeLineBreaks": normalizeLineBreaks,
            "removeTrailingSpaces": removeTrailingSpaces,
            "removeEmojis": removeEmojis,
            "removeExtraLineBreaks": removeExtraLineBreaks,
            "removeLeadingTrailingWhitespace": removeLeadingTrailingWhitespace,
            "removeUrlTracking": removeUrlTracking,
            "removeUrls": removeUrls,
            "removeHtmlTags": removeHtmlTags,
            "removeExtraPunctuation": removeExtraPunctuation
        ]
    }
    
    /// Verify all tooltips are non-empty
    static func validateTooltips() -> Bool {
        return allTooltips.allSatisfy { !$0.value.isEmpty }
    }
    
    /// Count of defined tooltips (should match number of cleaning rules)
    static var count: Int {
        return allTooltips.count
    }
}

