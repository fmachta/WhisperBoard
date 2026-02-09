# WhisperBoard Development Roadmap

This document outlines the detailed implementation plan for WhisperBoard.

## Current Phase: Phase 1 - Foundation & Setup 🏗️

### Task 1.1: Xcode Project Structure
- [ ] Create new Xcode project: iOS App (Storyboard)
- [ ] Add Keyboard Extension target
- [ ] Configure bundle identifiers
- [ ] Set up code signing (for device testing)

**Estimated Time:** 1-2 hours
**Dependencies:** None

---

### Task 1.2: App Groups Configuration
- [ ] Enable App Groups capability in both targets
- [ ] Create shared container for model storage
- [ ] Set up shared UserDefaults
- [ ] Test data sharing between app and extension

**Estimated Time:** 1 hour
**Dependencies:** Task 1.1

---

### Task 1.3: Dependency Management
- [ ] Add Swift Package Manager support
- [ ] Research and select dependencies:
  - Core ML conversion tools (python-coremltools)
  - Audio processing (Accelerate framework native)
  - Optional: swift-whisper if available
- [ ] Create Package.swift or add via Xcode

**Estimated Time:** 2-3 hours
**Dependencies:** Task 1.1

---

### Task 1.4: Basic Keyboard UI
- [ ] Implement KeyboardViewController
- [ ] Create minimal keyboard view (fallback to system)
- [ ] Handle basic text input/output
- [ ] Test keyboard in host apps (Notes, Messages)

**Estimated Time:** 2-3 hours
**Dependencies:** Task 1.1

---

### Task 1.5: Permissions & Entitlements
- [ ] Add microphone usage description to Info.plist
- [ ] Add full access permission for keyboard
- [ ] Request microphone permission on first use
- [ ] Handle permission denied states

**Estimated Time:** 1 hour
**Dependencies:** Task 1.4

---

## Phase 2: Audio Pipeline 🎤

### Task 2.1: Audio Engine Setup
- [ ] Configure AVAudioEngine
- [ ] Set up input node and format (16kHz, mono)
- [ ] Handle audio session configuration
- [ ] Manage audio session interruptions

**Estimated Time:** 3-4 hours
**Dependencies:** Phase 1 complete

---

### Task 2.2: Audio Buffering
- [ ] Implement circular buffer for audio samples
- [ ] 30-second sliding window for context
- [ ] Efficient memory management
- [ ] Buffer overflow handling

**Estimated Time:** 3-4 hours
**Dependencies:** Task 2.1

---

### Task 2.3: Mel Spectrogram Conversion
- [ ] Implement FFT-based spectrogram
- [ ] Apply Mel filter banks
- [ ] Normalize to Whisper expected format
- [ ] Optimize with Accelerate framework

**Estimated Time:** 4-6 hours
**Dependencies:** Task 2.2
**Note:** This is technically complex - consider using existing Swift implementation

---

### Task 2.4: Voice Activity Detection
- [ ] Implement energy-based VAD
- [ ] Configure silence detection threshold
- [ ] Auto-stop after silence period (configurable, default 2s)
- [ ] Manual stop button as fallback

**Estimated Time:** 2-3 hours
**Dependencies:** Task 2.1

---

## Phase 3: Whisper Integration 🧠

### Task 3.1: Model Conversion
- [ ] Set up Python environment for conversion
- [ ] Install coremltools and whisper
- [ ] Convert whisper-base to Core ML
- [ ] Test model output matches Python
- [ ] Document conversion process

**Estimated Time:** 4-6 hours
**Dependencies:** None (can be done in parallel)

---

### Task 3.2: Model Management
- [ ] Create model download system
- [ ] On-device model storage
- [ ] Model versioning and updates
- [ ] First-launch model download flow

**Estimated Time:** 3-4 hours
**Dependencies:** Task 1.2, Task 3.1

---

### Task 3.3: Inference Pipeline
- [ ] Load Core ML model
- [ ] Create prediction pipeline
- [ ] Audio input → Text output
- [ ] Handle model warmup

**Estimated Time:** 4-5 hours
**Dependencies:** Task 2.3, Task 3.2

---

### Task 3.4: Streaming Transcription
- [ ] Implement chunked processing
- [ ] Overlapping windows for continuity
- [ ] Partial result handling
- [ ] Update UI in real-time

**Estimated Time:** 5-7 hours
**Dependencies:** Task 3.3

---

## Phase 4: UI Implementation (Option A) 📱

### Task 4.1: Research System Keyboard Overlay
- [ ] Investigate if dictation button overlay is possible
- [ ] Test floating button approach
- [ ] Evaluate system keyboard constraints
- [ ] Document findings and decision

**Estimated Time:** 2-3 hours
**Dependencies:** Phase 1 complete

---

### Task 4.2: Dictation Button
- [ ] Design floating button UI
- [ ] Position button above keyboard
- [ ] Handle different keyboard heights
- [ ] Animate button states (idle, listening, processing)

**Estimated Time:** 3-4 hours
**Dependencies:** Task 4.1

---

### Task 4.3: Transcription UI
- [ ] Overlay/panel for live transcription
- [ ] Confidence indicators (optional)
- [ ] Edit/cancel options
- [ ] Insert confirmation

**Estimated Time:** 3-4 hours
**Dependencies:** Task 3.4, Task 4.2

---

## Phase 5: UI Implementation (Option B) ⌨️

*Only if Option A proves infeasible*

### Task 5.1: Custom Keyboard Layout
- [ ] QWERTY key layout
- [ ] Key styling matching iOS aesthetic
- [ ] Support for light/dark mode
- [ ] Portrait and landscape layouts

**Estimated Time:** 6-8 hours
**Dependencies:** Decision to use Option B

---

## Phase 6: Polish & Release ✨

### Task 6.1-6.6: See README for full list

---

## Success Criteria

- [ ] Transcription latency < 500ms for short phrases
- [ ] Word error rate < 10% in quiet environments
- [ ] Works offline completely
- [ ] Battery impact < 5% per hour of active use
- [ ] App Store approval ready

## Timeline Estimate

- **Phase 1:** 1 week
- **Phase 2:** 1-2 weeks
- **Phase 3:** 2-3 weeks
- **Phase 4/5:** 1-2 weeks
- **Phase 6:** 1 week

**Total:** ~6-9 weeks for MVP

## Open Questions

1. Can we reliably overlay a button on the system keyboard?
2. What's the best approach for Mel spectrograms in Swift?
3. Should we support multiple languages in v1?
4. What's the minimum iOS version we should target?

---

*Last Updated: February 2026*
*Next Review: After Phase 1 completion*
