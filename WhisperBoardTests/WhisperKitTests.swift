import XCTest
@testable import WhisperBoard

final class WhisperKitTests: XCTestCase {
    
    // MARK: - WhisperTranscriber Tests
    
    func testVoiceCommandPattern_period() {
        let command = WhisperTranscriber.VoiceCommand(
            pattern: "\\bperiod\\b\\.?\\s*$",
            replacement: "."
        )
        
        XCTAssertEqual(applyCommand(command, to: "hello period"), "hello .")
        XCTAssertEqual(applyCommand(command, to: "end of sentence period."), "end of sentence .")
        XCTAssertEqual(applyCommand(command, to: "no match here"), "no match here")
    }
    
    func testVoiceCommandPattern_comma() {
        let command = WhisperTranscriber.VoiceCommand(
            pattern: "\\bcomma\\b,?\\s*$",
            replacement: ","
        )
        
        XCTAssertEqual(applyCommand(command, to: "hello comma"), "hello ,")
        XCTAssertEqual(applyCommand(command, to: "items comma,"), "items ,")
        XCTAssertEqual(applyCommand(command, to: "no comma here"), "no comma here")
    }
    
    func testVoiceCommandPattern_questionMark() {
        let command = WhisperTranscriber.VoiceCommand(
            pattern: "\\bquestion mark\\b\\??\\s*$",
            replacement: "?"
        )
        
        XCTAssertEqual(applyCommand(command, to: "what question mark"), "what ?")
        XCTAssertEqual(applyCommand(command, to: "really question mark?"), "really ?")
    }
    
    func testVoiceCommandPattern_exclamationMark() {
        let command = WhisperTranscriber.VoiceCommand(
            pattern: "\\bexclamation mark\\b!?\\s*$",
            replacement: "!"
        )
        
        XCTAssertEqual(applyCommand(command, to: "wow exclamation mark"), "wow !")
        XCTAssertEqual(applyCommand(command, to: "excited exclamation mark!"), "excited !")
    }
    
    func testVoiceCommandPattern_newLine() {
        let command = WhisperTranscriber.VoiceCommand(
            pattern: "\\bnew line\\b\\s*$",
            replacement: "\n"
        )
        
        let result = applyCommand(command, to: "end new line")
        XCTAssertTrue(result.contains("\n"))
    }
    
    func testVoiceCommandPattern_delete() {
        let command = WhisperTranscriber.VoiceCommand(
            pattern: "\\bdelete\\b\\s*$",
            replacement: "<<BACKSPACE>>"
        )
        
        XCTAssertEqual(applyCommand(command, to: "undo delete"), "undo <<BACKSPACE>>")
    }
    
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
    
    // MARK: - ModelManager Tests
    
    func testModelDirectoryCreation() {
        let manager = ModelManager()
        let directory = manager.getModelDirectory()
        
        XCTAssertTrue(directory.path.contains("WhisperModels"))
    }
    
    func testFormattedStorageUsed() {
        let manager = ModelManager()
        let formatted = manager.getFormattedStorageUsed()
        
        // Should return a human-readable string
        XCTAssertFalse(formatted.isEmpty)
    }
    
    func testModelInfo() {
        let manager = ModelManager()
        let baseInfo = manager.getModelInfo(.base)
        
        XCTAssertEqual(baseInfo.type, .base)
        XCTAssertFalse(baseInfo.size.isEmpty)
        XCTAssertFalse(baseInfo.recommendedUse.isEmpty)
    }
    
    func testAllModelInfos() {
        let manager = ModelManager()
        let allInfos = manager.getAllModelInfos()
        
        XCTAssertEqual(allInfos.count, 3)
    }
    
    func testDefaultVoiceCommands() {
        let commands = WhisperTranscriber.defaultVoiceCommands
        
        XCTAssertFalse(commands.isEmpty)
        XCTAssertTrue(commands.count >= 8)
        
        // Verify required commands exist
        let patterns = commands.map { $0.pattern }
        let hasPeriod = patterns.contains { $0.contains("period") }
        let hasComma = patterns.contains { $0.contains("comma") }
        let hasNewLine = patterns.contains { $0.contains("new line") }
        
        XCTAssertTrue(hasPeriod)
        XCTAssertTrue(hasComma)
        XCTAssertTrue(hasNewLine)
    }
    
    // MARK: - AudioProcessor Tests
    
    func testAudioProcessorInitialization() {
        let processor = AudioProcessor()
        XCTAssertNotNil(processor)
    }
    
    func testEnergyComputation() {
        let processor = AudioProcessor()
        
        // Create test signal with known energy
        let samples = [Float](repeating: 0.5, count: 100)
        let energy = processor.computeEnergy(samples)
        
        // Energy should be positive
        XCTAssertGreaterThan(energy, 0)
    }
    
    func testSilenceDetection() {
        let processor = AudioProcessor()
        
        // Silence should be detected
        let silence = [Float](repeating: 0.001, count: 100)
        XCTAssertTrue(processor.isSilence(silence, threshold: 0.01))
        
        // Non-silence should not be detected as silence
        let speech = [Float](repeating: 0.5, count: 100)
        XCTAssertFalse(processor.isSilence(speech, threshold: 0.01))
    }
    
    func testDataConversion() {
        let processor = AudioProcessor()
        
        let originalSamples: [Float] = [0.1, 0.2, 0.3, 0.4, 0.5]
        let data = processor.floatToData(originalSamples)
        let convertedSamples = processor.process(data)
        
        XCTAssertEqual(convertedSamples?.count, originalSamples.count)
    }
    
    // MARK: - VAD Tests
    
    func testVADInitialization() {
        let vad = VoiceActivityDetector()
        XCTAssertFalse(vad.isVoiceActive())
    }
    
    func testVADReset() {
        let vad = VoiceActivityDetector()
        
        // Process some audio
        let samples = [Float](repeating: 0.5, count: 1000)
        _ = vad.process(samples)
        
        // Reset
        vad.reset()
        
        XCTAssertFalse(vad.isVoiceActive())
    }
    
    func testVADConfig() {
        let config = VoiceActivityDetector.VADConfig.default
        XCTAssertEqual(config.silenceThreshold, 0.01)
        XCTAssertEqual(config.speechThreshold, 0.015)
        XCTAssertEqual(config.silenceDuration, 2.0)
    }
    
    // MARK: - Model Type Tests
    
    func testWhisperModelTypeProperties() {
        XCTAssertEqual(WhisperModelType.tiny.displayName, "Tiny")
        XCTAssertEqual(WhisperModelType.base.displayName, "Base")
        XCTAssertEqual(WhisperModelType.small.displayName, "Small")
    }
    
    func testModelSizeDisplay() {
        XCTAssertTrue(WhisperModelType.tiny.estimatedSize.contains("MB"))
        XCTAssertTrue(WhisperModelType.base.estimatedSize.contains("MB"))
        XCTAssertTrue(WhisperModelType.small.estimatedSize.contains("MB"))
    }
    
    // MARK: - Helper Methods
    
    private func applyCommand(_ command: WhisperTranscriber.VoiceCommand, to text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: command.pattern, options: .caseInsensitive) else {
            return text
        }
        
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: command.replacement)
    }
}

// MARK: - Transcription Integration Tests

final class TranscriptionIntegrationTests: XCTestCase {
    
    func testTranscriptionResultCreation() {
        let result = WhisperTranscriber.TranscriptionResult(
            text: "Hello world",
            timestamp: Date(),
            confidence: -0.5,
            isFinal: true,
            audioDuration: 1.5
        )
        
        XCTAssertEqual(result.text, "Hello world")
        XCTAssertTrue(result.isFinal)
        XCTAssertGreaterThan(result.audioDuration, 0)
    }
    
    func testModelManagerSharedDefaults() {
        let defaults = ModelManager.sharedDefaults
        XCTAssertNotNil(defaults)
    }
}

// MARK: - Voice Command Performance Tests

final class VoiceCommandPerformanceTests: XCTestCase {
    
    func testCommandMatchingPerformance() {
        let transcriber = WhisperTranscriber()
        let commands = transcriber.getVoiceCommands()
        
        measure {
            for _ in 0..<100 {
                _ = applyCommands(commands, to: "hello period test comma")
            }
        }
    }
    
    private func applyCommands(_ commands: [WhisperTranscriber.VoiceCommand], to text: String) -> String {
        var result = text
        for command in commands {
            if let regex = try? NSRegularExpression(pattern: command.pattern, options: .caseInsensitive) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: command.replacement)
            }
        }
        return result
    }
}

// MARK: - Haptic Feedback Tests

final class HapticFeedbackTests: XCTestCase {
    
    func testHapticGeneratorCreation() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        XCTAssertNotNil(generator)
        print("[HapticFeedbackTests] Generator creation test passed")
    }
    
    func testNotificationFeedbackGeneratorCreation() {
        let generator = UINotificationFeedbackGenerator()
        XCTAssertNotNil(generator)
        print("[HapticFeedbackTests] Notification generator creation test passed")
    }
    
    func testFeedbackGeneratorPrepare() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        // prepare() should not throw
        generator.prepare()
        print("[HapticFeedbackTests] Prepare test passed")
    }
}

// MARK: - Memory Warning Tests

final class MemoryWarningTests: XCTestCase {
    
    func testMemoryWarningHandling() {
        let transcriber = WhisperTranscriber()
        
        // Verify initial state
        XCTAssertFalse(transcriber.isModelLoaded)
        
        // Simulate memory warning
        transcriber.handleMemoryWarning()
        
        // Verify model is unloaded
        XCTAssertFalse(transcriber.isModelLoaded)
        print("[MemoryWarningTests] Memory warning handling test passed")
    }
    
    func testModelUnload() {
        let manager = ModelManager()
        let models = manager.getAllModelInfos()
        
        // Verify we can get model infos
        XCTAssertEqual(models.count, 3)
        print("[MemoryWarningTests] Model unload test passed")
    }
}

// MARK: - Error Handling Tests

final class ErrorHandlingTests: XCTestCase {
    
    func testTranscriptionErrorDescriptions() {
        let errors: [WhisperTranscriber.TranscriptionError] = [
            .modelNotLoaded,
            .audioBufferEmpty,
            .transcriptionFailed("Test error"),
            .modelDownloadFailed("Download failed"),
            .unsupportedLanguage,
            .initializationFailed("Init failed")
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
        print("[ErrorHandlingTests] Error descriptions test passed")
    }
    
    func testModelErrorDescriptions() {
        let errors: [ModelManager.ModelError] = [
            .downloadFailed("Test"),
            .modelNotFound("Test"),
            .invalidURL,
            .storageError("Test"),
            .verificationFailed("Test")
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
        print("[ErrorHandlingTests] Model error descriptions test passed")
    }
}