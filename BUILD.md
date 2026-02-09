# WhisperBoard Build Instructions

This document provides detailed build instructions for WhisperBoard iOS keyboard extension.

## Prerequisites

- **macOS**: Ventura 14.0+ recommended
- **Xcode**: 15.0 or higher
- **iOS SDK**: iOS 16.0+
- **Apple Developer Account**: For code signing and testing on device
- **Git**: For version control

## Quick Start

```bash
# Clone the repository
git clone https://github.com/fmachta/WhisperBoard.git
cd WhisperBoard

# Open in Xcode
open WhisperBoard.xcodeproj

# Build and run on a physical device
```

## Project Structure

```
WhisperBoard/
├── WhisperBoard/                    # Main iOS App
│   ├── App/                         # App entry point
│   ├── Sources/
│   │   ├── App/                     # App lifecycle
│   │   ├── KeyboardExtension/      # Keyboard extension
│   │   ├── Views/                   # SwiftUI views
│   │   └── WhisperKit/              # Whisper integration
│   └── Resources/                   # Assets
├── WhisperBoardTests/               # Unit tests
├── WhisperBoard.xcodeproj/          # Xcode project
├── AppStore/                        # App Store assets
├── Package.swift                    # Swift Package dependencies
└── README.md / BUILD.md             # Documentation
```

## Dependencies

WhisperBoard uses Swift Package Manager for dependencies:

| Dependency | Version | Purpose |
|------------|---------|---------|
| WhisperKit | 0.1.0+ | On-device speech recognition |
| KeyboardKit | 13.0.0+ | Keyboard extension helpers |

### Dependency Management

```bash
# Resolve dependencies
File → Packages → Resolve Package Versions

# Update dependencies
File → Packages → Update to Latest Package Versions
```

## Build Configuration

### Debug Build

For development and testing:

1. Select `WhisperBoard` scheme in Xcode
2. Set build configuration to `Debug`
3. Select target device (iPhone physical device required for audio)

```bash
# Command line build
xcodebuild -project WhisperBoard.xcodeproj \
  -scheme WhisperBoard \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  build
```

### Release Build

For App Store submission:

1. Select `WhisperBoard` scheme in Xcode
2. Set build configuration to `Release`
3. Ensure code signing is configured

```bash
# Command line release build
xcodebuild -project WhisperBoard.xcodeproj \
  -scheme WhisperBoard \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  build
```

## Code Signing

### Development

1. Open project in Xcode
2. Select `WhisperBoard` project in navigator
3. Select each target:
   - `WhisperBoard` (iOS App)
   - `WhisperBoardKeyboard` (Keyboard Extension)
4. Set `Team` to your Apple Developer team
5. Set bundle identifiers:
   - App: `com.whisperboard.app`
   - Keyboard: `com.whisperboard.app.keyboard`
6. Enable `Automatically manage signing`

### App Store

1. Create App Store distribution certificate
2. Create provisioning profile for App Store
3. Configure in Xcode or via command line:

```bash
xcodebuild -project WhisperBoard.xcodeproj \
  -scheme WhisperBoard \
  -configuration Release \
  CODE_SIGN_IDENTITY="Apple Distribution" \
  CODE_SIGNING_REQUIRED=YES \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Capabilities & Entitlements

### Required Capabilities

Both targets require:

- **App Group**: `group.com.whisperboard.shared`
- **Microphone Usage**: Required for keyboard extension
- **Full Access**: For keyboard extension functionality

### Info.plist Configuration

**WhisperBoard (App)**:
```xml
<key>NSCmicrophoneUsageDescription</key>
<string>WhisperBoard needs microphone access for voice-to-text transcription.</string>
```

**WhisperBoardKeyboard (Extension)**:
```xml
<key>NSCmicrophoneUsageDescription</key>
<string>WhisperBoard needs microphone access for voice-to-text transcription.</string>
<key>RequestsOpenAccess</key>
<true/>
```

## Testing

### Unit Tests

Run all unit tests:

```bash
xcodebuild test \
  -project WhisperBoard.xcodeproj \
  -scheme WhisperBoard \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  CODE_SIGN_IDENTITY="Apple Development"
```

### Test Coverage

| Test Suite | Location | Purpose |
|------------|----------|---------|
| WhisperKitTests | WhisperBoardTests/ | WhisperKit integration tests |
| AudioPipelineTests | WhisperBoardTests/ | Audio capture, processing, VAD tests |
| HapticFeedbackTests | WhisperBoardTests/ | Haptic feedback tests |
| MemoryWarningTests | WhisperBoardTests/ | Memory warning handling tests |
| ErrorHandlingTests | WhisperBoardTests/ | Error handling tests |

### Manual Testing Checklist

- [ ] Keyboard appears in Settings → General → Keyboard → Keyboards
- [ ] Can switch to WhisperBoard using globe key
- [ ] Microphone button responds to tap
- [ ] Haptic feedback on key press
- [ ] Light/dark mode works correctly
- [ ] Recording starts and stops properly
- [ ] Transcription appears in text field

## Performance Targets

| Metric | Target | Notes |
|--------|--------|-------|
| Memory Usage | < 150MB | During transcription |
| Transcription Latency | < 500ms | Short phrases |
| Model Load Time | < 5 seconds | First load |
| Battery Impact | < 5% per hour | Active use |

## Troubleshooting

### Build Errors

**"No such module 'WhisperKit'"**
- Resolve Swift Package Manager dependencies
- Clean build folder (Product → Clean Build Folder)

**Code signing errors**
- Verify Apple Developer account access
- Check bundle identifiers match provisioning profile
- Ensure capabilities are enabled in Apple Developer portal

**Runtime crashes**
- Test on physical device (simulator doesn't support microphone)
- Check microphone permissions in Settings
- Verify App Group configuration

### Audio Issues

**Microphone not working**
- Enable microphone permission in Settings → WhisperBoard
- Check App Group configuration
- Verify audio session configuration

**Poor transcription quality**
- Ensure quiet environment during testing
- Speak clearly and at normal pace
- Check VAD thresholds in settings

### Performance Issues

**High memory usage**
- Monitor via Xcode Instruments → Allocations
- Check for memory leaks in circular buffer
- Verify model unloading on memory warning

**Slow transcription**
- Use smaller model (Tiny or Base) for testing
- Check device performance (Apple Neural Engine required)
- Verify no background processes interfering

## Continuous Integration

### GitHub Actions Workflow

```yaml
name: iOS CI
on: [push, pull_request]
jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup Xcode
        uses: maxim-lobanov/setup-xcode-action@v1
        with:
          xcode-version: '15.0'
      - name: Build
        run: xcodebuild build -project WhisperBoard.xcodeproj -scheme WhisperBoard -configuration Debug
      - name: Test
        run: xcodebuild test -project WhisperBoard.xcodeproj -scheme WhisperBoard -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Export for Testing

### Ad Hoc Distribution

1. Xcode → Product → Archive
2. Window → Organizer
3. Select archive → Distribute App → Ad Hoc
4. Select provisioning profile
5. Export .ipa file

### TestFlight Distribution

1. Xcode → Product → Archive
2. Window → Organizer
3. Select archive → Distribute App → TestFlight
4. Upload to App Store Connect
5. Add external testers

## Version Information

- **Swift Version**: 5.9
- **Minimum iOS Version**: 16.0
- **Xcode Version**: 15.0+
- **Tested Devices**: iPhone 12 and newer

## Support

- **GitHub Issues**: https://github.com/fmachta/WhisperBoard/issues
- **Email**: support@whisperboard.app

---

*Last Updated: February 2026*
*Version: 1.0.0*