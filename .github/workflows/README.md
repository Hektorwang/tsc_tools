# GitHub Actions Workflows

This directory contains the CI/CD workflows for TSC Tools.

## Quick Reference

| Workflow | File | Trigger | Purpose |
|----------|------|---------|---------|
| CI | `ci.yml` | Push, PR | Linting, building, basic tests |
| Release | `release.yml` | Tags, Manual | Create GitHub releases |
| Integration Tests | `test.yml` | Push, PR, Schedule | Comprehensive testing |
| Security Scan | `codeql.yml` | Push, PR, Schedule | Security analysis |

## Workflow Status

Check the [Actions tab](../../actions) to see the status of all workflows.

## Documentation

See [CICD_GUIDE.md](../CICD_GUIDE.md) for detailed documentation on:
- How to use each workflow
- Setup instructions
- Troubleshooting guide
- Best practices

## Quick Start

### For Contributors

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Push and create a PR
5. CI will run automatically

### For Maintainers

1. Review PR and CI results
2. Merge when all checks pass
3. Create release tag to trigger release workflow

```bash
git tag -a v2.0.3.beta9 -m "Release 2.0.3.beta9"
git push origin v2.0.3.beta9
```

## Need Help?

- Read the [CICD_GUIDE.md](../CICD_GUIDE.md)
- Check workflow logs in the Actions tab
- Open an issue if you encounter problems
