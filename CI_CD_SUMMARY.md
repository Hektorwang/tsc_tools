# GitHub Actions CI/CD Setup

This project uses GitHub Actions to automatically build and release TSC Tools.

## What It Does

### 1. CI Workflow (Continuous Integration)
- **Runs on**: Every push and pull request
- **Does**: 
  - Runs `build.sh` to build the package
  - Verifies the release file is created in `release/` directory
  - Uploads the build artifact for download

### 2. Release Workflow
- **Runs on**: When you push a version tag (e.g., `v2.0.3.beta9`)
- **Does**:
  - Runs `build.sh` to build the package
  - Calculates SHA256 checksum
  - Creates a GitHub Release
  - Uploads the built file to the release
  - Generates installation instructions

## Setup (One-Time)

1. **Push the workflow files to GitHub**:
   ```bash
   git add .github/
   git commit -m "ci: add GitHub Actions workflows"
   git push origin main
   ```

2. **Enable GitHub Actions**:
   - Go to your repository on GitHub
   - Click **Settings** → **Actions** → **General**
   - Under "Actions permissions": Select **Allow all actions**
   - Under "Workflow permissions": Select **Read and write permissions**
   - Click **Save**

That's it! Your CI/CD is ready.

## How to Use

### Building (Automatic)

Every time you push code, GitHub Actions will automatically:
1. Run `build.sh`
2. Create the release file
3. Make it available for download

```bash
# Just push your code
git add .
git commit -m "your changes"
git push

# Check the Actions tab to see the build
```

### Creating a Release

To publish a new release:

**Step 1**: Update the version in `release-note.md`
```bash
vim release-note.md
# Add at the top:
# ## Version=2.0.3.beta9
# 
# 1. feat: New feature
# 2. fix: Bug fix
```

**Step 2**: Commit and push
```bash
git add release-note.md
git commit -m "chore: bump version to 2.0.3.beta9"
git push origin main
```

**Step 3**: Create and push a tag
```bash
git tag -a v2.0.3.beta9 -m "Release version 2.0.3.beta9"
git push origin v2.0.3.beta9
```

**Step 4**: Wait for the release
- Go to the **Actions** tab
- Watch the "Release" workflow run
- When complete, go to **Releases** section
- Your release is published with the built file!

## What Gets Published

Each release includes:
- The built `.sh` file from `release/` directory
- SHA256 checksum for verification
- Installation instructions
- Link to release notes

## Viewing Results

- **CI Builds**: Actions tab → CI workflow
- **Releases**: Releases section (right sidebar on GitHub)
- **Download Artifacts**: Click on a workflow run → Artifacts section

## Tag Format

Tags must start with `v` followed by version:
- ✅ `v2.0.3.beta9`
- ✅ `v2.0.4`
- ✅ `v3.0.0-rc1`
- ❌ `2.0.3` (missing 'v')
- ❌ `release-2.0.3` (wrong format)

## Pre-releases

Tags containing `beta`, `alpha`, or `rc` are automatically marked as pre-releases:
- `v2.0.3.beta9` → Pre-release ✓
- `v2.0.3` → Stable release ✓

## Troubleshooting

### Workflow not running
- Check that Actions are enabled in Settings → Actions
- Verify workflow files are in `.github/workflows/`

### Build fails
- Check the workflow logs in Actions tab
- Test locally: `./build.sh`
- Ensure all dependencies are available

### Release not created
- Verify tag format starts with `v`
- Check workflow has write permissions
- Look at workflow logs for errors

## Example: Complete Release Process

```bash
# 1. Make your changes
vim tsc_tools/modules/my_module/run.sh

# 2. Update release notes
vim release-note.md
# Add: ## Version=2.0.3.beta9
#      1. feat: Added my_module

# 3. Commit everything
git add .
git commit -m "feat: add my_module"
git push origin main

# 4. Create release tag
git tag -a v2.0.3.beta9 -m "Release 2.0.3.beta9"
git push origin v2.0.3.beta9

# 5. Check GitHub
# - Actions tab: Watch the build
# - Releases: Download your release file
```

## Status Badge

Add this to your README.md to show build status:

```markdown
[![CI](https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/ci.yml/badge.svg)](https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/ci.yml)
[![Release](https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/release.yml/badge.svg)](https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/release.yml)
```

Replace `YOUR_USERNAME` and `YOUR_REPO` with your GitHub username and repository name.

---

**That's all you need!** The CI/CD is simple and focused on building and releasing your package.
