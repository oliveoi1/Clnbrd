# Clnbrd DMG Installer Creation

This directory contains scripts to create professional DMG installers for Clnbrd with the classic "drag to Applications folder" interface.

## Scripts Available

### 1. `create_dmg.sh` - Basic DMG Creator
- Creates a simple DMG with drag-to-Applications interface
- Basic background and layout
- Good for quick testing

### 2. `create_dmg_pro.sh` - Professional DMG Creator ⭐ **RECOMMENDED**
- Creates a beautiful DMG with custom styling
- Professional gradient background
- Enhanced visual layout
- Better user experience

## Prerequisites

Before running the scripts, ensure you have:

1. **Built the Clnbrd app** - The app should be located at `../Clnbrd.app`
2. **Python 3** with PIL (Pillow) - For creating background images
3. **macOS** - Scripts use macOS-specific tools

### Install Python Dependencies
```bash
pip3 install Pillow
```

## Usage

### Quick Start (Professional Version)
```bash
./create_dmg_pro.sh
```

### Basic Version
```bash
./create_dmg.sh
```

## What the Scripts Do

1. **Create Temporary DMG** - Builds a writable DMG from your app
2. **Mount DMG** - Mounts it for customization
3. **Add Applications Alias** - Creates the drag-to-Applications folder
4. **Create Background** - Generates a beautiful background image
5. **Configure Layout** - Sets up window properties and icon positions
6. **Compress DMG** - Creates the final compressed installer
7. **Clean Up** - Removes temporary files

## Output

The script creates:
- `Clnbrd-1.3.dmg` - Your professional installer
- Automatic verification and testing
- Size and success confirmation

## DMG Features

- ✅ **Drag-to-Applications Interface** - Classic macOS installer experience
- ✅ **Professional Background** - Beautiful gradient with app branding
- ✅ **Proper Icon Layout** - App icon and Applications folder positioned correctly
- ✅ **Compressed Size** - Optimized for distribution
- ✅ **Automatic Testing** - Verifies the DMG works correctly

## Troubleshooting

### Common Issues

1. **"App not found"** - Make sure `../Clnbrd.app` exists
2. **"Python PIL error"** - Install Pillow: `pip3 install Pillow`
3. **"Permission denied"** - Make scripts executable: `chmod +x *.sh`

### Manual Testing

After creation, test your DMG:
1. Double-click the DMG file
2. Verify the drag-to-Applications interface appears
3. Test dragging the app to Applications
4. Verify the app works after installation

## Distribution

Your DMG is ready for:
- Direct distribution to users
- Upload to your website
- GitHub releases
- App distribution platforms

## Customization

To customize the DMG further:
- Edit the background image in `create_dmg_pro.sh`
- Modify window dimensions and icon positions
- Change colors and styling
- Add additional branding elements
