# 🔔 Notarization Guide for Clnbrd

## ✅ Configuration Updated!

I've configured your project for notarization:

### Debug Configuration (Daily Development):
- **Team**: Q7A38DCZ98
- **Certificate**: Apple Development
- **Signing**: Automatic

### Release Configuration (Distribution/Notarization):
- **Team**: 58Y8VPZ7JG (Allan Alomes)
- **Certificate**: Developer ID Application
- **Signing**: Manual

---

## 🚀 Method 1: Notarize via Xcode (GUI)

### Step 1: Configure Apple ID in Xcode

1. **Open Xcode Settings**
   - Xcode → Settings (⌘,)
   - Go to "Accounts" tab

2. **Add Your Apple ID**
   - Click "+" to add Apple ID if not already there
   - Sign in with: `olivedesignstudios@gmail.com`
   - You should see both teams:
     - Q7A38DCZ98
     - **58Y8VPZ7JG (Allan Alomes)** ← Use this for notarization

3. **Generate App-Specific Password**
   - Go to: https://appleid.apple.com
   - Sign in with your Apple ID
   - Security → App-Specific Passwords
   - Generate password for "Xcode Notarization"
   - **Save this password** - you'll need it!

---

### Step 2: Archive Your App

1. **Open Your Project**
   ```bash
   open /Users/allanalomes/Documents/AlsApp/Clnbrd/Clnbrd/Clnbrd.xcodeproj
   ```

2. **Select "Any Mac" as destination**
   - At top of Xcode, click the scheme selector
   - Choose "Any Mac (Apple Silicon, Intel)"

3. **Create Archive**
   - Product → Archive (or ⌘⇧B)
   - Wait for build to complete
   - Organizer window will open automatically

---

### Step 3: Distribute and Notarize

1. **In the Organizer Window**
   - Select your latest archive
   - Click "Distribute App" button

2. **Choose Distribution Method**
   - Select **"Developer ID"**
   - Click "Next"

3. **Distribution Options**
   - Select **"Upload"** (to notarize with Apple)
   - Click "Next"

4. **Distribution Options**
   - ✅ Upload to Apple's notary service
   - ✅ Strip Swift symbols (optional)
   - Click "Next"

5. **Automatically manage signing**
   - Xcode will select: "Developer ID Application: Allan Alomes (58Y8VPZ7JG)"
   - Click "Next"

6. **Review and Upload**
   - Review the app info
   - Click "Upload"

7. **Wait for Notarization**
   - Apple will notarize your app (usually 5-15 minutes)
   - You'll get an email when complete
   - Status shows in Organizer

8. **Export Notarized App**
   - Once notarized, click "Export Notarized App"
   - Choose save location
   - Your app is now ready to distribute!

---

## 🖥️ Method 2: Notarize via Terminal (Automated)

This is what your `build_distribution.sh` script does automatically.

### Prerequisites:

1. **Create `.env` file** with your credentials:
   ```bash
   cd /Users/allanalomes/Documents/AlsApp/Clnbrd
   nano .env
   ```

2. **Add these lines**:
   ```bash
   APPLE_ID="olivedesignstudios@gmail.com"
   APPLE_PASSWORD="your-app-specific-password-here"
   TEAM_ID="58Y8VPZ7JG"
   ```

3. **Run the build script**:
   ```bash
   ./build_distribution.sh
   ```

   This will:
   - Build with Release configuration
   - Sign with Developer ID Application (58Y8VPZ7JG)
   - Upload to Apple for notarization
   - Wait for approval
   - Staple the notarization ticket
   - Create a signed DMG

---

## 🔍 Check Notarization Status

### Via Xcode:
- Window → Organizer → Archives
- Look for notarization status

### Via Terminal:
```bash
# List recent notarization submissions
xcrun notarytool history --apple-id "olivedesignstudios@gmail.com" --team-id "58Y8VPZ7JG"

# Check specific submission
xcrun notarytool info <submission-id> --apple-id "olivedesignstudios@gmail.com" --team-id "58Y8VPZ7JG"
```

### Via Email:
You'll receive an email from Apple at `olivedesignstudios@gmail.com` with the notarization result.

---

## ✅ Verify Notarization

After notarization is complete:

```bash
# Check if app is notarized
spctl -a -vv /path/to/Clnbrd.app

# Should show:
# source=Notarized Developer ID
```

```bash
# Check notarization ticket
stapler validate /path/to/Clnbrd.app

# Should show:
# The validate action worked!
```

---

## 🎯 Quick Reference

### For Development (Daily Work):
```bash
# Open Xcode and build
open Clnbrd.xcodeproj
# Press ⌘B or ⌘R
# Uses: Team Q7A38DCZ98, Apple Development certificate
```

### For Distribution (Notarized):
**Option A - Xcode GUI:**
```bash
open Clnbrd.xcodeproj
# Product → Archive
# Distribute App → Developer ID → Upload
# Uses: Team 58Y8VPZ7JG, Developer ID Application
```

**Option B - Terminal (Automated):**
```bash
cd /Users/allanalomes/Documents/AlsApp/Clnbrd
./build_distribution.sh
# Automatically uses Team 58Y8VPZ7JG
```

---

## 🚨 Troubleshooting

### "No valid code signing certificates found"
- Make sure you're using **Release** scheme (not Debug)
- Verify certificate: `security find-identity -v -p codesigning | grep "Developer ID Application"`

### "Authentication failed"
- Use an **app-specific password**, not your regular Apple ID password
- Generate one at: https://appleid.apple.com

### "Notarization failed"
- Check email from Apple for specific error
- Or run: `xcrun notarytool log <submission-id> --apple-id "your@email.com" --team-id "58Y8VPZ7JG"`

### "Wrong team ID"
- For notarization, use: **58Y8VPZ7JG** (Allan Alomes)
- This team has the Developer ID Application certificate

---

## 📋 Summary

**Your Configuration:**
- ✅ Debug builds use: Q7A38DCZ98 (Apple Development)
- ✅ Release builds use: 58Y8VPZ7JG (Developer ID Application)
- ✅ Ready for notarization from Xcode or Terminal

**Next Steps:**
1. Generate app-specific password at appleid.apple.com
2. Choose your method: Xcode Archive or `build_distribution.sh`
3. Notarize and distribute!

🎉 You're all set!

