# GitHub Actions Setup Instructions

Follow these steps to enable CI/CD for your TSC Tools repository.

## Prerequisites

- GitHub repository with admin access
- Git installed locally
- Basic understanding of Git and GitHub

## Step-by-Step Setup

### Step 1: Push Workflow Files to GitHub

The workflow files are already created in `.github/workflows/`. Push them to your repository:

```bash
# Add all workflow files
git add .github/

# Commit the changes
git commit -m "ci: add GitHub Actions workflows for CI/CD"

# Push to your repository
git push origin main
```

### Step 2: Enable GitHub Actions

1. Go to your repository on GitHub
2. Click on **Settings** (top menu)
3. Click on **Actions** → **General** (left sidebar)
4. Under "Actions permissions":
   - Select: **Allow all actions and reusable workflows**
5. Under "Workflow permissions":
   - Select: **Read and write permissions**
   - Check: **Allow GitHub Actions to create and approve pull requests**
6. Click **Save**

### Step 3: Verify Workflows Are Active

1. Go to the **Actions** tab in your repository
2. You should see the following workflows:
   - CI
   - Release
   - Integration Tests
   - CodeQL Security Scan

### Step 4: Configure Branch Protection (Recommended)

Protect your main branch to ensure code quality:

1. Go to **Settings** → **Branches**
2. Click **Add branch protection rule**
3. Branch name pattern: `main` (or `master`)
4. Enable these settings:
   - ✅ **Require status checks to pass before merging**
   - Select required checks:
     - `ShellCheck Linting`
     - `Test Build (ubuntu-20.04)`
     - `Test Build (ubuntu-22.04)`
     - `Bash Syntax Check`
   - ✅ **Require branches to be up to date before merging**
   - ✅ **Require linear history** (optional, but recommended)
   - ✅ **Include administrators** (optional)
5. Click **Create**

### Step 5: Test the CI Pipeline

Create a test branch and make a small change:

```bash
# Create a test branch
git checkout -b test-ci

# Make a small change (e.g., add a comment to README)
echo "# CI/CD Test" >> README.md

# Commit and push
git add README.md
git commit -m "test: verify CI pipeline"
git push origin test-ci
```

Then:
1. Go to GitHub and create a Pull Request from `test-ci` to `main`
2. Watch the CI checks run automatically
3. Verify all checks pass
4. You can merge or close the PR

### Step 6: Create Your First Release

When you're ready to create a release:

```bash
# 1. Update release-note.md with new version
vim release-note.md

# Add at the top:
# ## Version=2.0.3.beta9
# 
# 1. feat: Added CI/CD workflows
# 2. fix: Various improvements

# 2. Commit the changes
git add release-note.md
git commit -m "chore: bump version to 2.0.3.beta9"
git push origin main

# 3. Create and push a tag
git tag -a v2.0.3.beta9 -m "Release version 2.0.3.beta9"
git push origin v2.0.3.beta9
```

Then:
1. Go to **Actions** tab
2. Watch the **Release** workflow run
3. Once complete, go to **Releases** section
4. You'll see your new release with the built package

### Step 7: Add Status Badges to README (Optional)

Add CI/CD status badges to your README.md:

```markdown
# TSC Tools

[![CI](https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/ci.yml/badge.svg)](https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/ci.yml)
[![Release](https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/release.yml/badge.svg)](https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/release.yml)
[![Tests](https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/test.yml/badge.svg)](https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/test.yml)
[![Security](https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/codeql.yml/badge.svg)](https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/codeql.yml)

[Rest of your README...]
```

Replace `YOUR_USERNAME` and `YOUR_REPO` with your actual values.

## Workflow Overview

### CI Workflow
- **Runs on**: Every push and PR
- **Purpose**: Quick validation (linting, syntax, build)
- **Duration**: ~2-5 minutes

### Release Workflow
- **Runs on**: Tag push (v*.*.*)
- **Purpose**: Create GitHub releases
- **Duration**: ~3-7 minutes

### Integration Tests
- **Runs on**: Push, PR, daily schedule
- **Purpose**: Comprehensive testing
- **Duration**: ~5-10 minutes

### Security Scan
- **Runs on**: Push, PR, weekly schedule
- **Purpose**: Security analysis
- **Duration**: ~3-5 minutes

## Local Testing

Before pushing, test locally:

```bash
# Make the script executable (Linux/Mac)
chmod +x scripts/local-ci-check.sh

# Run local checks
./scripts/local-ci-check.sh
```

On Windows with Git Bash:
```bash
bash scripts/local-ci-check.sh
```

## Troubleshooting

### Workflows Not Running

**Problem**: Workflows don't appear or run after pushing

**Solution**:
1. Check that workflow files are in `.github/workflows/`
2. Verify Actions are enabled in Settings → Actions
3. Check workflow syntax with: https://rhysd.github.io/actionlint/

### Permission Errors

**Problem**: Workflow fails with permission errors

**Solution**:
1. Go to Settings → Actions → General
2. Set "Workflow permissions" to "Read and write permissions"
3. Re-run the failed workflow

### Build Failures

**Problem**: Build job fails

**Solution**:
1. Check the build logs in Actions tab
2. Test build locally: `./build.sh`
3. Ensure all dependencies are in the repository
4. Check that `makeself.sh` is executable

### ShellCheck Warnings

**Problem**: ShellCheck job reports warnings

**Solution**:
1. Review the warnings in the job logs
2. Fix the issues or suppress with `# shellcheck disable=SCXXXX`
3. Document why warnings are suppressed

### Release Not Created

**Problem**: Tag pushed but no release created

**Solution**:
1. Check tag format: must be `v*.*.*` (e.g., `v2.0.3.beta9`)
2. Verify Release workflow ran in Actions tab
3. Check workflow logs for errors
4. Ensure workflow has write permissions

## Advanced Configuration

### Customize Build Matrix

Edit `.github/workflows/ci.yml`:

```yaml
strategy:
  matrix:
    os: [ubuntu-20.04, ubuntu-22.04, ubuntu-24.04]
```

### Add Deployment Step

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy

on:
  release:
    types: [published]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Deploy
        run: |
          # Your deployment commands
```

### Add Slack/Email Notifications

Add to any workflow:

```yaml
- name: Notify on failure
  if: failure()
  run: |
    # Send notification
    curl -X POST -H 'Content-type: application/json' \
      --data '{"text":"Build failed!"}' \
      ${{ secrets.SLACK_WEBHOOK_URL }}
```

## Getting Help

- **Documentation**: See [CICD_GUIDE.md](CICD_GUIDE.md)
- **GitHub Actions Docs**: https://docs.github.com/en/actions
- **Issues**: Open an issue in your repository

## Next Steps

After setup:
1. ✅ Review and merge test PR
2. ✅ Create your first release
3. ✅ Add status badges to README
4. ✅ Configure branch protection
5. ✅ Share with your team

## Checklist

- [ ] Workflow files pushed to repository
- [ ] GitHub Actions enabled
- [ ] Workflow permissions configured
- [ ] Branch protection rules set up
- [ ] Test PR created and verified
- [ ] First release created successfully
- [ ] Status badges added to README
- [ ] Team members notified
- [ ] Documentation reviewed

Congratulations! Your CI/CD pipeline is now set up and ready to use! 🎉
