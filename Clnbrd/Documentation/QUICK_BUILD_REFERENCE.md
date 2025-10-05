# 🚀 Quick Build Reference - Clnbrd

## Build in Xcode (Easiest!)

### Open and Build:
```bash
open /Users/allanalomes/Documents/AlsApp/Clnbrd/Clnbrd/Clnbrd.xcodeproj
```

Then in Xcode:
- Press **⌘B** to build
- Press **⌘R** to build and run

### What's Already Set Up:
✅ Automatic code signing  
✅ Development team: Q7A38DCZ98  
✅ Bundle ID: com.allanray.Clnbrd  
✅ All entitlements configured  

**No additional setup needed for development!**

---

## Build from Terminal

### For Development:
```bash
cd /Users/allanalomes/Documents/AlsApp/Clnbrd/Clnbrd
xcodebuild -project Clnbrd.xcodeproj -scheme Clnbrd -configuration Debug
```

### For Distribution (DMG):
```bash
cd /Users/allanalomes/Documents/AlsApp/Clnbrd
./build_distribution.sh
```

---

## Troubleshooting

### "No certificate found"
- Sign into Xcode: **Xcode → Settings → Accounts** → Add your Apple ID

### "Can't open app - unidentified developer"
- Right-click the app → **Open** (bypass security check)

### Certificate Issues
- Check: `security find-identity -v -p codesigning`
- See full guide: `XCODE_CERTIFICATE_SETUP.md`

---

## Documentation

📖 **Full Setup Guide**: [XCODE_CERTIFICATE_SETUP.md](XCODE_CERTIFICATE_SETUP.md)  
🏢 **Professional Distribution**: [PROFESSIONAL_SETUP_GUIDE.md](PROFESSIONAL_SETUP_GUIDE.md)  
📦 **DMG Creation**: [DMG_ARCHIVING_GUIDE.md](DMG_ARCHIVING_GUIDE.md)

---

**TL;DR**: Just open the project in Xcode and press ⌘B to build! Everything is already configured.

