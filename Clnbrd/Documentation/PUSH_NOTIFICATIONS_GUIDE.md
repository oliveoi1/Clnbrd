# Clnbrd Push Notification System Setup Guide

## Overview
Your Clnbrd app now has a comprehensive push notification system for updates! Here's what's been implemented and how to set it up.

## ✅ What's Already Implemented

### 1. **Automatic Update Checking**
- Checks for updates on app launch (with 3-second delay)
- Periodic checks every 24 hours
- Checks when app becomes active
- Rate limiting (max once every 6 hours)

### 2. **Push-Style Notifications**
- Native macOS notifications with action buttons
- "Download" and "Later" buttons
- Sound notifications
- Persistent until user interacts

### 3. **Menu Bar Integration**
- Sends notifications to MenuBarManager for visual updates
- Can show update indicators in menu bar

## 🚀 How to Set Up Push Notifications

### Option 1: Simple JSON File (Current Setup)
Your current setup uses a JSON file hosted on Amazon S3. To push updates:

1. **Update your JSON file** at `AppConstants.versionCheckURL`:
```json
{
  "version": "1.4",
  "download_url": "https://your-domain.com/Clnbrd-1.4.dmg",
  "release_notes": "• New feature: Smart clipboard detection\n• Bug fixes and performance improvements\n• Enhanced accessibility support"
}
```

2. **Users will automatically receive notifications** when they:
   - Launch the app
   - Switch back to the app
   - Every 24 hours (if app is running)

### Option 2: Advanced Push Service (Recommended)
For more control, implement a push service:

#### A. Create a Simple Push Service
```python
# push_service.py
from flask import Flask, request, jsonify
import requests
import json

app = Flask(__name__)

@app.route('/push-update', methods=['POST'])
def push_update():
    data = request.json
    version = data['version']
    download_url = data['download_url']
    release_notes = data['release_notes']
    
    # Store update info
    update_info = {
        'version': version,
        'download_url': download_url,
        'release_notes': release_notes,
        'timestamp': time.time()
    }
    
    # Save to your S3 bucket or database
    save_update_info(update_info)
    
    return jsonify({'status': 'success'})

@app.route('/check-updates', methods=['GET'])
def check_updates():
    # Return latest update info
    return jsonify(get_latest_update())
```

#### B. Deploy the Service
- Deploy to AWS Lambda, Google Cloud Functions, or any hosting service
- Update `AppConstants.versionCheckURL` to point to your service

#### C. Push Updates via API
```bash
curl -X POST https://your-service.com/push-update \
  -H "Content-Type: application/json" \
  -d '{
    "version": "1.4",
    "download_url": "https://your-domain.com/Clnbrd-1.4.dmg",
    "release_notes": "• New feature: Smart clipboard detection\n• Bug fixes and performance improvements"
  }'
```

## 📱 User Experience

### When an Update is Available:
1. **Push Notification** appears with:
   - Title: "🚀 Clnbrd Update Available!"
   - Subtitle: "Version 1.4 is ready"
   - Action buttons: "Download" and "Later"

2. **Detailed Dialog** shows:
   - Current vs. latest version
   - Release notes
   - Download/Skip/Later options

3. **Menu Bar** can show update indicator

### User Actions:
- **Download**: Opens download URL in browser
- **Skip**: Won't show this version again
- **Later**: Will check again next time

## 🔧 Configuration Options

### Update Check Frequency
Modify in `setupPeriodicUpdateChecking()`:
```swift
// Check every 12 hours instead of 24
let timer = Timer.scheduledTimer(withTimeInterval: 43200, repeats: true) { [weak self] _ in
    self?.checkForUpdates()
}
```

### Rate Limiting
Modify in `checkForUpdates()`:
```swift
// Check every 2 hours instead of 6
if timeSinceLastCheck < 7200 { // 2 hours in seconds
    return
}
```

### Notification Settings
Users can disable notifications in System Preferences > Notifications > Clnbrd

## 🎯 Testing the System

### Test Update Notification:
1. Update your JSON file with a higher version number
2. Launch Clnbrd
3. You should see the push notification within 3 seconds

### Test Rate Limiting:
1. Check for updates manually
2. Try again immediately - should be blocked
3. Wait 6 hours and try again - should work

## 📊 Analytics Integration

The system integrates with your existing analytics:
- Tracks when updates are checked
- Tracks user responses (download/skip/later)
- Tracks notification delivery

## 🚀 Next Steps

1. **Deploy your updated app** with the new notification system
2. **Set up your push service** (Option 2 recommended)
3. **Test the system** with a test update
4. **Monitor analytics** to see update adoption rates

Your users will now receive timely, professional update notifications that encourage them to stay current with the latest version!
