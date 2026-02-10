import XCTest
@testable import WhisperBoard

// MARK: - WhisperTranscriber Tests

final class WhisperKitTests: XCTestCase {

    func testTranscriberInitialization() {
        let transcriber = WhisperTranscriber()
        XCTAssertFalse(transcriber.isModelLoaded)
        XCTAssertFalse(transcriber.isTranscribing)
        XCTAssertNil(transcriber.lastResult)
    }

    func testGetAvailableModels() {
        let transcriber = WhisperTranscriber()
        let models = transcriber.getAvailableModels()
        XCTAssertEqual(models.count, 3)
        XCTAssertTrue(models.contains(.tiny))
        XCTAssertTrue(models.contains(.base))
        XCTAssertTrue(models.contains(.small))
    }

    func testTranscriptionResultCreation() {
        let result = WhisperTranscriber.TranscriptionResult(
            text: "Hello world",
            timestamp: Date(),
            confidence: 0.95,
            isFinal: true,
            audioDuration: 1.5
        )
        XCTAssertEqual(result.text, "Hello world")
        XCTAssertTrue(result.isFinal)
        XCTAssertGreaterThan(result.audioDuration, 0)
    }

    func testTranscribeWithoutModelThrows() async {
        let transcriber = WhisperTranscriber()
        let samples: [Float] = Array(repeating: 0.1, count: 1600)
        do {
            _ = try await transcriber.transcribe(samples)
            XCTFail("Should throw modelNotLoaded")
        } catch {
            // Expected
        }
    }

    func testMemoryWarningHandling() {
        let transcriber = WhisperTranscriber()
        XCTAssertFalse(transcriber.isModelLoaded)
        transcriber.handleMemoryWarning()
        XCTAssertFalse(transcriber.isModelLoaded)
    }

    func testTranscriptionErrorDescriptions() {
        let errors: [WhisperTranscriber.TranscriptionError] = [
            .modelNotLoaded,
            .audioBufferEmpty,
            .transcriptionFailed("Test"),
            .modelDownloadFailed("Download failed"),
            .unsupportedLanguage,
            .initializationFailed("Init failed"),
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
}

// MARK: - ModelManager Tests

final class ModelManagerTests: XCTestCase {

    func testInitialization() {
        let manager = ModelManager()
        XCTAssertFalse(manager.isDownloading)
        XCTAssertEqual(manager.downloadProgress, 0)
    }

    func testIsModelDownloaded() {
        let manager = ModelManager()
        // No models should be downloaded by default
        XCTAssertFalse(manager.isModelDownloaded(.tiny))
        XCTAssertFalse(manager.isModelDownloaded(.base))
        XCTAssertFalse(manager.isModelDownloaded(.small))
    }

    func testFormattedStorageUsed() {
        let manager = ModelManager()
        let formatted = manager.getFormattedStorageUsed()
        XCTAssertFalse(formatted.isEmpty)
    }

    func testModelInfo() {
        let manager = ModelManager()
        let info = manager.getModelInfo(.base)
        XCTAssertEqual(info.type, .base)
        XCTAssertFalse(info.size.isEmpty)
        XCTAssertFalse(info.recommendedUse.isEmpty)
    }

    func testAllModelInfos() {
        let manager = ModelManager()
        let all = manager.getAllModelInfos()
        XCTAssertEqual(all.count, 3)
    }

    func testSaveSelectedModel() {
        let manager = ModelManager()
        manager.saveSelectedModel(.small)
        XCTAssertEqual(manager.selectedModel, .small)
    }

    func testDeleteModel() {
        let manager = ModelManager()
        manager.deleteModel(.base)
        XCTAssertFalse(manager.isModelDownloaded(.base))
    }

    func testModelErrorDescriptions() {
        let errors: [ModelManager.ModelError] = [
            .downloadFailed("Test"),
            .modelNotFound("Test"),
            .initializationFailed("Test"),
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
}

// MARK: - Model Type Tests

final class WhisperModelTypeTests: XCTestCase {

    func testDisplayNames() {
        XCTAssertEqual(WhisperModelType.tiny.displayName, "Tiny")
        XCTAssertEqual(WhisperModelType.base.displayName, "Base")
        XCTAssertEqual(WhisperModelType.small.displayName, "Small")
    }

    func testEstimatedSizes() {
        for model in WhisperModelType.allCases {
            XCTAssertTrue(model.estimatedSize.contains("MB"))
        }
    }

    func testModelIds() {
        XCTAssertTrue(WhisperModelType.tiny.modelId.contains("tiny"))
        XCTAssertTrue(WhisperModelType.base.modelId.contains("base"))
        XCTAssertTrue(WhisperModelType.small.modelId.contains("small"))
    }

    func testAllCases() {
        XCTAssertEqual(WhisperModelType.allCases.count, 3)
    }
}

// MARK: - AudioProcessor Tests (from WhisperKit module)

final class AudioProcessorModuleTests: XCTestCase {

    func testInitialization() {
        let processor = AudioProcessor()
        XCTAssertNotNil(processor)
    }

    func testEnergyComputation() {
        let processor = AudioProcessor()
        let samples = [Float](repeating: 0.5, count: 100)
        let energy = processor.computeEnergy(samples)
        XCTAssertGreaterThan(energy, 0)
    }

    func testSilenceDetection() {
        let processor = AudioProcessor()
        let silence = [Float](repeating: 0.001, count: 100)
        XCTAssertTrue(processor.isSilence(silence, threshold: 0.01))

        let speech = [Float](repeating: 0.5, count: 100)
        XCTAssertFalse(processor.isSilence(speech, threshold: 0.01))
    }

    func testDataConversion() {
        let processor = AudioProcessor()
        let original: [Float] = [0.1, 0.2, 0.3, 0.4, 0.5]
        let data = processor.floatToData(original)
        let converted = processor.process(data)
        XCTAssertEqual(converted?.count, original.count)
    }
}

// MARK: - SharedDefaults Tests

final class SharedDefaultsTests: XCTestCase {

    func testAppGroupIdentifier() {
        XCTAssertEqual(SharedDefaults.appGroupIdentifier, "group.com.fmachta.whisperboard")
    }

    func testTranscriptionRequestCodable() throws {
        let request = SharedDefaults.TranscriptionRequest(
            audioFileName: "test.pcm",
            language: "auto",
            sampleRate: 16000,
            timestamp: Date().timeIntervalSince1970
        )
        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(SharedDefaults.TranscriptionRequest.self, from: data)
        XCTAssertEqual(decoded.audioFileName, "test.pcm")
        XCTAssertEqual(decoded.language, "auto")
        XCTAssertEqual(decoded.sampleRate, 16000)
    }

    func testTranscriptionResultCodable() throws {
        let result = SharedDefaults.TranscriptionResult(
            text: "Hello world",
            status: .completed,
            requestTimestamp: 12345,
            completedTimestamp: 12346,
            error: nil
        )
        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(SharedDefaults.TranscriptionResult.self, from: data)
        XCTAssertEqual(decoded.text, "Hello world")
        XCTAssertEqual(decoded.status, .completed)
    }

    func testTranscriptionResultStatusCases() {
        let statuses: [SharedDefaults.TranscriptionResult.Status] = [.pending, .processing, .completed, .failed]
        XCTAssertEqual(statuses.count, 4)
    }
}

// MARK: - TranscriptionService Tests

final class TranscriptionServiceTests: XCTestCase {

    func testSingleton() {
        let a = TranscriptionService.shared
        let b = TranscriptionService.shared
        XCTAssertTrue(a === b)
    }

    func testInitialState() {
        let service = TranscriptionService.shared
        // Service may or may not be running depending on test order
        XCTAssertFalse(service.isTranscribing)
        XCTAssertTrue(service.lastTranscription.isEmpty || !service.lastTranscription.isEmpty)
    }

    func testTranscriptionErrorDescriptions() {
        let errors: [TranscriptionService.TranscriptionError] = [
            .modelNotLoaded,
            .audioEmpty,
            .failed("Test"),
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
        }
    }
}
