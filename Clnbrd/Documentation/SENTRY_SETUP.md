# Sentry Setup Instructions for Clnbrd

## 🚀 Getting Started with Sentry

### 1. Create Sentry Account
1. Go to [sentry.io](https://sentry.io)
2. Sign up for a free account
3. Create a new project for "Clnbrd"

### 2. Get Your DSN
1. In Sentry dashboard, go to **Settings** → **Projects** → **Clnbrd**
2. Click **Client Keys (DSN)**
3. Copy the DSN URL (looks like: `https://abc123@o123456.ingest.sentry.io/123456`)

### 3. Update SentryManager.swift
✅ **Already configured!** Your DSN is already set in `SentryManager.swift`:

```swift
options.dsn = "https://6a8ed4b3ddf836bf196efbb890f5c713@o4510128805249024.ingest.us.sentry.io/4510128808656896"
```

### 4. Test Integration
Add this to your app for testing:

```swift
// In AppDelegate.swift, add a test button or menu item
@objc func testSentry() {
    SentryManager.shared.testCrashReporting()
}
```

## 📊 What You'll See in Sentry

### Error Reports
- **Stack traces** showing exactly where errors occur
- **User context** (anonymous user ID, app version, macOS version)
- **Breadcrumbs** showing user actions leading to errors
- **Custom context** (error type, additional data)

### Performance Monitoring
- **App launch time**
- **Memory usage** patterns
- **Network request** performance
- **User action** timing

### User Analytics
- **Feature usage** patterns
- **Error frequency** by feature
- **User journey** tracking
- **Crash-free users** percentage

## 🔒 Privacy & Security

### What Gets Sent
- ✅ Error messages and stack traces
- ✅ App version and build number
- ✅ macOS version (anonymized)
- ✅ User actions (anonymized)
- ✅ Performance metrics

### What Doesn't Get Sent
- ❌ Clipboard content
- ❌ Personal information
- ❌ File paths or names
- ❌ User identity

## 🎯 Benefits for Clnbrd

### 1. Proactive Issue Detection
- **Catch crashes** before users report them
- **Identify patterns** in error occurrences
- **Monitor performance** degradation

### 2. Better User Support
- **Detailed error context** for support tickets
- **User journey** leading to issues
- **System information** automatically included

### 3. Product Improvement
- **Feature usage** analytics
- **Error hotspots** identification
- **Performance bottlenecks** detection

## 🚨 Alert Configuration

### Set up alerts for:
- **New crashes** (immediate notification)
- **Error rate spikes** (daily/weekly reports)
- **Performance degradation** (weekly reports)

### Recommended alert thresholds:
- **Crash rate** > 1%
- **Error rate** > 5%
- **App launch time** > 3 seconds

## 📈 Monitoring Dashboard

### Key metrics to track:
- **Crash-free users** percentage
- **Error rate** by feature
- **Performance** trends
- **User engagement** patterns

## 🔧 Maintenance

### Regular tasks:
- **Review error reports** weekly
- **Update Sentry SDK** quarterly
- **Analyze performance** trends monthly
- **Clean up old data** annually

---

**Your Clnbrd app now has professional-grade error monitoring!** 🎉
