# CI/CD Guide for TSC Tools

This document explains the GitHub Actions CI/CD setup for the TSC Tools project.

## Overview

The project uses GitHub Actions for continuous integration and deployment with the following workflows:

1. **CI Workflow** (`ci.yml`) - Runs on every push and pull request
2. **Release Workflow** (`release.yml`) - Creates releases when tags are pushed
3. **Integration Tests** (`test.yml`) - Comprehensive testing suite
4. **Security Scan** (`codeql.yml`) - Security analysis and vulnerability detection

## Workflows

### 1. CI Workflow (`.github/workflows/ci.yml`)

**Triggers:**
- Push to `main`, `master`, or `develop` branches
- Pull requests to these branches
- Manual trigger via workflow_dispatch

**Jobs:**

#### ShellCheck Linting
- Runs ShellCheck on all shell scripts in `tsc_tools/`
- Severity level: warning
- Ignores: `lib/` directory

#### Test Build
- Builds the project on Ubuntu 20.04 and 22.04
- Verifies build output
- Uploads build artifacts (retained for 7 days)

#### Bash Syntax Check
- Validates syntax of all `.sh` files
- Fails fast on syntax errors

#### Security Scan
- Checks for hardcoded secrets
- Detects unsafe command patterns
- Reports warnings for review

### 2. Release Workflow (`.github/workflows/release.yml`)

**Triggers:**
- Push of version tags (e.g., `v2.0.3.beta8`)
- Manual trigger with version input

**Process:**
1. Builds the release package
2. Calculates SHA256 checksum
3. Generates release notes
4. Creates GitHub Release
5. Uploads release artifact
6. Marks as pre-release if version contains `beta`, `alpha`, or `rc`

**Creating a Release:**

```bash
# Method 1: Using Git tags
git tag -a v2.0.3.beta9 -m "Release version 2.0.3.beta9"
git push origin v2.0.3.beta9

# Method 2: Manual trigger from GitHub Actions UI
# Go to Actions → Release → Run workflow
# Enter version: 2.0.3.beta9
```

### 3. Integration Tests (`.github/workflows/test.yml`)

**Triggers:**
- Push to main branches
- Pull requests
- Daily at 2 AM UTC (scheduled)
- Manual trigger

**Test Suites:**

#### Installation Tests
- Tests package extraction
- Validates installation process
- Tests on multiple Ubuntu versions

#### Function Library Tests
- Tests logging functions
- Tests version comparison utilities
- Validates core functionality

#### Module Structure Tests
- Validates all modules have required files
- Checks syntax of all `run.sh` scripts
- Ensures proper module structure

#### Environment Detection Tests
- Tests `.supported_env.conf` parsing
- Validates system detection functions
- Checks JSON output format

#### Code Quality Tests
- Checks for unquoted variables
- Validates error handling
- Reports TODO/FIXME comments

### 4. Security Scan (`.github/workflows/codeql.yml`)

**Triggers:**
- Push to main branches
- Pull requests
- Weekly on Mondays at 6 AM UTC
- Manual trigger

**Security Checks:**
- CodeQL analysis (for future JS/Python code)
- ShellCheck security analysis
- Dangerous `eval` usage detection
- Command injection risk detection
- World-writable permission checks
- Unsafe temp file creation detection

## Setup Instructions

### 1. Enable GitHub Actions

1. Go to your repository on GitHub
2. Navigate to **Settings** → **Actions** → **General**
3. Under "Actions permissions", select:
   - ✅ Allow all actions and reusable workflows
4. Under "Workflow permissions", select:
   - ✅ Read and write permissions
   - ✅ Allow GitHub Actions to create and approve pull requests

### 2. Configure Branch Protection (Recommended)

1. Go to **Settings** → **Branches**
2. Add branch protection rule for `main` or `master`:
   - ✅ Require status checks to pass before merging
   - Select required checks:
     - ShellCheck Linting
     - Test Build
     - Bash Syntax Check
   - ✅ Require branches to be up to date before merging
   - ✅ Require linear history (optional)

### 3. Set Up Secrets (if needed)

For future enhancements, you may need to add secrets:

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Add secrets as needed (e.g., deployment credentials)

## Usage Examples

### Running CI on Pull Requests

When you create a pull request:
1. All CI checks run automatically
2. Review the results in the PR checks section
3. Fix any issues before merging
4. Merge only when all checks pass

### Creating a Release

**Step 1: Update version in release-note.md**
```bash
# Edit release-note.md
vim release-note.md

# Add new version section at the top:
## Version=2.0.3.beta9

1. feat: New feature description
2. fix: Bug fix description
```

**Step 2: Commit and push**
```bash
git add release-note.md
git commit -m "chore: bump version to 2.0.3.beta9"
git push origin main
```

**Step 3: Create and push tag**
```bash
git tag -a v2.0.3.beta9 -m "Release version 2.0.3.beta9"
git push origin v2.0.3.beta9
```

**Step 4: Monitor release workflow**
1. Go to **Actions** tab
2. Watch the "Release" workflow
3. Once complete, check **Releases** section
4. Download and test the release package

### Manual Testing

Run workflows manually:
1. Go to **Actions** tab
2. Select a workflow (e.g., "Integration Tests")
3. Click **Run workflow**
4. Select branch and click **Run workflow**

## Monitoring and Troubleshooting

### Viewing Workflow Runs

1. Go to **Actions** tab
2. Click on a workflow run to see details
3. Click on individual jobs to see logs
4. Download artifacts if needed

### Common Issues

#### Build Fails
- Check `build.sh` syntax
- Verify all dependencies are installed
- Review build logs for specific errors

#### ShellCheck Warnings
- Review ShellCheck output
- Fix or suppress warnings with `# shellcheck disable=SCXXXX`
- Document why warnings are suppressed

#### Security Scan Failures
- Review security warnings carefully
- Fix critical issues (eval, chmod 777, etc.)
- Update code to use safer alternatives

### Debugging Failed Workflows

1. **Check the logs:**
   - Click on the failed job
   - Expand failed steps
   - Read error messages

2. **Reproduce locally:**
   ```bash
   # Run ShellCheck
   shellcheck tsc_tools/**/*.sh
   
   # Test build
   ./build.sh
   
   # Run syntax check
   find . -name "*.sh" -exec bash -n {} \;
   ```

3. **Fix and re-run:**
   - Make fixes
   - Commit and push
   - Workflow runs automatically

## Best Practices

### For Contributors

1. **Before committing:**
   ```bash
   # Check syntax
   bash -n your_script.sh
   
   # Run ShellCheck
   shellcheck your_script.sh
   
   # Test locally
   ./build.sh
   ```

2. **Write good commit messages:**
   ```
   type(scope): subject
   
   - feat: new feature
   - fix: bug fix
   - docs: documentation
   - test: testing
   - chore: maintenance
   ```

3. **Keep PRs focused:**
   - One feature/fix per PR
   - Include tests
   - Update documentation

### For Maintainers

1. **Review CI results before merging**
2. **Ensure all tests pass**
3. **Check security scan results**
4. **Verify build artifacts**
5. **Test releases before announcing**

## Customization

### Adding New Tests

Edit `.github/workflows/test.yml`:

```yaml
- name: My New Test
  run: |
    echo "Running my test..."
    # Add test commands here
```

### Changing Build Matrix

Edit `.github/workflows/ci.yml`:

```yaml
strategy:
  matrix:
    os: [ubuntu-20.04, ubuntu-22.04, ubuntu-24.04]  # Add more versions
```

### Adding Deployment

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
      - name: Deploy to server
        run: |
          # Add deployment commands
```

## Status Badges

Add these badges to your README.md:

```markdown
[![CI](https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/ci.yml/badge.svg)](https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/ci.yml)
[![Release](https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/release.yml/badge.svg)](https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/release.yml)
[![Security](https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/codeql.yml/badge.svg)](https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/codeql.yml)
```

Replace `YOUR_USERNAME` and `YOUR_REPO` with your actual GitHub username and repository name.

## Support

For issues with CI/CD:
1. Check workflow logs
2. Review this guide
3. Open an issue with:
   - Workflow name
   - Run ID
   - Error messages
   - Steps to reproduce

## Future Enhancements

Planned improvements:
- [ ] Add Docker container builds
- [ ] Implement automated testing on real hardware
- [ ] Add performance benchmarking
- [ ] Integrate with external monitoring
- [ ] Add automatic changelog generation
- [ ] Implement semantic versioning automation
