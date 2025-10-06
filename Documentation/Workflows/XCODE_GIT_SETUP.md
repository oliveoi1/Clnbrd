# 🔧 Xcode Git Integration Setup Guide

## Step 1: Enable Source Control in Xcode

### Open Xcode Settings:
1. Open Xcode
2. Go to **Xcode → Settings...** (or press **⌘,**)
3. Click the **"Source Control"** tab

### Configure These Settings:

#### General Tab:
- ✅ **Enable source control**
- ✅ **Refresh local status automatically**
- ✅ **Fetch and refresh server status automatically**
- ✅ **Add and remove files automatically**
- ✅ **Select files to commit automatically**

#### Git Tab:
- ✅ **Author Name:** Allan Alomes
- ✅ **Author Email:** olivedesignstudios@gmail.com
- ✅ **Prefer to rebase when pulling** (optional, recommended)
- ✅ **Show source control changes** (shows M, A, D badges on files)

---

## Step 2: Add Your GitHub Account to Xcode

### Add Account:
1. In Xcode Settings, go to **"Accounts"** tab
2. Click the **"+"** button at bottom left
3. Select **"GitHub"**
4. Click **"Continue"**
5. **Sign in with your GitHub credentials:**
   - Username: `oliveoi1`
   - Personal Access Token: (the token you created earlier)
6. Click **"Sign In"**

**Why?** This allows Xcode to push/pull directly to GitHub without terminal!

---

## Step 3: Verify Source Control in Your Project

### Check Repository Status:
1. Open your project: `/Users/allanalomes/Documents/AlsApp/Clnbrd/Clnbrd/Clnbrd.xcodeproj`
2. Look at the **Navigator panel** (left side)
3. You should see **Source Control Navigator** (icon looks like a branch)
4. Or press **⌘2** to open Source Control Navigator

### What You Should See:
- **Branches** section
  - `main` (current branch, with a checkmark)
- **Tags** section (empty for now)
- **Remotes** section
  - `origin` (your GitHub repository)

---

## Step 4: View Source Control Menu

### In Xcode Menu Bar:
Go to **Source Control** menu - you should see:
- **Commit...** (⌘⌥C)
- **Push...** (⌘⌥P)
- **Pull...**
- **Fetch Changes**
- **Discard All Changes...**
- **New Branch...**
- **Switch Branch...**

If you don't see this menu, source control isn't enabled!

---

## Step 5: Enable File Status Indicators

### Show Git Status on Files:
1. In **Project Navigator** (⌘1)
2. Files should show badges:
   - **M** = Modified (yellow dot)
   - **A** = Added (green dot)
   - **D** = Deleted (red dot)
   - **?** = Untracked (gray dot)
   - **No badge** = Unchanged

**If you don't see badges:**
- Xcode → Settings → Source Control
- ✅ Check "Show source control changes"

---

## Step 6: Use Source Control in Xcode

### View Changes in a File:
1. Select any Swift file
2. Go to **Editor → Show Change**
3. Or click the **"Show Change"** button (looks like a person)
4. You'll see:
   - Green highlighting = Added lines
   - Red highlighting = Deleted lines
   - Side-by-side comparison

### Commit Changes:
1. Go to **Source Control → Commit...** (⌘⌥C)
2. Review your changes
3. Check boxes next to files you want to commit
4. Write commit message at bottom
5. Click **"Commit X Files"**

### Push to GitHub:
1. **Source Control → Push...** (⌘⌥P)
2. Select branch (usually `main`)
3. Click **"Push"**

### Create New Branch:
1. **Source Control → New Branch...**
2. Name it (e.g., `experiment/snake-game`)
3. Click **"Create"**
4. You're now on the new branch!

### Switch Branches:
1. **Source Control → Switch Branch...**
2. Select branch from list
3. Click **"Switch"**

---

## Step 7: View History

### See Commit History:
1. Open **Source Control Navigator** (⌘2)
2. Click on any commit to see:
   - Who made changes
   - When they were made
   - What files changed
   - Diff view of changes

### View File History:
1. Right-click any file
2. Select **"Show in Source Control"**
3. See all commits that touched that file

---

## Step 8: Compare Versions

### Compare Current vs. Previous:
1. Select a file
2. **Editor → Assistant**
3. Click the **history icon** (clock)
4. Choose version to compare with

### View Changes:
- **Editor → Show Change** (inline changes)
- **View → Navigators → Show Source Control Navigator** (⌘2)

---

## Keyboard Shortcuts (Learn These!)

| Action | Shortcut |
|--------|----------|
| Commit | **⌘⌥C** |
| Push | **⌘⌥P** |
| Source Control Navigator | **⌘2** |
| Show Changes | **⌘⌥⏎** then click change icon |
| Discard Changes | Right-click file → Discard Changes |

---

## Common Workflows in Xcode

### Workflow 1: Daily Changes
1. Make changes to files
2. Files show **M** badge
3. **Source Control → Commit** (⌘⌥C)
4. Write message, commit
5. **Source Control → Push** (⌘⌥P)

### Workflow 2: Experiment with New Feature
1. **Source Control → New Branch...**
2. Name: `experiment/feature-name`
3. Make changes
4. Test, commit as you go
5. When done:
   - If good: **Source Control → Merge...** → merge to main
   - If bad: **Source Control → Switch Branch** → main (abandons changes)

### Workflow 3: Undo Mistakes
1. Right-click file → **Show in Finder**
2. Right-click file → **Discard Changes in...**
3. Or: **Source Control → Discard All Changes**

---

## Troubleshooting

### "Source Control" Menu is Grayed Out
**Fix:**
1. Xcode → Settings → Source Control
2. ✅ Enable source control
3. Restart Xcode

### Can't See File Status Badges
**Fix:**
1. Xcode → Settings → Source Control
2. ✅ Show source control changes
3. ✅ Refresh local status automatically

### Can't Push to GitHub
**Fix:**
1. Make sure you added GitHub account (Step 2)
2. Or use Terminal: `git push`
3. Check credentials in Keychain Access

### Branch List is Empty
**Fix:**
1. Close and reopen project
2. Or: Source Control → Fetch Changes

---

## Best Practices

1. **Commit often** - Small, logical chunks
2. **Write clear messages** - "Added analytics tracking" not "changes"
3. **Test before committing** - Build (⌘B) and run (⌘R) first
4. **Pull before you push** - Get latest changes first
5. **Use branches for experiments** - Keep main clean
6. **Review changes before committing** - Use diff view

---

## Your Project Info

- **Project:** `/Users/allanalomes/Documents/AlsApp/Clnbrd/Clnbrd/Clnbrd.xcodeproj`
- **Repository:** `https://github.com/oliveoi1/Clnbrd`
- **Current Branch:** `main`
- **Git User:** Allan Alomes <olivedesignstudios@gmail.com>

---

## Visual Guide

### Where to Find Things:

```
Xcode Window Layout:
┌─────────────────────────────────────────────────┐
│ Toolbar          Source Control → (menu)        │
├──────────┬──────────────────────────────────────┤
│          │                                       │
│ Navigator│  Editor Area                          │
│ (⌘1-9)  │  (your code)                          │
│          │                                       │
│ ⌘2 = SC │  M = Modified files                   │
│          │  A = Added files                      │
│          │  D = Deleted files                    │
│          │                                       │
└──────────┴──────────────────────────────────────┘
```

### Source Control Navigator (⌘2):
```
Branches
  └─ main ✓
Remotes
  └─ origin
     └─ main
Tags
  (none yet)
```

---

## Quick Test: Verify Your Setup

### Test Checklist:
1. ✅ Open Xcode project
2. ✅ Press ⌘2 → See "Branches" with `main`
3. ✅ See "Source Control" in menu bar
4. ✅ Files show badges (M, A, D)
5. ✅ Can create new branch
6. ✅ Can commit changes
7. ✅ Can push to GitHub

**If all ✅, you're set up correctly!**

---

## Need Help?

- **Git Workflow:** See `GIT_WORKFLOW.md`
- **Xcode Documentation:** Help → Xcode Help → "Source Control"
- **GitHub Repo:** https://github.com/oliveoi1/Clnbrd

---

**You're ready to use Git in Xcode! 🚀**

