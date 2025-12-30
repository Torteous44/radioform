# Code Signing Setup Guide

## Prerequisites
- Active Apple Developer Program membership ($99/year)
- Access to https://developer.apple.com/account

## Step 1: Create Developer ID Certificate

1. **Go to Apple Developer Portal**
   - Visit: https://developer.apple.com/account/resources/certificates/list
   - Sign in with your Apple ID

2. **Create a new certificate**
   - Click the **"+"** button (top right)
   - Under "Services", select **"Developer ID Application"**
   - Click **Continue**

3. **Create a Certificate Signing Request (CSR)**
   - Open **Keychain Access** app (Applications > Utilities)
   - Go to menu: **Keychain Access > Certificate Assistant > Request a Certificate From a Certificate Authority**
   - Enter your email address
   - Enter a name (e.g., "Radioform Developer ID")
   - Select **"Saved to disk"**
   - Click **Continue**
   - Save the `.certSigningRequest` file

4. **Upload CSR**
   - Back in Apple Developer Portal, upload the `.certSigningRequest` file you just created
   - Click **Continue**
   - Click **Download** to get your certificate (`.cer` file)

## Step 2: Install Certificate in Keychain

1. **Install the certificate**
   - Double-click the downloaded `.cer` file
   - It will open in Keychain Access
   - Make sure it's installed in **"login"** keychain (not "System")

2. **Verify installation**
   - Open Keychain Access
   - Select **"login"** keychain (left sidebar)
   - Select **"My Certificates"** category
   - You should see: **"Developer ID Application: Your Name (TEAM_ID)"**
   - Expand it - you should see both the certificate AND a private key underneath

3. **Verify with command line**
   ```bash
   security find-identity -v -p codesigning | grep "Developer ID"
   ```
   - You should see your Developer ID certificate listed

## Step 3: Code Sign Your App

Once the certificate is installed, you can sign your app:

```bash
# Build and create app bundle
make bundle

# Sign the app
make sign

# Verify signatures
make verify
```

## Troubleshooting

### "No Developer ID certificate found"
- Make sure certificate is in "login" keychain, not "System"
- Make sure private key is present (expand certificate in Keychain Access)
- Try: `security find-identity -v -p codesigning`

### "Private key not found"
- If you created the CSR on a different Mac, you need to export/import the private key
- Export from original Mac: Right-click certificate > Export > Save as .p12
- Import on this Mac: Double-click .p12 file and enter password

### "Certificate expired"
- Go to Apple Developer Portal and create a new certificate
- Download and install the new one

## Alternative: Use Environment Variable

If you want to specify the certificate explicitly:

```bash
# Find your certificate identity
security find-identity -v -p codesigning | grep "Developer ID"

# Set it as environment variable (use the full string from above)
export APPLE_DEVELOPER_ID="Developer ID Application: Your Name (TEAM_ID)"

# Now sign
make sign
```

## Next Steps After Signing

1. **Test the signed app**
   ```bash
   make test-release
   ```

2. **Notarize** (required for distribution outside App Store)
   ```bash
   ./tools/notarize.sh
   ```

3. **Create DMG** (for distribution)
   ```bash
   ./tools/create_dmg.sh
   ```

