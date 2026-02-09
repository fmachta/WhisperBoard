import XCTest
@testable import WhisperBoard

// MARK: - AudioProcessor Tests

final class AudioProcessorTests: XCTestCase {
    
    var sut: AudioProcessor!
    
    override func setUp() {
        super.setUp()
        sut = AudioProcessor()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(sut)
        print("[AudioProcessorTests] Initialization test passed")
    }
    
    // MARK: - Process Tests
    
    func testProcessWithValidSamples() {
        let samples = generateSineWave(frequency: 440, sampleRate: 16000, duration: 0.1)
        let processed = sut.process(samples)
        
        XCTAssertEqual(samples.count, processed.count)
        XCTAssertFalse(processed.allSatisfy { $0.isNaN || $0.isInfinite })
        print("[AudioProcessorTests] Process test passed with \(samples.count) samples")
    }
    
    func testProcessWithEmptySamples() {
        let samples: [Float] = []
        let processed = sut.process(samples)
        
        XCTAssertTrue(processed.isEmpty)
    }
    
    func testProcessWithSilence() {
        let samples = [Float](repeating: 0.0, count: 1600)
        let processed = sut.process(samples)
        
        XCTAssertEqual(samples.count, processed.count)
    }
    
    // MARK: - Energy Tests
    
    func testComputeEnergy() {
        let silence: [Float] = [Float](repeating: 0.0, count: 1000)
        let speech: [Float] = generateSineWave(frequency: 440, sampleRate: 16000, duration: 0.1)
        
        let silenceEnergy = sut.computeEnergy(silence)
        let speechEnergy = sut.computeEnergy(speech)
        
        XCTAssertGreaterThan(speechEnergy, silenceEnergy)
        print("[AudioProcessorTests] Energy test: silence=\(silenceEnergy), speech=\(speechEnergy)")
    }
    
    func testComputeEnergyDB() {
        let samples = generateSineWave(frequency: 440, sampleRate: 16000, duration: 0.1)
        let db = sut.computeEnergyDB(samples)
        
        XCTAssertFalse(db.isNaN)
        XCTAssertFalse(db.isInfinite)
        print("[AudioProcessorTests] Energy dB: \(db)")
    }
    
    // MARK: - Silence Detection Tests
    
    func testIsSilenceWithSilence() {
        let silence = [Float](repeating: 0.0, count: 1000)
        let isSilence = sut.isSilence(silence, threshold: 0.01)
        
        XCTAssertTrue(isSilence)
    }
    
    func testIsSilenceWithSpeech() {
        let speech = generateSineWave(frequency: 440, sampleRate: 16000, duration: 0.1)
        let isSilence = sut.isSilence(speech, threshold: 0.01)
        
        XCTAssertFalse(isSilence)
    }
    
    // MARK: - Statistics Tests
    
    func testCalculateStats() {
        let samples = generateSineWave(frequency: 440, sampleRate: 16000, duration: 0.1)
        let stats = sut.calculateStats(samples)
        
        XCTAssertGreaterThanOrEqual(stats.max, stats.min)
        XCTAssertEqual(stats.sampleCount, samples.count)
        print("[AudioProcessorTests] Stats: mean=\(stats.mean), stdDev=\(stats.stdDev)")
    }
    
    // MARK: - Data Conversion Tests
    
    func testFloatToDataConversion() {
        let samples: [Float] = [1.0, 2.0, 3.0, 4.0]
        let data = sut.floatToData(samples)
        
        XCTAssertEqual(data.count, samples.count * MemoryLayout<Float>.size)
    }
    
    func testDataToFloatConversion() {
        let samples: [Float] = [1.0, 2.0, 3.0, 4.0]
        let data = sut.floatToData(samples)
        let converted = sut.dataToFloat(data)
        
        XCTAssertEqual(samples, converted)
    }
    
    // MARK: - Helpers
    
    private func generateSineWave(frequency: Double, sampleRate: Double, duration: TimeInterval) -> [Float] {
        let sampleCount = Int(sampleRate * duration)
        var samples = [Float]()
        samples.reserveCapacity(sampleCount)
        
        for i in 0..<sampleCount {
            let time = Double(i) / sampleRate
            let sample = Float(sin(2.0 * .pi * frequency * time)) * 0.5
            samples.append(sample)
        }
        
        return samples
    }
}

// MARK: - VAD Tests

final class VADTests: XCTestCase {
    
    var sut: VoiceActivityDetector!
    
    override func setUp() {
        super.setUp()
        sut = VoiceActivityDetector()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(sut)
        XCTAssertFalse(sut.isVoiceActive())
        print("[VADTests] Initialization test passed")
    }
    
    // MARK: - Process Tests
    
    func testProcessSilenceReturnsFalse() {
        let silence = [Float](repeating: 0.0, count: 1600)
        let result = sut.process(silence)
        
        XCTAssertFalse(result.isVoice)
        XCTAssertEqual(result.state, .silence)
    }
    
    func testProcessSpeechReturnsTrue() {
        let speech = generateSineWave(frequency: 440, sampleRate: 16000, duration: 0.1)
        let result = sut.process(speech)
        
        XCTAssertTrue(result.isVoice)
        XCTAssertEqual(result.state, .speech)
        print("[VADTests] Speech detected: energy=\(result.energy), state=\(result.state)")
    }
    
    func testProcessWithData() {
        let samples = generateSineWave(frequency: 440, sampleRate: 16000, duration: 0.1)
        let data = Data(bytes: samples, count: samples.count * MemoryLayout<Float>.size)
        
        let result = sut.process(data)
        
        XCTAssertTrue(result.isVoice)
    }
    
    // MARK: - State Management Tests
    
    func testReset() {
        let speech = generateSineWave(frequency: 440, sampleRate: 16000, duration: 0.1)
        _ = sut.process(speech)
        
        XCTAssertTrue(sut.isVoiceActive())
        
        sut.reset()
        
        XCTAssertFalse(sut.isVoiceActive())
    }
    
    func testShouldStopRecordingWithSilence() {
        let silence = [Float](repeating: 0.0, count: 1600)
        _ = sut.process(silence)
        
        // Should return nil immediately as not enough silence time has passed
        let shouldStop = sut.shouldStopRecording()
        XCTAssertNil(shouldStop)
    }
    
    // MARK: - Configuration Tests
    
    func testUpdateConfig() {
        let newConfig = VoiceActivityDetector.VADConfig(
            silenceThreshold: 0.02,
            speechThreshold: 0.03,
            silenceDuration: 3.0,
            speechDuration: 0.2,
            sampleRate: 16000
        )
        
        sut.updateConfig(newConfig)
        let config = sut.getConfig()
        
        XCTAssertEqual(config.silenceThreshold, 0.02)
        XCTAssertEqual(config.speechThreshold, 0.03)
        XCTAssertEqual(config.silenceDuration, 3.0)
    }
    
    // MARK: - Preset Tests
    
    func testKeyboardOptimalPreset() {
        let detector = VoiceActivityDetector.keyboardOptimal
        XCTAssertNotNil(detector)
    }
    
    func testSensitivePreset() {
        let detector = VoiceActivityDetector.sensitive
        XCTAssertNotNil(detector)
    }
    
    func testConservativePreset() {
        let detector = VoiceActivityDetector.conservative
        XCTAssertNotNil(detector)
    }
    
    // MARK: - Helpers
    
    private func generateSineWave(frequency: Double, sampleRate: Double, duration: TimeInterval) -> [Float] {
        let sampleCount = Int(sampleRate * duration)
        var samples = [Float]()
        samples.reserveCapacity(sampleCount)
        
        for i in 0..<sampleCount {
            let time = Double(i) / sampleRate
            let sample = Float(sin(2.0 * .pi * frequency * time)) * 0.5
            samples.append(sample)
        }
        
        return samples
    }
}

// MARK: - CircularBuffer Tests

final class CircularBufferTests: XCTestCase {
    
    var sut: CircularBuffer!
    
    override func setUp() {
        super.setUp()
        // Create buffer for 1 second at 16kHz
        sut = CircularBuffer(sampleRate: 16000, maxDuration: 1.0, channels: 1)
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(sut)
        XCTAssertEqual(sut.maxSamples, 16000)
        print("[CircularBufferTests] Initialization test passed")
    }
    
    // MARK: - Write/Read Tests
    
    func testWriteAndRead() {
        let samples = generateSamples(count: 1000)
        
        // Create AVAudioPCMBuffer from samples
        let buffer = createAudioBuffer(from: samples)
        sut.write(buffer)
        
        let readData = sut.readAll()
        
        XCTAssertNotNil(readData)
        XCTAssertGreaterThan(readData!.count, 0)
    }
    
    func testReadAllSamples() {
        let samples = generateSamples(count: 500)
        let buffer = createAudioBuffer(from: samples)
        sut.write(buffer)
        
        let readSamples = sut.readAllSamples()
        
        XCTAssertNotNil(readSamples)
        XCTAssertEqual(readSamples!.count, 500)
    }
    
    func testReadDuration() {
        let samples = generateSamples(count: 8000) // 0.5 seconds
        let buffer = createAudioBuffer(from: samples)
        sut.write(buffer)
        
        let readData = sut.read(duration: 0.1)
        
        XCTAssertNotNil(readData)
        let expectedBytes = Int(16000 * 0.1) * MemoryLayout<Float>.size
        XCTAssertEqual(readData!.count, expectedBytes)
    }
    
    // MARK: - Overflow Tests
    
    func testBufferOverflow() {
        // Write more samples than buffer capacity
        let samples = generateSamples(count: 20000)
        let buffer = createAudioBuffer(from: samples)
        sut.write(buffer)
        
        // Should gracefully handle overflow
        let readData = sut.readAll()
        XCTAssertNotNil(readData)
    }
    
    // MARK: - Clear Tests
    
    func testClear() {
        let samples = generateSamples(count: 1000)
        let buffer = createAudioBuffer(from: samples)
        sut.write(buffer)
        
        sut.clear()
        
        let readData = sut.readAll()
        XCTAssertNil(readData)
    }
    
    // MARK: - Duration Tests
    
    func testCurrentDuration() {
        XCTAssertEqual(sut.currentDuration, 0.0, accuracy: 0.01)
        
        let samples = generateSamples(count: 8000) // 0.5 seconds
        let buffer = createAudioBuffer(from: samples)
        sut.write(buffer)
        
        XCTAssertEqual(sut.currentDuration, 0.5, accuracy: 0.01)
    }
    
    // MARK: - Helpers
    
    private func generateSamples(count: Int) -> [Float] {
        var samples = [Float](repeating: 0, count: count)
        for i in 0..<count {
            samples[i] = Float(i % 100) / 100.0
        }
        return samples
    }
    
    private func createAudioBuffer(from samples: [Float]) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1
        )!
        
        let frameCount = AVAudioFrameCount(samples.count)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        
        if let channelData = buffer.floatChannelData {
            samples.withUnsafeBufferPointer { sourcePtr in
                channelData[0].initialize(from: sourcePtr.baseAddress!, count: samples.count)
            }
        }
        
        return buffer
    }
}

// MARK: - Keyboard VAD Preset Tests

final class KeyboardVADPresetTests: XCTestCase {
    
    // MARK: - Keyboard Optimal Tests
    
    func testKeyboardOptimalPresetConfiguration() {
        let detector = VoiceActivityDetector.keyboardOptimal
        let config = detector.getConfig()
        
        // Verify keyboard optimal configuration
        XCTAssertEqual(config.silenceThreshold, 0.01)
        XCTAssertEqual(config.speechThreshold, 0.015)
        XCTAssertEqual(config.silenceDuration, 2.0)
        XCTAssertEqual(config.sampleRate, 16000)
        print("[KeyboardVADPresetTests] Keyboard optimal preset test passed")
    }
    
    func testSensitivePresetConfiguration() {
        let detector = VoiceActivityDetector.sensitive
        let config = detector.getConfig()
        
        // Verify sensitive configuration - lower thresholds for quiet environments
        XCTAssertLessThan(config.silenceThreshold, 0.01)
        XCTAssertLessThan(config.speechThreshold, 0.015)
        XCTAssertEqual(config.silenceDuration, 1.5)
        print("[KeyboardVADPresetTests] Sensitive preset test passed")
    }
    
    func testConservativePresetConfiguration() {
        let detector = VoiceActivityDetector.conservative
        let config = detector.getConfig()
        
        // Verify conservative configuration - higher thresholds for noisy environments
        XCTAssertGreaterThan(config.silenceThreshold, 0.01)
        XCTAssertGreaterThan(config.speechThreshold, 0.03)
        XCTAssertEqual(config.silenceDuration, 3.0)
        print("[KeyboardVADPresetTests] Conservative preset test passed")
    }
    
    // MARK: - VAD State Transition Tests
    
    func testVADStateTransitions() {
        let detector = VoiceActivityDetector()
        
        // Initial state should be silence
        XCTAssertFalse(detector.isVoiceActive())
        
        // Process silence samples
        let silenceSamples = [Float](repeating: 0.001, count: 1000)
        let silenceResult = detector.process(silenceSamples)
        XCTAssertFalse(silenceResult.isVoice)
        XCTAssertEqual(silenceResult.state, .silence)
        
        // Process speech samples
        let speechSamples = generateSineWave(frequency: 440, sampleRate: 16000, duration: 0.1)
        let speechResult = detector.process(speechSamples)
        XCTAssertTrue(speechResult.isVoice)
        XCTAssertEqual(speechResult.state, .speech)
        
        print("[KeyboardVADPresetTests] State transition test passed")
    }
    
    // MARK: - Performance Tests
    
    func testVADProcessingPerformance() {
        let detector = VoiceActivityDetector()
        let samples = generateSineWave(frequency: 440, sampleRate: 16000, duration: 1.0)
        
        measure {
            for _ in 0..<100 {
                _ = detector.process(samples)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func generateSineWave(frequency: Double, sampleRate: Double, duration: TimeInterval) -> [Float] {
        let sampleCount = Int(sampleRate * duration)
        var samples = [Float]()
        samples.reserveCapacity(sampleCount)
        
        for i in 0..<sampleCount {
            let time = Double(i) / sampleRate
            let sample = Float(sin(2.0 * .pi * frequency * time)) * 0.5
            samples.append(sample)
        }
        
        return samples
    }
}