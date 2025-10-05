# 🔐 Xcode Certificate Setup Guide for Clnbrd

This guide will walk you through setting up Xcode with the correct certificates to build and distribute Clnbrd.

## ✅ Fixed Issues

I've updated your project configuration to fix a certificate type mismatch:
- **Changed from**: "Developer ID Installer" (for .pkg installers)
- **Changed to**: "Apple Development" with Automatic signing for development builds

## 🎯 Two Signing Approaches

### Option 1: Automatic Signing (Recommended for Development)

**Best for**: Development, testing, and local builds

**Current Configuration**: ✅ Already set up!

#### What's Already Configured:
- Code Sign Style: `Automatic`
- Code Sign Identity: `Apple Development`
- Development Team: `Q7A38DCZ98`
- Bundle Identifier: `com.allanray.Clnbrd`

#### Steps to Build in Xcode:

1. **Open the Project**
   ```bash
   open /Users/allanalomes/Documents/AlsApp/Clnbrd/Clnbrd/Clnbrd.xcodeproj
   ```

2. **Verify Team Settings**
   - Select the project in the navigator (blue icon at top)
   - Select the "Clnbrd" target
   - Go to "Signing & Capabilities" tab
   - Verify "Team" shows your Apple ID / Team: `Q7A38DCZ98`
   - Verify "Automatically manage signing" is checked ✅

3. **Build the App**
   - Select "Product" → "Build" (⌘B)
   - Or click the Play button to build and run

**That's it!** Xcode will automatically:
- Create development certificates if needed
- Provision the app
- Sign it for local testing

---

### Option 2: Manual Signing (Required for Distribution)

**Best for**: Distribution, notarization, and DMG creation

**When to Use**: When creating builds for others or distributing outside App Store

#### Prerequisites:

1. **Apple Developer Account** ($99/year)
   - Sign up at [developer.apple.com](https://developer.apple.com)

2. **Developer ID Application Certificate**
   - Go to: [developer.apple.com/account/resources/certificates](https://developer.apple.com/account/resources/certificates)
   - Click "+" to create a new certificate
   - Select "Developer ID Application"
   - Follow steps to generate CSR (Certificate Signing Request):
     1. Open "Keychain Access" on your Mac
     2. Menu: Keychain Access → Certificate Assistant → Request a Certificate from a Certificate Authority
     3. Enter your email, name, select "Saved to disk"
     4. Upload the CSR file to Apple Developer Portal
   - Download the certificate and double-click to install

3. **Verify Certificate Installation**
   ```bash
   security find-identity -v -p codesigning
   ```
   
   You should see:
   ```
   1) ABC123... "Developer ID Application: Your Name (Q7A38DCZ98)"
   ```

#### Configure Manual Signing:

When you're ready to distribute, you'll need to switch to manual signing:

1. **In Xcode**:
   - Select the project → Target → Signing & Capabilities
   - **Uncheck** "Automatically manage signing"
   - Under "Signing Certificate", select "Developer ID Application"
   - Under "Provisioning Profile", select "None" (for Developer ID)

2. **Or Update project.pbxproj** directly (both Debug and Release):
   ```
   CODE_SIGN_STYLE = Manual;
   CODE_SIGN_IDENTITY = "Developer ID Application";
   ```

---

## 🚀 Complete Build Workflow

### For Development (Daily Work):

```bash
# Open Xcode
open /Users/allanalomes/Documents/AlsApp/Clnbrd/Clnbrd/Clnbrd.xcodeproj

# In Xcode: Press ⌘B to build, or ⌘R to build and run
```

**Current Setup**: ✅ Ready to use with Automatic signing!

### For Distribution (Creating DMG for others):

```bash
# 1. Switch to Manual signing in Xcode (see Option 2 above)

# 2. Use the build script
cd /Users/allanalomes/Documents/AlsApp/Clnbrd
./build_distribution.sh

# This will:
# - Build with Developer ID Application certificate
# - Notarize with Apple
# - Create a signed DMG
```

---

## 🔍 Troubleshooting

### Issue: "No signing certificate found"

**Solution**:
1. Make sure you're signed into your Apple ID in Xcode:
   - Xcode → Settings → Accounts
   - Add your Apple ID if not present
   - Select your team: `Q7A38DCZ98`

2. For automatic signing, Xcode will create certificates for you
3. For manual signing, follow Option 2 prerequisites above

### Issue: "Provisioning profile doesn't match"

**Solution**:
- For **Development**: Use Automatic signing (already configured!)
- For **Distribution**: Use Manual signing with "Developer ID Application"

### Issue: "Untrusted Developer" when running the app

**Solution**:
This is normal for Developer ID signed apps on first run:
1. Right-click the app → Open
2. Or go to System Settings → Privacy & Security → Allow

### Issue: Build succeeds but app won't run

**Solution**:
1. Check Console.app for crash logs
2. Verify entitlements match the certificate:
   ```bash
   codesign -d --entitlements - /path/to/Clnbrd.app
   ```
3. Make sure accessibility permissions are granted

---

## 📊 Current Project Status

✅ **Configured for Development**:
- Automatic code signing enabled
- Development Team set: `Q7A38DCZ98`
- Bundle ID: `com.allanray.Clnbrd`
- Entitlements: Sandbox, Network, USB, Apple Events

🔄 **Switching Between Modes**:
- **Development** (current): Just open and build in Xcode
- **Distribution**: Switch to Manual signing and use `build_distribution.sh`

---

## 🎯 Quick Reference

### Build in Xcode (Development)
```bash
open /Users/allanalomes/Documents/AlsApp/Clnbrd/Clnbrd/Clnbrd.xcodeproj
# Press ⌘B to build
```

### Build for Distribution
```bash
cd /Users/allanalomes/Documents/AlsApp/Clnbrd
./build_distribution.sh
```

### Check Certificate
```bash
security find-identity -v -p codesigning
```

### Verify App Signature
```bash
codesign -dvvv /path/to/Clnbrd.app
```

---

## 🎉 You're Ready!

Your project is now configured for easy development in Xcode:
1. ✅ Automatic signing enabled
2. ✅ Development team configured
3. ✅ Entitlements set up
4. ✅ Build settings optimized

**Just open the project in Xcode and hit ⌘B to build!**

When you're ready to distribute, follow Option 2 to switch to manual signing with Developer ID certificates.

