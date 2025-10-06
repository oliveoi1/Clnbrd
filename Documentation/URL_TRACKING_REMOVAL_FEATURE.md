# URL Tracking Removal Feature

## Overview

Extend Clnbrd's clipboard cleaning to automatically remove tracking parameters and affiliate cruft from URLs. This feature makes copied links cleaner, more private, and easier to share.

## Why This Feature?

**Privacy Benefits:**
- Removes tracking parameters that let companies follow you across the web
- Strips affiliate IDs that track click attribution
- Makes links anonymous and non-traceable

**Usability Benefits:**
- Shorter, cleaner URLs
- Easier to read and share
- No broken links from expired tracking tokens

**Examples:**

**Before:**
```
https://www.amazon.com/product/B08N5WRWNW/ref=sr_1_1?crid=ABC123&keywords=headphones&qid=1234567890&sprefix=head%2Caps%2C123&sr=8-1
```

**After:**
```
https://www.amazon.com/product/B08N5WRWNW
```

## Implementation Plan

### Phase 1: Core Functionality ✅
- [x] Create URLTrackingCleaner class
- [x] Implement global tracking parameter removal (utm_*, fbclid, gclid, etc.)
- [x] Implement site-specific rules for major platforms
- [x] Add pattern-based path cleaning (e.g., Amazon /ref=)

### Phase 2: Integration (In Progress)
- [ ] Integrate with ClipboardManager
- [ ] Add preference toggle: "Clean tracking from URLs"
- [ ] Add to preferences UI
- [ ] Test with real-world URLs

### Phase 3: Testing & Refinement
- [ ] Unit tests for URLTrackingCleaner
- [ ] Test with edge cases (malformed URLs, no parameters, etc.)
- [ ] Performance testing (regex on large text blocks)
- [ ] User testing with common scenarios

### Phase 4: Extended Support
- [ ] Add Facebook-specific rules
- [ ] Add LinkedIn tracking removal
- [ ] Add Reddit tracking removal
- [ ] Configuration file for user-customizable rules

## Supported Platforms

### ✅ Fully Implemented
- **YouTube/youtu.be** - Removes `?si=...` tracking
- **Spotify** - Removes `?si=...` tracking  
- **Amazon** - Removes affiliate tags, tracking IDs, `/ref=` paths
- **Google** - Removes search tracking while keeping query
- **Instagram** - Removes `?igsh=...` tracking
- **Twitter/X** - Removes `?s=...&t=...` tracking
- **Walmart** - Removes `?from=...&sid=...` tracking
- **TikTok** - Removes copy tracking parameters

### 🔄 Planned
- **Facebook** - Complex tracking removal
- **LinkedIn** - Professional network tracking
- **Reddit** - Thread tracking parameters
- **Medium** - Article source tracking

### 🌐 Universal
All sites get:
- UTM parameter removal (`utm_source`, `utm_medium`, etc.)
- Facebook click ID removal (`fbclid`)
- Google click ID removal (`gclid`, `gclsrc`)
- Email tracking removal (MailChimp, HubSpot, Marketo)

## User Interface

### Preferences Panel Addition

```
┌─────────────────────────────────────────┐
│ Clipboard Cleaning Options              │
├─────────────────────────────────────────┤
│ ☑ Remove text formatting                │
│ ☑ Remove tracking from URLs             │
│   ├─ Clean UTM parameters               │
│   ├─ Clean affiliate links              │
│   └─ Clean site-specific tracking       │
└─────────────────────────────────────────┘
```

### Menu Bar Status
Show when URL cleaning happens:
- "Cleaned text + 1 URL" 
- "Cleaned 3 URLs from clipboard"

## Technical Details

### Architecture
```
ClipboardManager
    ↓ (if URL cleaning enabled)
URLTrackingCleaner.cleanURLsInText(text)
    ↓
1. Detect URLs with regex
2. Parse each URL
3. Apply global rules
4. Apply site-specific rules
5. Reconstruct clean URL
6. Replace in text
```

### Performance Considerations
- Regex URL detection: Fast for typical clipboard sizes (<10KB)
- URL parsing: Native Foundation URLComponents (optimized)
- Only processes text containing "http" (quick pre-check)
- No network requests (all local processing)

### Privacy
- **100% local processing** - no URLs sent to servers
- **No logging** - cleaned URLs are not stored
- **Optional feature** - user can disable if desired

## Testing Strategy

### Unit Tests
```swift
// Test global tracking removal
testRemoveUTMParameters()
testRemoveFacebookTracking()
testRemoveGoogleTracking()

// Test site-specific rules
testCleanYouTubeURL()
testCleanAmazonURL()
testCleanSpotifyURL()
testCleanInstagramURL()

// Test edge cases
testMalformedURL()
testURLWithoutParameters()
testMultipleURLsInText()
testNonHTTPText()
```

### Manual Testing Checklist
- [ ] Copy YouTube video link → Verify `?si=` removed
- [ ] Copy Amazon product → Verify `/ref=` and tags removed
- [ ] Copy Google search → Verify tracking removed, query kept
- [ ] Copy text with multiple URLs → All cleaned
- [ ] Toggle preference → Feature enables/disables correctly
- [ ] Performance with large paste (100+ URLs)

## Configuration

### Future: User-Customizable Rules

Allow power users to add custom rules:

```json
{
  "customRules": [
    {
      "domain": "mysite.com",
      "removeParams": ["tracking_id", "source"],
      "keepParams": ["id", "page"]
    }
  ]
}
```

## Release Notes Template

### v1.4 - URL Tracking Removal

**New Feature: URL Tracking Cleaner 🔗**

Clnbrd now automatically removes tracking parameters and affiliate cruft from URLs in your clipboard!

**What's Cleaned:**
- UTM tracking parameters (utm_source, utm_medium, etc.)
- Affiliate tracking IDs
- Site-specific tracking:
  - YouTube: `?si=...`
  - Amazon: `/ref=...` and tracking tags
  - Instagram: `?igsh=...`
  - Twitter/X: `?s=...&t=...`
  - And more!

**How to Use:**
- Works automatically with your clipboard cleaning
- Toggle in Preferences → "Clean tracking from URLs"
- 100% local processing, completely private

**Privacy First:**
- All processing happens on your Mac
- No URLs are sent to any server
- No logging or storage of cleaned URLs

Share cleaner, more private links! 🎉

## Future Enhancements

1. **Statistics**: Show how many tracking params removed (lifetime counter)
2. **Whitelist**: Allow specific domains to keep tracking
3. **Link Shortener Expansion**: Resolve t.co, bit.ly before cleaning
4. **AMP Link Removal**: Strip Google AMP wrappers
5. **Redirect Unwrapping**: Follow redirects to get final clean URL

## Resources

- [ClearURLs Rules](https://github.com/ClearURLs/Rules) - Similar browser extension
- [Neat URL](https://github.com/Smile4ever/Neat-URL) - Another reference implementation
- [URL Tracking Parameters Database](https://github.com/newhouse/url-tracking-stripper)

---

**Author:** Allan Alomes  
**Created:** October 6, 2025  
**Status:** In Development  
**Branch:** `feature/url-tracking-removal`

