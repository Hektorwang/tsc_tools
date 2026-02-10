# CI/CD for TSC Tools

Simple GitHub Actions setup that builds and releases your package automatically.

## 📋 What It Does

1. **CI (Continuous Integration)**: Runs `build.sh` on every push/PR
2. **Release**: Publishes to GitHub Releases when you push a tag

## 🚀 Quick Setup

```bash
# 1. Push workflows to GitHub
git add .github/
git commit -m "ci: add GitHub Actions"
git push

# 2. Enable in GitHub Settings
# Settings → Actions → General
# - Allow all actions ✓
# - Read and write permissions ✓
```

## 📦 Create a Release

```bash
# Update version
vim release-note.md  # Add: ## Version=2.0.3.beta9

# Commit
git add release-note.md
git commit -m "chore: bump to 2.0.3.beta9"
git push

# Tag and release
git tag -a v2.0.3.beta9 -m "Release 2.0.3.beta9"
git push origin v2.0.3.beta9
```

**Result**: GitHub automatically:
- Runs `build.sh`
- Creates a release
- Uploads the `.sh` file
- Adds SHA256 checksum
- Generates install instructions

## 📁 Files Created

```
.github/
├── workflows/
│   ├── ci.yml              # Build on push/PR
│   ├── release.yml         # Publish releases
│   ├── README.md           # Workflow docs
│   └── WORKFLOW_DIAGRAM.md # Visual guide
├── CI_CD_SUMMARY.md        # Detailed guide
├── QUICK_START.md          # Quick reference
└── README_CICD.md          # This file
```

## 🔍 Monitoring

- **Builds**: Actions tab → CI workflow
- **Releases**: Releases section (right sidebar)
- **Artifacts**: Workflow run → Artifacts (7 days)

## 📊 Status Badges

Add to your README.md:

```markdown
[![CI](https://github.com/USERNAME/REPO/actions/workflows/ci.yml/badge.svg)](https://github.com/USERNAME/REPO/actions/workflows/ci.yml)
[![Release](https://github.com/USERNAME/REPO/actions/workflows/release.yml/badge.svg)](https://github.com/USERNAME/REPO/actions/workflows/release.yml)
```

## 🎯 Key Points

- ✅ Simple: Just runs `build.sh`
- ✅ Automatic: Triggered by git push
- ✅ Reliable: Uses official GitHub Actions
- ✅ Fast: ~2-3 minutes per build
- ✅ Secure: SHA256 checksums included

## 📖 Documentation

- **Quick Start**: `QUICK_START.md`
- **Full Guide**: `CI_CD_SUMMARY.md`
- **Workflow Details**: `.github/workflows/README.md`
- **Visual Diagram**: `.github/WORKFLOW_DIAGRAM.md`

## 🐛 Troubleshooting

| Problem | Solution |
|---------|----------|
| Workflow not running | Enable Actions in Settings |
| Build fails | Check `build.sh` works locally |
| No release created | Verify tag starts with `v` |
| Permission error | Enable write permissions |

## 💡 Tips

- Tag format: `v{version}` (e.g., `v2.0.3.beta9`)
- Pre-releases: Tags with `beta`, `alpha`, `rc`
- Stable releases: Tags without pre-release keywords
- Build artifacts: Available for 7 days in Actions

## 🎉 That's It!

Your CI/CD is ready. Just push code and tags!
