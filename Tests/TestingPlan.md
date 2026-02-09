# WhisperBoard Testing Plan

## Testing Strategy

### Unit Tests (XCTest)
Test individual components in isolation

### UI Tests (XCUITest)  
Test user flows and keyboard integration

### Manual Testing
Device-specific testing and real-world usage

---

## Phase 1 Tests: Foundation

### Unit Tests
- [ ] `KeyboardViewControllerTests`
  - [ ] Test keyboard appears when activated
  - [ ] Test key tap inserts text
  - [ ] Test backspace removes text
  - [ ] Test return key sends action
  
- [ ] `KeyboardLayoutTests`
  - [ ] Test QWERTY layout loads correctly
  - [ ] Test shift key toggles case
  - [ ] Test number/symbol toggle

### UI Tests
- [ ] `KeyboardActivationTest`
  - [ ] Navigate to Settings > General > Keyboard
  - [ ] Add WhisperBoard keyboard
  - [ ] Verify keyboard appears in list

### Manual Tests
- [ ] Build and run on physical iPhone
- [ ] Enable keyboard in Settings
- [ ] Switch to WhisperBoard in Messages app
- [ ] Type basic text
- [ ] Test light/dark mode appearance

---

## Phase 2 Tests: Audio Pipeline

### Unit Tests
- [ ] `AudioCaptureTests`
  - [ ] Test AVAudioEngine initialization
  - [ ] Test microphone permission handling
  - [ ] Test audio format configuration (16kHz, mono)
  - [ ] Test buffer allocation
  
- [ ] `AudioProcessorTests`
  - [ ] Test sample rate conversion
  - [ ] Test mono channel extraction
  - [ ] Test Float32 conversion
  
- [ ] `VADTests`
  - [ ] Test silence detection
  - [ ] Test speech detection
  - [ ] Test auto-stop trigger

### Integration Tests
- [ ] `AudioPipelineIntegrationTest`
  - [ ] Test full audio capture flow
  - [ ] Test buffer management
  - [ ] Test memory usage stays within limits

### Manual Tests
- [ ] Tap mic button - verify recording starts
- [ ] Speak into microphone - verify audio captured
- [ ] Stop recording - verify audio stops
- [ ] Test audio session interruption (receive phone call)
- [ ] Verify no audio glitches or dropouts

---

## Phase 3 Tests: WhisperKit Integration

### Unit Tests
- [ ] `WhisperKitTests`
  - [ ] Test model download
  - [ ] Test model loading
  - [ ] Test transcription with sample audio
  - [ ] Test streaming transcription
  
- [ ] `TranscriptionManagerTests`
  - [ ] Test audio queue management
  - [ ] Test transcription result handling
  - [ ] Test error handling

### UI Tests
- [ ] `DictationFlowTest`
  - [ ] Tap mic button
  - [ ] Speak "Hello world"
  - [ ] Verify "Hello world" appears in text field
  - [ ] Test punctuation commands ("period", "comma")

### Manual Tests
- [ ] Test transcription accuracy in quiet environment
- [ ] Test transcription with background noise
- [ ] Test different accents
- [ ] Test multiple languages (if supported)
- [ ] Test offline functionality (airplane mode)
- [ ] Measure transcription latency (< 500ms target)

---

## Phase 4 Tests: Polish & E2E

### Unit Tests
- [ ] `SettingsTests`
  - [ ] Test model selection
  - [ ] Test language selection
  - [ ] Test preferences persistence

### UI Tests
- [ ] `EndToEndTest`
  - [ ] Full flow: Open Messages → Switch keyboard → Dictate → Send
  - [ ] Test keyboard switching
  - [ ] Test text insertion in different apps

### Performance Tests
- [ ] `PerformanceTests`
  - [ ] Test startup time (< 2 seconds)
  - [ ] Test memory usage (< 150MB)
  - [ ] Test battery impact
  - [ ] Test with long transcription sessions (> 5 minutes)

### Manual Tests
- [ ] Test in popular apps (Messages, Notes, Safari, Mail)
- [ ] Test with autocorrect and predictions
- [ ] Test copy/paste integration
- [ ] Test with external keyboard connected
- [ ] Test on different iPhone sizes (SE, Pro, Pro Max)
- [ ] Test with Low Power Mode
- [ ] Test with VoiceOver enabled

---

## Test Data

### Sample Audio Files
- `test_hello.wav` - "Hello world"
- `test_numbers.wav` - "One two three four five"
- `test_punctuation.wav` - "Hello period How are you question mark"
- `test_long.wav` - 30 seconds of continuous speech

### Test Phrases
- Short: "Hello", "Test", "Yes", "No"
- Medium: "The quick brown fox jumps over the lazy dog"
- Long: Technical paragraph with punctuation
- Commands: "Period", "Comma", "New line", "Question mark"

---

## CI/CD Testing

### GitHub Actions Workflow
```yaml
name: iOS Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      - name: Build
        run: xcodebuild build -scheme WhisperBoard
      - name: Test
        run: xcodebuild test -scheme WhisperBoard -destination 'platform=iOS Simulator,name=iPhone 15'
```

---

## Acceptance Criteria

### Phase 1 Complete When:
- [ ] All unit tests pass
- [ ] Keyboard appears in Settings
- [ ] Can type basic text in any app
- [ ] UI matches native iOS aesthetic

### Phase 2 Complete When:
- [ ] Audio capture works without crashes
- [ ] Audio format is correct (16kHz mono)
- [ ] VAD detects speech/silence accurately
- [ ] Memory usage stays within limits

### Phase 3 Complete When:
- [ ] WhisperKit transcribes speech accurately (> 90%)
- [ ] Transcription latency < 500ms
- [ ] Works offline
- [ ] Supports punctuation commands

### Phase 4 Complete When:
- [ ] All E2E tests pass
- [ ] Performance meets targets
- [ ] App Store ready (screenshots, description, privacy policy)
- [ ] No critical bugs

---

## Bug Reporting Template

**Title:** [Phase] Brief description

**Steps to Reproduce:**
1. Step one
2. Step two
3. Step three

**Expected Behavior:**
What should happen

**Actual Behavior:**
What actually happens

**Device:** iPhone model, iOS version
**Build:** Commit hash
**Severity:** Critical / High / Medium / Low
