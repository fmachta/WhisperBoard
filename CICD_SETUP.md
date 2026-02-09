# WhisperBoard CI/CD & TestFlight Setup Guide

This guide will help you set up automated TestFlight deployments for WhisperBoard.

## Prerequisites

1. **Xcode installed** (from Mac App Store)
2. **Apple Developer Account** ($99/year) - [Enroll here](https://developer.apple.com/programs/)
3. **GitHub account** (you already have this)

## Step 1: Initial Setup

### 1.1 Install Dependencies

```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install fastlane
brew install fastlane

# Or use gem
gem install fastlane
```

### 1.2 Initialize Fastlane

```bash
cd /path/to/WhisperBoard
fastlane init
```

Follow the prompts:
- Choose "Automated beta deploy to TestFlight"
- Enter your Apple ID
- Select your team

## Step 2: Code Signing with Match (Recommended)

Match securely stores your certificates in a private Git repo.

### 2.1 Create Private Repository

1. Go to GitHub → New Repository
2. Name it `whisperboard-certificates` (or any private name)
3. Make it **Private**
4. Don't initialize with README

### 2.2 Setup Match

```bash
# Update Matchfile with your private repo URL
# Edit fastlane/Matchfile and uncomment/set:
# git_url("https://github.com/YOUR_USERNAME/whisperboard-certificates")

# Run match to create certificates
fastlane match appstore
fastlane match development
```

Enter a **Match password** when prompted. **Save this password!** You'll need it for CI/CD.

## Step 3: App Store Connect API Key

### 3.1 Generate API Key

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Users and Access → Keys → App Store Connect API
3. Click "+" to create new key
4. Name: "WhisperBoard CI/CD"
5. Role: **App Manager** (or Admin)
6. Click "Generate"
7. **Download the .p8 file immediately** (you can only download once!)
8. Note the **Key ID** and **Issuer ID**

### 3.2 Add Secrets to GitHub

Go to your GitHub repo → Settings → Secrets and variables → Actions → New repository secret

Add these secrets:

| Secret Name | Value |
|-------------|-------|
| `APP_STORE_CONNECT_API_KEY_ID` | Your Key ID from step 3.1 |
| `APP_STORE_CONNECT_API_ISSUER_ID` | Your Issuer ID from step 3.1 |
| `APP_STORE_CONNECT_API_KEY_CONTENT` | Base64-encoded content of the .p8 file |
| `MATCH_PASSWORD` | The password you set for match |
| `MATCH_GIT_BASIC_AUTHORIZATION` | Base64 of `username:personal_access_token` |

To generate `MATCH_GIT_BASIC_AUTHORIZATION`:
```bash
echo -n "your_github_username:your_personal_access_token" | base64
```

Generate a Personal Access Token:
- GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
- Generate new token with `repo` scope

## Step 4: Configure Fastlane

### 4.1 Update Appfile

Edit `fastlane/Appfile` and fill in:

```ruby
team_id("YOUR_TEAM_ID")  # From Apple Developer Portal
team_name("YOUR_NAME")
apple_id("your.email@example.com")
```

Find your Team ID:
- [Apple Developer Portal](https://developer.apple.com/account) → Membership

### 4.2 Update Matchfile

Edit `fastlane/Matchfile`:

```ruby
git_url("https://github.com/YOUR_USERNAME/whisperboard-certificates")
storage_mode("git")
type("appstore")
team_id("YOUR_TEAM_ID")
app_identifier(["com.fmachta.whisperboard", "com.fmachta.whisperboard.keyboard"])
username("your.email@example.com")
```

## Step 5: First Manual Upload

Before CI/CD works, you need to manually upload once:

### 5.1 Build Locally

```bash
fastlane beta
```

This will:
- Build the app
- Upload to TestFlight
- You'll get an email when it's ready

### 5.2 Configure TestFlight

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. My Apps → WhisperBoard → TestFlight
3. Add yourself as an internal tester
4. Download the TestFlight app on your iPhone
5. Accept the invitation

## Step 6: Automated CI/CD

Once Step 5 works manually, CI/CD will work automatically!

### How to Trigger Automated Deploy

1. Go to GitHub repo → Actions → "iOS Build & TestFlight"
2. Click "Run workflow"
3. Select "beta" or "production"
4. Click "Run workflow"

Or push to main branch with a tag:
```bash
git tag -a "v1.0.0-beta.1" -m "Beta release 1"
git push origin v1.0.0-beta.1
```

## Available Fastlane Commands

```bash
# Run tests
fastlane test

# Build locally
fastlane build

# Deploy to TestFlight
fastlane beta

# Deploy to App Store
fastlane release

# Sync certificates
fastlane sync_certs

# Take screenshots
fastlane screenshots
```

## Troubleshooting

### "Certificate not found"
```bash
fastlane match development --force
fastlane match appstore --force
```

### "Invalid API key"
- Check that the .p8 file content is base64-encoded correctly
- Verify Key ID and Issuer ID are correct
- Ensure the API key hasn't expired

### "No provisioning profile found"
```bash
fastlane match appstore --force_for_new_devices
```

### "Authentication failed"
- Check your MATCH_PASSWORD is correct
- Verify MATCH_GIT_BASIC_AUTHORIZATION is valid
- Ensure your GitHub token has `repo` scope

## Security Best Practices

1. **Never commit certificates** - Match stores them encrypted in Git
2. **Use GitHub Secrets** - Never put API keys in code
3. **Rotate keys regularly** - Regenerate API keys every 6 months
4. **Use separate keys for CI** - Don't use your personal Apple ID
5. **Enable 2FA** - On your Apple ID and GitHub account

## Next Steps

1. ✅ Install Xcode
2. ✅ Enroll in Apple Developer Program
3. ✅ Run `fastlane init`
4. ✅ Setup Match for code signing
5. ✅ Create App Store Connect API key
6. ✅ Add GitHub secrets
7. ✅ Configure Appfile and Matchfile
8. ✅ Run `fastlane beta` manually
9. ✅ Test automated CI/CD

## Help

- [Fastlane Documentation](https://docs.fastlane.tools)
- [Match Documentation](https://docs.fastlane.tools/actions/match/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [App Store Connect API](https://developer.apple.com/documentation/appstoreconnectapi)

---

**Questions?** Open an issue on GitHub!
