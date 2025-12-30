# Apple Developer Setup for Radioform

This document explains how to set up code signing, notarization, and distribution for Radioform.

## Prerequisites

1. **Apple Developer Account**
   - Individual or Organization account ($99/year)
   - Enroll at: https://developer.apple.com/programs/

2. **Developer ID Certificate**
   - "Developer ID Application" certificate for distribution outside Mac App Store
   - Created through Apple Developer Portal

## Required Environment Variables

### For Code Signing

You need to configure **ONE** of the following options:

#### Option 1: Use Installed Certificate (Local Development)

If you have your Developer ID certificate installed in Keychain Access:

```bash
# No environment variables needed!
# The script will automatically find your certificate
make sign
```

#### Option 2: Specify Developer ID (Local/CI)

```bash
export APPLE_DEVELOPER_ID="Developer ID Application: Your Name (TEAM_ID)"
make sign
```

**How to find your Developer ID:**
```bash
security find-identity -v -p codesigning | grep "Developer ID Application"
```

Example output:
```
1) ABC123DEF456 "Developer ID Application: John Doe (ABCD123456)"
```

Use the full string in quotes.

#### Option 3: Base64-Encoded Certificate (CI/CD)

For GitHub Actions and automated builds:

```bash
export APPLE_CERTIFICATE="<base64-encoded .p12 file>"
export APPLE_CERTIFICATE_PASSWORD="<certificate password>"
```

**How to create base64-encoded certificate:**

1. Export certificate from Keychain Access:
   - Open Keychain Access
   - Find "Developer ID Application: ..." certificate
   - Right-click → Export → Save as .p12 with password

2. Encode to base64:
   ```bash
   base64 -i certificate.p12 | pbcopy
   ```

3. Add to GitHub Secrets:
   - Go to Repository Settings → Secrets and variables → Actions
   - Add `APPLE_CERTIFICATE` with the base64 string
   - Add `APPLE_CERTIFICATE_PASSWORD` with your password

### For Notarization (Phase 2)

Required for distribution to users:

```bash
export APPLE_ID="your.email@example.com"          # Your Apple ID
export APPLE_ID_PASSWORD="xxxx-xxxx-xxxx-xxxx"   # App-specific password
export APPLE_TEAM_ID="ABCD123456"                # 10-character team ID
```

**How to get each value:**

#### APPLE_ID
Your Apple ID email address (same one you use to log into developer.apple.com)

#### APPLE_ID_PASSWORD (App-Specific Password)

1. Go to https://appleid.apple.com/
2. Sign in with your Apple ID
3. Go to "Security" → "App-Specific Passwords"
4. Click "Generate an app-specific password"
5. Label it "Radioform Notarization"
6. Save the generated password (format: xxxx-xxxx-xxxx-xxxx)

**⚠️ IMPORTANT:** This is NOT your Apple ID password. It's a special password for API access.

#### APPLE_TEAM_ID

Find your Team ID:

1. Go to https://developer.apple.com/account/
2. Click "Membership" in sidebar
3. Your Team ID is listed (10 characters, like "ABCD123456")

Or from terminal:
```bash
xcrun altool --list-providers -u "your.email@example.com" -p "xxxx-xxxx-xxxx-xxxx"
```

## Step-by-Step Setup Guide

### 1. Create Developer ID Certificate

1. Go to https://developer.apple.com/account/resources/certificates/list
2. Click "+" to create a new certificate
3. Select "Developer ID Application"
4. Follow instructions to create CSR (Certificate Signing Request)
5. Upload CSR and download certificate
6. Double-click certificate to install in Keychain Access

**Verify installation:**
```bash
security find-identity -v -p codesigning
```

You should see: "Developer ID Application: Your Name (TEAM_ID)"

### 2. Test Code Signing Locally

```bash
# Build the app
make bundle

# Sign it (will automatically find your certificate)
make sign

# Verify signatures
make verify
```

If successful, you should see:
```
✓ All signatures valid!
```

### 3. Configure for CI/CD (GitHub Actions)

1. Export your certificate:
   ```bash
   # Find your certificate in Keychain Access
   # Right-click → Export "Developer ID Application..."
   # Save as certificate.p12 with a strong password
   ```

2. Encode to base64:
   ```bash
   base64 -i certificate.p12 | pbcopy
   ```

3. Add GitHub Secrets:
   - Repository → Settings → Secrets and variables → Actions
   - Click "New repository secret"
   - Add each secret:

   | Secret Name | Value |
   |-------------|-------|
   | `APPLE_CERTIFICATE` | Base64-encoded .p12 (from clipboard) |
   | `APPLE_CERTIFICATE_PASSWORD` | Password you used when exporting |
   | `APPLE_TEAM_ID` | Your 10-character team ID |
   | `APPLE_ID` | Your Apple ID email |
   | `APPLE_ID_PASSWORD` | App-specific password |

4. Secrets are now available in GitHub Actions as:
   ```yaml
   env:
     APPLE_CERTIFICATE: ${{ secrets.APPLE_CERTIFICATE }}
     APPLE_CERTIFICATE_PASSWORD: ${{ secrets.APPLE_CERTIFICATE_PASSWORD }}
   ```

### 4. Local Development Workflow

For daily development (no signing needed):
```bash
make dev          # Build and run with onboarding
make run          # Run without resetting
```

When preparing a release:
```bash
make release      # Build + sign + verify
make test-release # Test the signed build
```

### 5. CI/CD Release Workflow

Once GitHub secrets are configured:
```bash
git tag v1.0.0
git push origin v1.0.0
```

GitHub Actions will automatically:
1. Build all components
2. Sign with your Developer ID
3. Notarize with Apple
4. Create DMG
5. Publish GitHub Release

## Environment Variables Quick Reference

### Local Development (Option 1 - Recommended)
```bash
# No env vars needed - certificate from Keychain
make sign
```

### Local Development (Option 2 - Explicit)
```bash
export APPLE_DEVELOPER_ID="Developer ID Application: Your Name (TEAM_ID)"
make sign
```

### CI/CD (GitHub Actions)
```bash
# GitHub Secrets → Environment Variables
APPLE_CERTIFICATE               # Base64-encoded .p12
APPLE_CERTIFICATE_PASSWORD      # Certificate password
APPLE_TEAM_ID                   # 10-char team ID
APPLE_ID                        # Apple ID email
APPLE_ID_PASSWORD               # App-specific password
```

### Full Release (Local)
```bash
# Code Signing
export APPLE_DEVELOPER_ID="Developer ID Application: Your Name (TEAM_ID)"

# Notarization (Phase 2)
export APPLE_ID="your.email@example.com"
export APPLE_ID_PASSWORD="xxxx-xxxx-xxxx-xxxx"
export APPLE_TEAM_ID="ABCD123456"

# Build and sign
make release
```

## Security Best Practices

1. **Never commit secrets to git**
   - Use `.env` file (already in `.gitignore`)
   - Use environment variables
   - Use GitHub Secrets for CI/CD

2. **Protect your .p12 file**
   - Use strong password
   - Delete after encoding to base64
   - Store backup in secure location (password manager)

3. **Rotate app-specific passwords**
   - Create separate password for each service
   - Revoke and regenerate if compromised
   - Label clearly (e.g., "Radioform Notarization")

4. **Use Keychain for local development**
   - More secure than environment variables
   - Automatic certificate selection
   - Protected by macOS security

## Troubleshooting

### "No identity found" error
- Install Developer ID certificate in Keychain
- Or set `APPLE_DEVELOPER_ID` environment variable
- Verify: `security find-identity -v -p codesigning`

### "User interaction is not allowed" in CI
- Certificate not imported correctly
- Check `security unlock-keychain` in script
- Verify base64 encoding is correct

### "Invalid signature" error
- Entitlements file missing or incorrect
- Run: `make verify` to see details
- Check: `codesign -dv --entitlements - dist/Radioform.app`

### Gatekeeper rejection
- App not notarized yet (expected before Phase 2)
- Or signature verification failed
- Run: `spctl --assess -vv dist/Radioform.app`

## Next Steps

After code signing is working:

1. **Phase 2: Notarization**
   - Submit signed app to Apple for notarization
   - Receive notarization ticket
   - Staple ticket to app

2. **Phase 3: DMG Packaging**
   - Create installer DMG
   - Sign DMG
   - Distribute to users

3. **Phase 4: CI/CD Automation**
   - Automate entire release process
   - Tag-triggered builds
   - Automatic GitHub Releases

## Resources

- [Apple Code Signing Guide](https://developer.apple.com/support/code-signing/)
- [Notarizing macOS Software](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [App-Specific Passwords](https://support.apple.com/en-us/HT204397)
- [Hardened Runtime](https://developer.apple.com/documentation/security/hardened_runtime)

---

**Questions?** Check the [GitHub Issues](https://github.com/Torteous44/radioform/issues) or reach out to the team.
