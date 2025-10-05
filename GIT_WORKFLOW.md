# 🚀 Git Workflow for Clnbrd Development

## Daily Workflow

### Start New Experiment/Feature
```bash
cd /Users/allanalomes/Documents/AlsApp/Clnbrd

# Create and switch to new branch
git checkout -b experiment/feature-name

# Make your changes in Xcode...
# Test, build, refine...

# Save your changes
git add .
git commit -m "Description of what you did"
```

### If You Like Your Changes
```bash
# Switch back to main
git checkout main

# Merge your experiment
git merge experiment/feature-name

# Push to GitHub
git push

# Optional: Delete the experiment branch
git branch -d experiment/feature-name
```

### If You DON'T Like Your Changes
```bash
# Switch back to main (abandons changes)
git checkout main

# Delete the experiment branch
git branch -D experiment/snake-game

# Your main code is unchanged!
```

---

## Common Commands

### Check Status
```bash
git status              # See what's changed
git log --oneline       # See commit history
git branch              # List all branches
```

### Save Changes
```bash
git add .                           # Stage all changes
git commit -m "Your message"        # Save snapshot
git push                            # Upload to GitHub
```

### Switch Branches
```bash
git checkout main                   # Go to main branch
git checkout experiment/feature     # Go to experiment branch
git checkout -b new-branch          # Create and switch to new branch
```

### Undo Changes
```bash
git checkout -- filename.swift      # Discard changes to a file
git reset --hard HEAD               # Discard ALL changes (careful!)
git revert HEAD                     # Undo last commit (safe)
```

### View Changes
```bash
git diff                    # See what changed (not committed)
git diff main experiment    # Compare two branches
```

---

## Branch Naming Conventions

Use descriptive names:
- `experiment/snake-game` - Testing new features
- `feature/analytics` - New features for main app
- `fix/crash-on-paste` - Bug fixes
- `refactor/clipboard-manager` - Code improvements

---

## Before Pushing to GitHub

Always:
1. **Build in Xcode** - Make sure it compiles
2. **Test the app** - Make sure it works
3. **Check what changed:** `git status`
4. **Review changes:** `git diff`
5. **Then commit and push**

---

## GitHub Repository

- **URL:** https://github.com/oliveoi1/Clnbrd
- **Status:** Private
- **Branch:** main

---

## Tips

1. **Commit often** - Small commits are better than big ones
2. **Write clear messages** - "Added snake game" not "changes"
3. **Test before merging** - Don't merge broken code to main
4. **Push regularly** - Backs up to GitHub
5. **Branches are cheap** - Create one for every experiment!

---

## Emergency: "I Messed Up!"

### Went to wrong branch?
```bash
git checkout main
```

### Made changes you don't want?
```bash
git checkout -- .
```

### Committed something bad?
```bash
git reset --soft HEAD~1    # Undo last commit, keep changes
git reset --hard HEAD~1    # Undo last commit, delete changes
```

### Need help?
```bash
git status    # Shows what to do next
git help      # Built-in help
```

---

## Integration with Xcode

Xcode shows Git status automatically:
- **M** = Modified (yellow)
- **A** = Added (green)
- **D** = Deleted (red)
- **?** = Untracked (gray)

**View in Xcode:**
- Source Control → History (⌘2)
- Right-click files → Show in Source Control

---

## Your Setup

- **Git User:** Allan Alomes
- **Email:** olivedesignstudios@gmail.com
- **GitHub:** oliveoi1
- **Repository:** https://github.com/oliveoi1/Clnbrd.git
- **Current Commit:** 6ff1180 "Initial commit: Clnbrd v1.3 with all features"

---

**Happy Coding! 🚀**

