# GitHub Actions Workflows

This directory contains CI/CD workflows for TSC Tools.

## Workflows

### 1. CI (`ci.yml`)
- **Triggers**: Push to main/master/develop, Pull Requests
- **Purpose**: Build and verify the package
- **Steps**:
  1. Checkout code
  2. Install dependencies (dos2unix, gzip, tar)
  3. Run `build.sh`
  4. Verify release file is created
  5. Upload build artifact

### 2. Release (`release.yml`)
- **Triggers**: Push version tags (e.g., `v2.0.3.beta9`)
- **Purpose**: Build and publish to GitHub Releases
- **Steps**:
  1. Checkout code
  2. Install dependencies
  3. Run `build.sh`
  4. Calculate SHA256 checksum
  5. Generate release notes
  6. Create GitHub Release with the built file

## Usage

### Testing Builds (CI)

Every push and PR automatically builds the package:

```bash
git add .
git commit -m "your changes"
git push
```

Check the **Actions** tab to see the build status.

### Creating Releases

To create a new release:

```bash
# 1. Update release-note.md with new version
vim release-note.md

# 2. Commit and push
git add release-note.md
git commit -m "chore: bump version to 2.0.3.beta9"
git push

# 3. Create and push tag
git tag -a v2.0.3.beta9 -m "Release 2.0.3.beta9"
git push origin v2.0.3.beta9
```

The release workflow will:
- Build the package using `build.sh`
- Create a GitHub Release
- Upload the built file
- Generate installation instructions

## Setup

1. **Enable GitHub Actions**:
   - Go to Settings → Actions → General
   - Allow all actions
   - Enable read/write permissions

2. **That's it!** The workflows are ready to use.

## Viewing Results

- **CI Builds**: Go to Actions tab → CI workflow
- **Releases**: Go to Releases section (right sidebar)
- **Artifacts**: Available in workflow run details (7 days retention)
