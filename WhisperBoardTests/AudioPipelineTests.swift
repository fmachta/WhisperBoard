import XCTest
@testable import WhisperBoard

// MARK: - AudioProcessor Tests
// AudioProcessor is compiled into the main app target (Sources/WhisperKit/)

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

    // MARK: - Initialization

    func testInitialization() {
        XCTAssertNotNil(sut)
    }

    // MARK: - Process

    func testProcessWithValidSamples() {
        let samples = generateSineWave(frequency: 440, sampleRate: 16000, duration: 0.1)
        let processed = sut.process(samples)
        XCTAssertEqual(samples.count, processed.count)
        XCTAssertFalse(processed.allSatisfy { $0.isNaN || $0.isInfinite })
    }

    func testProcessWithEmptySamples() {
        let processed = sut.process([Float]())
        XCTAssertTrue(processed.isEmpty)
    }

    func testProcessWithSilence() {
        let silence = [Float](repeating: 0.0, count: 1600)
        let processed = sut.process(silence)
        XCTAssertEqual(silence.count, processed.count)
    }

    // MARK: - Energy

    func testComputeEnergy() {
        let silence = [Float](repeating: 0.0, count: 1000)
        let speech = generateSineWave(frequency: 440, sampleRate: 16000, duration: 0.1)
        XCTAssertGreaterThan(sut.computeEnergy(speech), sut.computeEnergy(silence))
    }

    func testComputeEnergyDB() {
        let samples = generateSineWave(frequency: 440, sampleRate: 16000, duration: 0.1)
        let db = sut.computeEnergyDB(samples)
        XCTAssertFalse(db.isNaN)
        XCTAssertFalse(db.isInfinite)
    }

    // MARK: - Silence Detection

    func testIsSilenceWithSilence() {
        let silence = [Float](repeating: 0.0, count: 1000)
        XCTAssertTrue(sut.isSilence(silence, threshold: 0.01))
    }

    func testIsSilenceWithSpeech() {
        let speech = generateSineWave(frequency: 440, sampleRate: 16000, duration: 0.1)
        XCTAssertFalse(sut.isSilence(speech, threshold: 0.01))
    }

    // MARK: - Statistics

    func testCalculateStats() {
        let samples = generateSineWave(frequency: 440, sampleRate: 16000, duration: 0.1)
        let stats = sut.calculateStats(samples)
        XCTAssertGreaterThanOrEqual(stats.max, stats.min)
        XCTAssertEqual(stats.sampleCount, samples.count)
    }

    // MARK: - Data Conversion

    func testFloatToDataConversion() {
        let samples: [Float] = [1.0, 2.0, 3.0, 4.0]
        let data = sut.floatToData(samples)
        XCTAssertEqual(data.count, samples.count * MemoryLayout<Float>.size)
    }

    func testDataToFloatRoundTrip() {
        let samples: [Float] = [1.0, 2.0, 3.0, 4.0]
        let data = sut.floatToData(samples)
        let converted = sut.dataToFloat(data)
        XCTAssertEqual(samples, converted)
    }

    // MARK: - Helpers

    private func generateSineWave(frequency: Double, sampleRate: Double, duration: TimeInterval) -> [Float] {
        let count = Int(sampleRate * duration)
        return (0..<count).map { i in
            Float(sin(2.0 * .pi * frequency * Double(i) / sampleRate)) * 0.5
        }
    }
}

// NOTE: VAD, CircularBuffer, and AudioCapture tests are omitted here because
// those classes are compiled only into the WhisperBoardKeyboard extension target,
// which the test target does not link against. To test keyboard-extension code,
// a dedicated test target for WhisperBoardKeyboard would be needed.
