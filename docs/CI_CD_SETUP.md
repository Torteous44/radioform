# CI/CD Setup Guide

This guide explains how to set up GitHub Actions for automated releases.

## Overview

When you push a tag like `v1.0.0`, GitHub Actions will automatically:
1. Build all components (DSP, Driver, Host, App)
2. Code sign with your Developer ID certificate
3. Notarize with Apple
4. Create a signed DMG
5. Publish a GitHub Release

## Required GitHub Secrets

Go to your repository: **Settings → Secrets and variables → Actions → New repository secret**

Add these 6 secrets:

| Secret Name | Description | How to Get It |
|-------------|-------------|---------------|
| `APPLE_CERTIFICATE` | Base64-encoded .p12 certificate | See Step 1 below |
| `APPLE_CERTIFICATE_PASSWORD` | Password for the .p12 file | The password you set when exporting |
| `KEYCHAIN_PASSWORD` | Any random password for CI keychain | Generate: `openssl rand -base64 32` |
| `APPLE_ID` | Your Apple ID email | `maxdecastro777@gmail.com` |
| `APPLE_ID_PASSWORD` | App-specific password | See Step 2 below |
| `APPLE_TEAM_ID` | 10-character Team ID | `F3KSR2SF6L` |

---

## Step 1: Export Certificate as Base64

**On your Mac (where the certificate is installed):**

### 1.1 Export from Keychain Access

1. Open **Keychain Access**
2. Select **login** keychain → **My Certificates**
3. Find **"Developer ID Application: Max de Castro (F3KSR2SF6L)"**
4. Right-click → **Export "Developer ID Application..."**
5. Save as `Radioform.p12`
6. Set a strong password (you'll need this for `APPLE_CERTIFICATE_PASSWORD`)

### 1.2 Convert to Base64

```bash
# Convert .p12 to base64 and copy to clipboard
base64 -i Radioform.p12 | pbcopy

# Or save to a file to inspect
base64 -i Radioform.p12 > certificate_base64.txt
```

### 1.3 Add to GitHub Secrets

1. Go to your repo → **Settings → Secrets and variables → Actions**
2. Click **New repository secret**
3. Name: `APPLE_CERTIFICATE`
4. Value: Paste the base64 string (Cmd+V)
5. Click **Add secret**

Also add `APPLE_CERTIFICATE_PASSWORD` with the password you used when exporting.

### 1.4 Clean up!

```bash
# Delete the .p12 file for security
rm Radioform.p12
rm certificate_base64.txt  # if you created this
```

---

## Step 2: Create App-Specific Password

**⚠️ This is NOT your Apple ID password!**

1. Go to https://appleid.apple.com/
2. Sign in with your Apple ID
3. Navigate to **Sign-In and Security → App-Specific Passwords**
4. Click **Generate an app-specific password**
5. Label it: `Radioform GitHub Actions`
6. Copy the generated password (format: `xxxx-xxxx-xxxx-xxxx`)
7. Add to GitHub Secrets as `APPLE_ID_PASSWORD`

---

## Step 3: Generate Keychain Password

This is just a random password for the temporary CI keychain:

```bash
# Generate and copy to clipboard
openssl rand -base64 32 | pbcopy
```

Add to GitHub Secrets as `KEYCHAIN_PASSWORD`.

---

## Step 4: Add Remaining Secrets

| Secret | Value |
|--------|-------|
| `APPLE_ID` | `maxdecastro777@gmail.com` |
| `APPLE_TEAM_ID` | `F3KSR2SF6L` |

---

## Triggering a Release

### Option 1: Push a Git Tag

```bash
# Tag the current commit
git tag v1.0.0

# Push the tag to trigger release
git push origin v1.0.0
```

### Option 2: Manual Dispatch

1. Go to **Actions → Release** workflow
2. Click **Run workflow**
3. Enter version (e.g., `1.0.0`)
4. Click **Run workflow**

---

## Verification Checklist

Before your first release, verify:

- [ ] All 6 secrets are added to GitHub
- [ ] Certificate exported with private key included
- [ ] App-specific password created (not regular password)
- [ ] Test with a pre-release tag first: `git tag v0.0.1-test && git push origin v0.0.1-test`

---

## Team Members

**Each team member does NOT need their own certificate.** The certificate is stored in GitHub Secrets and used by CI/CD.

Team members can:
- Push code normally
- Create tags to trigger releases
- Download signed builds from GitHub Releases

Only one person needs to set up the secrets (typically the certificate owner).

---

## Local Development

For local development and testing, team members don't need code signing:

```bash
# Build and run locally (no signing needed)
make dev

# Or just build
make build
```

Only use `make sign` if you have the certificate installed locally.

---

## Troubleshooting

### "No identity found" in CI

- Verify `APPLE_CERTIFICATE` is correctly base64 encoded
- Check `APPLE_CERTIFICATE_PASSWORD` matches export password
- Ensure private key was exported with certificate (expand cert in Keychain, should show key)

### "Unable to authenticate" notarization error

- Verify `APPLE_ID_PASSWORD` is an app-specific password, not your regular password
- Check `APPLE_TEAM_ID` is correct (10 characters)
- Ensure `APPLE_ID` email is correct

### "Invalid signature" 

- Certificate may have expired - create new one in Apple Developer Portal
- Re-export and update `APPLE_CERTIFICATE` secret

### View CI Logs

1. Go to **Actions** tab in GitHub
2. Click on the failed workflow run
3. Expand the failed step to see detailed logs

---

## Security Best Practices

1. **Never commit secrets** - Use GitHub Secrets only
2. **Rotate app-specific passwords** periodically
3. **Limit secret access** - Use environment protection rules if needed
4. **Delete local .p12 files** after encoding to base64
5. **Use branch protection** - Require PR reviews before merging to main

---

## Quick Reference

```bash
# Release a new version
git tag v1.2.3 && git push origin v1.2.3

# Release a beta
git tag v1.2.3-beta.1 && git push origin v1.2.3-beta.1

# Delete a tag (if needed)
git tag -d v1.2.3
git push origin :refs/tags/v1.2.3
```

