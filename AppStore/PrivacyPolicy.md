# WhisperBoard Privacy Policy

**Last Updated:** February 2026

## Overview

WhisperBoard is designed with privacy as a core principle. This policy explains what data we collect (spoiler: almost none) and how we handle it.

## Data Collection

### What We DON'T Collect
- **Voice recordings** - Never leave your device
- **Transcriptions** - Processed locally, never uploaded
- **Keystrokes** - Only processed for text input
- **Personal information** - No accounts, no tracking
- **Location data** - Not accessed
- **Usage analytics** - No telemetry or tracking

### What We DO Collect
**Nothing.**

WhisperBoard operates entirely on your device. We have no servers, no database, and no way to access your data.

## Technical Details

### On-Device Processing
- Speech recognition runs using OpenAI Whisper models converted to Core ML
- All inference happens on your iPhone's Apple Neural Engine
- No network connections required for transcription

### Storage
- Keyboard settings stored locally on device (iOS UserDefaults)
- Whisper models downloaded to device storage
- No cloud backup of any data

### Permissions
- **Microphone**: Required to capture voice for transcription
- **Full Access**: Required for keyboard extensions to function (we don't use it to transmit data)

## Third-Party Services

WhisperBoard uses no third-party:
- Analytics services
- Crash reporting
- Cloud services
- Advertising networks

## Open Source

WhisperBoard is open source. You can inspect the code yourself:
https://github.com/fmachta/WhisperBoard

## Children's Privacy

WhisperBoard does not collect any information from anyone, including children under 13.

## Changes to This Policy

If we ever change this privacy policy (unlikely), we'll update the GitHub repository and this document.

## Contact

Questions about privacy?
- GitHub Issues: https://github.com/fmachta/WhisperBoard/issues
- Email: privacy@whisperboard.app

## Summary

**WhisperBoard cannot access your data because we never receive it.**

Everything happens on your iPhone. Your voice, your words, your privacy.
