# tools/ci/

Continuous integration and release automation.

## Purpose

Automated workflows for testing, building, and releasing Radioform.

## Workflows to Implement

### test.yml
Run on every PR and commit:
- Build DSP library and run unit tests (`packages/dsp/tests`)
- Build bridge and run ABI smoke tests
- Lint Swift code (SwiftLint)
- Lint C++ code (clang-tidy)
- Check formatting (SwiftFormat, clang-format)

### build.yml
Build all targets:
- Build driver, audio host, and menu bar app
- Build for Intel and Apple Silicon
- Archive build artifacts
- Run on PR and main branch

### release.yml
Triggered on Git tags (e.g., `v1.0.0`):
- Build release configuration
- Code sign and notarize
- Create DMG/PKG installer
- Generate checksums (SHA-256)
- Upload to GitHub Releases
- Update website download links

### deploy-site.yml
Deploy marketing website:
- Build Next.js site (`apps/web/site`)
- Deploy to Vercel or Cloudflare Pages
- Run on changes to `apps/web/` or `docs/`

## Platform

GitHub Actions is recommended for open-source projects.

## Secrets Management

Required secrets:
- `APPLE_CERTIFICATE`: Developer ID Application certificate
- `APPLE_CERTIFICATE_PASSWORD`: Certificate password
- `APPLE_ID`: Apple ID for notarization
- `APPLE_TEAM_ID`: Developer team ID
- `NOTARIZATION_PASSWORD`: App-specific password
