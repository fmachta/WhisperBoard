# WhisperBoard 🎙️

An iOS keyboard extension that uses OpenAI Whisper locally on-device for fast, private speech-to-text transcription.

**No cloud. No subscriptions. Complete privacy.**

[![Swift Version](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2016+-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Features

- 🏃 **Local Processing** - Whisper runs entirely on-device using Core ML/MLX
- 🔒 **Private by Design** - Your voice never leaves your device
- ⚡ **Real-time Streaming** - See transcription as you speak
- 🎯 **Native iOS Integration** - Option A: Dictation button alongside system keyboard; Option B: Full custom keyboard
- 🌐 **Offline Capable** - Works without internet connection
- 📝 **Smart Formatting** - Punctuation, capitalization, and voice commands

## Architecture

```
WhisperBoard/
├── WhisperBoard/                 # Main iOS App (container)
│   ├── AppDelegate.swift
│   ├── SceneDelegate.swift
│   └── Settings/                 # App settings and model management
├── WhisperBoardKeyboard/         # Keyboard Extension
│   ├── KeyboardViewController.swift
│   ├── AudioCapture.swift        # Audio recording and buffering
│   ├── WhisperTranscriber.swift  # Whisper model inference
│   └── UI/
│       ├── KeyboardView.swift    # Custom keyboard UI
│       └── DictationButton.swift # Microphone trigger
├── WhisperCore/                  # Shared Core (Swift Package)
│   ├── WhisperModel.swift        # Model loading and management
│   ├── AudioPreprocessor.swift   # Audio → Mel spectrograms
│   └── Tokenizer.swift           # Whisper tokenizer
└── Models/                       # Core ML converted models
    └── whisper-base.mlmodel      ~75MB (default)
    └── whisper-small.mlmodel     ~244MB (optional)
```

## Implementation Roadmap

### Phase 1: Foundation & Setup
**Goal:** Project structure, dependencies, and basic keyboard extension

| Task | Status | Notes |
|------|--------|-------|
| 1.1 | ✅ | Create Xcode project with iOS app + Keyboard Extension |
| 1.2 | ⬜ | Configure App Groups for data sharing between app and extension |
| 1.3 | ⬜ | Set up Swift Package Manager dependencies |
| 1.4 | ⬜ | Basic keyboard UI skeleton (system keyboard fallback) |
| 1.5 | ⬜ | Request microphone permissions |

### Phase 2: Audio Pipeline
**Goal:** Capture and preprocess audio for Whisper

| Task | Status | Notes |
|------|--------|-------|
| 2.1 | ⬜ | Implement AVAudioEngine for microphone capture |
| 2.2 | ⬜ | Audio buffering (30-second sliding window) |
| 2.3 | ⬜ | Convert PCM → Mel spectrograms |
| 2.4 | ⬜ | Voice Activity Detection (VAD) for auto-stop |
| 2.5 | ⬜ | Audio format normalization (16kHz, mono) |

### Phase 3: Whisper Integration
**Goal:** Convert and run Whisper models on-device

| Task | Status | Notes |
|------|--------|-------|
| 3.1 | ⬜ | Convert Whisper base model to Core ML |
| 3.2 | ⬜ | Model downloading and storage management |
| 3.3 | ⬜ | Basic inference pipeline (audio → text) |
| 3.4 | ⬜ | Streaming transcription (chunked processing) |
| 3.5 | ⬜ | Post-processing (punctuation, timestamps) |

### Phase 4: Keyboard UI (Option A - Preferred)
**Goal:** Dictation button alongside iOS keyboard

| Task | Status | Notes |
|------|--------|-------|
| 4.1 | ⬜ | Research: Can we overlay on system keyboard? |
| 4.2 | ⬜ | Implement floating dictation button |
| 4.3 | ⬜ | Transcription overlay UI |
| 4.4 | ⬜ | Insert text into host app |
| 4.5 | ⬜ | Keyboard switching logic |

### Phase 5: Keyboard UI (Option B - Fallback)
**Goal:** Full custom keyboard if Option A not viable

| Task | Status | Notes |
|------|--------|-------|
| 5.1 | ⬜ | Custom QWERTY keyboard layout |
| 5.2 | ⬜ | Key press handling and haptics |
| 5.3 | ⬜ | Dictation button integration |
| 5.4 | ⬜ | Keyboard-to-keyboard switching |
| 5.5 | ⬜ | Auto-capitalization and suggestions (optional) |

### Phase 6: Polish & Optimization
**Goal:** Production-ready experience

| Task | Status | Notes |
|------|--------|-------|
| 6.1 | ⬜ | Model size optimization (quantization) |
| 6.2 | ⬜ | Battery usage optimization |
| 6.3 | ⬜ | Settings UI (model selection, language) |
| 6.4 | ⬜ | Voice commands ("period", "new line", etc.) |
| 6.5 | ⬜ | Error handling and user feedback |
| 6.6 | ⬜ | App Store preparation |

## Technical Decisions

### Why Local Whisper?
- **Privacy**: No audio sent to servers
- **Latency**: No network round-trip
- **Cost**: No API fees
- **Offline**: Works anywhere

### Model Sizes
| Model | Size | Speed | Accuracy | Use Case |
|-------|------|-------|----------|----------|
| tiny | ~39MB | Fastest | Basic | Low-end devices |
| base | ~74MB | Fast | Good | **Default choice** |
| small | ~244MB | Medium | Better | High-end devices |
| medium | ~769MB | Slow | Best | Pro users (optional) |

### Core ML vs MLX
- **Core ML**: Native iOS, optimized for Neural Engine, easier deployment
- **MLX**: Apple's ML framework, potentially better performance on Apple Silicon
- **Decision**: Start with Core ML, evaluate MLX for optimization

## Getting Started

### Prerequisites
- Xcode 15+
- iOS 16+ device (simulator won't work for audio)
- Apple Developer account (for keyboard extension signing)

### Setup
```bash
# Clone the repository
git clone https://github.com/fmachta/WhisperBoard.git
cd WhisperBoard

# Open in Xcode
open WhisperBoard.xcodeproj

# Build and run on a physical device
```

### Model Setup
The app will download models on first launch, or you can pre-bundle them:
1. Download converted Core ML models
2. Add to `Models/` directory
3. Update model manifest

## Contributing

This is an open-source project! Contributions welcome:
- 🐛 Bug reports
- 💡 Feature requests
- 🔧 Pull requests
- 📖 Documentation

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- [OpenAI Whisper](https://github.com/openai/whisper) - The underlying ASR model
- [whisper.cpp](https://github.com/ggerganov/whisper.cpp) - Inspiration for local inference
- Apple's Core ML team - For on-device ML capabilities

---

**Status:** 🚧 Early development - Phase 1 in progress
