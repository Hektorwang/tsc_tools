# Quick Start: GitHub Actions CI/CD

## What You Get

✅ **Automatic builds** on every push  
✅ **Automatic releases** when you push a tag  
✅ **Simple and focused** - just runs `build.sh` and publishes

## Setup (2 minutes)

### 1. Push to GitHub

```bash
git add .github/ CI_CD_SUMMARY.md QUICK_START.md
git commit -m "ci: add GitHub Actions"
git push origin main
```

### 2. Enable Actions

Go to: **Settings** → **Actions** → **General**

- ✅ Allow all actions
- ✅ Read and write permissions
- Click **Save**

Done! 🎉

## Usage

### Every Push = Automatic Build

```bash
git add .
git commit -m "your changes"
git push
```

→ Check **Actions** tab to see the build

### Create a Release

```bash
# 1. Update version
vim release-note.md
# Add: ## Version=2.0.3.beta9

# 2. Commit
git add release-note.md
git commit -m "chore: bump to 2.0.3.beta9"
git push

# 3. Tag and push
git tag -a v2.0.3.beta9 -m "Release 2.0.3.beta9"
git push origin v2.0.3.beta9
```

→ Check **Releases** section for your published release!

## That's It!

- **CI builds**: Actions tab
- **Releases**: Releases section
- **Details**: See `CI_CD_SUMMARY.md`

## Example Release

```bash
# Complete example
vim release-note.md  # Add version
git add release-note.md
git commit -m "chore: bump to 2.0.4"
git push
git tag -a v2.0.4 -m "Release 2.0.4"
git push origin v2.0.4

# Wait 2-3 minutes, then check Releases section!
```
