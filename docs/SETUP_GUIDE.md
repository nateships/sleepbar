# SleepBar Initial Setup Guide

Complete one-time setup for your indie Mac app infrastructure.

---

## ✅ Already Completed

- ✅ Private repo created: `zcpnate/sleepbar-private`
- ✅ Public repo created: `zcpnate/sleepbar`
- ✅ CNAME configured for `sleepbar.app`
- ✅ Git authentication configured

---

## 🚀 Remaining Setup Steps

### 1. Enable GitHub Pages (5 minutes)

1. Go to https://github.com/zcpnate/sleepbar/settings/pages
2. Under "Build and deployment":
   - **Source**: Deploy from a branch
   - **Branch**: main
   - **Folder**: / (root)
3. Under "Custom domain":
   - Enter: `sleepbar.app`
   - Click **Save**
4. ✅ Check **Enforce HTTPS**

---

### 2. Configure Custom Domain

#### Buy Domain
Buy `sleepbar.app` from Namecheap, Google Domains, or Cloudflare (~$10-12/year)

#### Configure DNS
Add these records at your registrar:

```
Type: A, Name: @, Value: 185.199.108.153
Type: A, Name: @, Value: 185.199.109.153
Type: A, Name: @, Value: 185.199.110.153
Type: A, Name: @, Value: 185.199.111.153
Type: CNAME, Name: www, Value: zcpnate.github.io
```

⏰ DNS propagation takes 24-48 hours

---

### 3. Add Sparkle Framework (10 minutes)

In Xcode:
1. **File → Add Packages...**
2. URL: `https://github.com/sparkle-project/Sparkle`
3. Version: `2.0.0` - `3.0.0`
4. Add to SleepBar target

---

### 4. Generate Sparkle Signing Keys (5 minutes)

```bash
cd ~/Library/Developer/Xcode/DerivedData/SleepBar-*/SourcePackages/artifacts/sparkle/Sparkle/bin/
./generate_keys
```

This will:
- Save a private key in your Keychain
- Print a public key (e.g., `pfIShU4dEXqPd5ObYNfDBiQWcXozk7estwzTnF9BamQ=`)

⚠️ **Keep your private key safe!** Back it up securely.

---

### 5. Configure Info.plist

#### Method A: Xcode Info Tab (Recommended)

1. Open `SleepBar.xcodeproj`
2. Select **SleepBar** target → **Info** tab
3. Add these keys (right-click → Add Row):

| Key | Type | Value |
|-----|------|-------|
| `SUFeedURL` | String | `https://sleepbar.app/appcast.xml` |
| `SUPublicEDKey` | String | Your public key from Step 4 |
| `CFBundleShortVersionString` | String | `1.0.0` |
| `CFBundleVersion` | String | `1` |

4. Save (Cmd+S)

#### Method B: Edit Info.plist Directly

```xml
<key>SUFeedURL</key>
<string>https://sleepbar.app/appcast.xml</string>

<key>SUPublicEDKey</key>
<string>YOUR_PUBLIC_KEY_FROM_STEP_4</string>

<key>CFBundleShortVersionString</key>
<string>1.0.0</string>

<key>CFBundleVersion</key>
<string>1</string>
```

---

### 6. Setup Lemon Squeezy (15 minutes)

1. Create account: https://lemonsqueezy.com
2. Create Store
3. Create Product:
   - Type: **License Key**
   - Price: **$4.20**
   - Name: **SleepBar**
   - License activations: **3**
4. Copy product ID from checkout URL
5. Update `sleepbar-website/index.html`:
   ```bash
   cd "/Users/nofarrell/Library/Mobile Documents/com~apple~CloudDocs/Documents/SleepBar/sleepbar-website"
   # Replace PRODUCT_ID with your actual ID
   git add index.html
   git commit -m "Add Lemon Squeezy product links"
   git push
   ```

---

## 📋 Pre-Release Checklist

- [ ] Sparkle framework added
- [ ] Sparkle keys generated and added to Info.plist
- [ ] Domain purchased and DNS configured
- [ ] GitHub Pages enabled with custom domain
- [ ] Lemon Squeezy product created
- [ ] Website updated with product links
- [ ] App version set to 1.0.0

---

## 🚀 Creating Your First Release

### 1. Build & Archive in Xcode

In Xcode:
1. **Product → Archive**
2. **Distribute App → Developer ID**
3. **Upload** (notarizes with Apple, wait 5-30 minutes)
4. **Export Notarized App**
5. Copy exported `SleepBar.app` to the releases directory

### 2. Create DMG with Build Script

```bash
# Navigate to releases directory
cd "/Users/nofarrell/Library/Mobile Documents/com~apple~CloudDocs/Documents/SleepBar/SleepBar/releases"

# Place your exported SleepBar.app here
# Then run the build script:
./build_release.sh 1.0.0
```

The script will:
- ✓ Create a temp directory (`build/tmp`)
- ✓ Copy your app
- ✓ Add Applications folder symlink
- ✓ Create and sign the DMG
- ✓ Verify signatures
- ✓ Clean up temp files

Output: `releases/build/SleepBar-1.0.0.dmg`

**Pro tip:** When users open the DMG, they'll see your app and an Applications folder link. They can drag SleepBar to Applications for easy installation.

### 3. Create GitHub Release

```bash
# From releases directory
gh release create v1.0.0 \
  --repo zcpnate/sleepbar \
  --title "SleepBar 1.0.0 - Initial Release" \
  --notes "🎉 Initial release of SleepBar!" \
  build/SleepBar-1.0.0.dmg
```

### 4. Generate Appcast

```bash
cd "/Users/nofarrell/Library/Mobile Documents/com~apple~CloudDocs/Documents/SleepBar/sleepbar-website"

# Download release
wget https://github.com/zcpnate/sleepbar/releases/download/v1.0.0/SleepBar-1.0.0.dmg

# Generate appcast
~/Library/Developer/Xcode/DerivedData/SleepBar-*/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast .

# Push to GitHub Pages
git add appcast.xml *.delta
git commit -m "Add appcast for v1.0.0"
git push
```

### 5. Test

1. Download from website
2. Test license activation with Lemon Squeezy purchase
3. Verify "Check for Updates" works

---

## 🔗 Important URLs

| Service | URL |
|---------|-----|
| Website | https://sleepbar.app |
| Private Repo | https://github.com/zcpnate/sleepbar-private |
| Public Repo | https://github.com/zcpnate/sleepbar |
| GitHub Pages Settings | https://github.com/zcpnate/sleepbar/settings/pages |
| Releases | https://github.com/zcpnate/sleepbar/releases |
| Appcast | https://sleepbar.app/appcast.xml |
| Lemon Squeezy | https://app.lemonsqueezy.com |

---

## 🆘 Troubleshooting

### Sparkle Issues
- **"Cannot find 'Sparkle' in scope"**: Clean build (Cmd+Shift+K), restart Xcode
- **Updates not working**: Verify `SUFeedURL` and `SUPublicEDKey` in Info.plist
- **Invalid signature**: Ensure private key is in Keychain

### GitHub Pages Issues
- **Not showing**: Wait 1-2 minutes, check Settings → Pages
- **Shows README**: Ensure `index.html` is in root, branch set to `main`

### DNS Issues
- **Domain not working**: DNS takes 24-48 hours to propagate
- **Temporary URL**: Use `zcpnate.github.io/sleepbar` while waiting

### License Issues
- **Activation failing**: Verify Lemon Squeezy product is published
- **Test in sandbox mode first**

---

## 📚 Resources

- **Sparkle**: https://sparkle-project.org/documentation/
- **Lemon Squeezy**: https://docs.lemonsqueezy.com/
- **GitHub Pages**: https://docs.github.com/en/pages

---

## 🔒 Security Reminders

**Never commit:**
- ❌ Sparkle private signing key
- ❌ Apple Developer certificates
- ❌ Lemon Squeezy API keys

**Always:**
- ✅ Keep Sparkle private key in Keychain
- ✅ Back up signing keys securely
- ✅ Use HTTPS for appcast URLs
- ✅ Code-sign with Developer ID

---

## ✨ You're Ready!

Once setup is complete, you'll have:
- ✅ Private source code repo
- ✅ Public website on GitHub Pages
- ✅ Release distribution via GitHub
- ✅ Auto-updates via Sparkle
- ✅ Licensing via Lemon Squeezy

For ongoing releases and development, see the main [README.md](../README.md).

