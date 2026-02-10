import Foundation
import WhisperKit
import Combine

/// Transcription coordinator for the main app.
/// Wraps WhisperKit and provides model lifecycle, transcription, and voice command processing.
/// The keyboard extension does NOT use this class – it communicates via TranscriptionService.

final class WhisperTranscriber: ObservableObject {

    // MARK: - Types

    enum TranscriptionError: Error, LocalizedError {
        case modelNotLoaded
        case modelDownloadFailed(String)
        case transcriptionFailed(String)
        case audioBufferEmpty
        case unsupportedLanguage
        case initializationFailed(String)

        var errorDescription: String? {
            switch self {
            case .modelNotLoaded:           return "Whisper model not loaded"
            case .modelDownloadFailed(let m): return "Download failed: \(m)"
            case .transcriptionFailed(let m): return "Transcription failed: \(m)"
            case .audioBufferEmpty:          return "No audio data available"
            case .unsupportedLanguage:       return "Unsupported language"
            case .initializationFailed(let m): return "Init failed: \(m)"
            }
        }
    }

    struct TranscriptionResult {
        let text: String
        let timestamp: Date
        let confidence: Float?
        let isFinal: Bool
        let audioDuration: TimeInterval
    }

    // MARK: - Published Properties

    @Published private(set) var isModelLoaded = false
    @Published private(set) var isTranscribing = false
    @Published private(set) var currentModel: WhisperModelType = .base
    @Published var lastResult: TranscriptionResult?
    @Published private(set) var downloadProgress: Double = 0

    // MARK: - Internal

    private var whisperKit: WhisperKit?
    private let modelManager: ModelManager
    private let audioProcessor: AudioProcessor

    let transcriptionQueue = DispatchQueue(label: "com.whisperboard.transcription", qos: .userInitiated)

    // Callbacks
    var onTranscriptionResult: ((TranscriptionResult) -> Void)?
    var onError: ((TranscriptionError) -> Void)?
    var onModelLoaded: (() -> Void)?

    // MARK: - Initialization

    init(modelManager: ModelManager? = nil) {
        self.modelManager = modelManager ?? ModelManager()
        self.audioProcessor = AudioProcessor()
    }

    convenience init() {
        self.init(modelManager: nil)
    }

    // MARK: - Model Lifecycle

    /// Load a Whisper model. Downloads it first if necessary.
    func loadModel(_ modelType: WhisperModelType = .base) async throws {
        await MainActor.run {
            isTranscribing = true
            downloadProgress = 0
        }

        do {
            print("[WhisperTranscriber] Loading \(modelType.displayName) model…")

            if !modelManager.isModelDownloaded(modelType) {
                print("[WhisperTranscriber] Model not cached – downloading…")
                try await modelManager.downloadModel(modelType) { [weak self] progress in
                    Task { @MainActor in self?.downloadProgress = progress }
                }
            }

            // Initialize WhisperKit
            let config = WhisperKitConfig(model: modelType.modelId)
            whisperKit = try await WhisperKit(config)

            await MainActor.run {
                isModelLoaded = true
                isTranscribing = false
                currentModel = modelType
            }

            print("[WhisperTranscriber] Model loaded: \(modelType.displayName)")
            onModelLoaded?()

        } catch {
            await MainActor.run { isTranscribing = false }
            throw TranscriptionError.initializationFailed(error.localizedDescription)
        }
    }

    func unloadModel() {
        whisperKit = nil
        Task { @MainActor in
            isModelLoaded = false
        }
        print("[WhisperTranscriber] Model unloaded")
    }

    // MARK: - Transcription

    /// Transcribe an array of Float32 audio samples (16 kHz, mono).
    func transcribe(_ audioSamples: [Float]) async throws -> TranscriptionResult {
        guard isModelLoaded, let kit = whisperKit else {
            throw TranscriptionError.modelNotLoaded
        }
        guard !audioSamples.isEmpty else {
            throw TranscriptionError.audioBufferEmpty
        }

        await MainActor.run { isTranscribing = true }

        let processed = audioProcessor.process(audioSamples)

        do {
            let options = DecodingOptions(
                language: nil,  // auto-detect
                temperature: 0.0,
                temperatureFallbackCount: 3,
                sampleLength: 224,
                usePrefillPrompt: true,
                usePrefillCache: true,
                skipSpecialTokens: true,
                withoutTimestamps: true
            )

            let segments = try await kit.transcribe(audioArray: processed, decodeOptions: options)
            let text = segments.map { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)

            let result = TranscriptionResult(
                text: text,
                timestamp: Date(),
                confidence: nil,
                isFinal: true,
                audioDuration: Double(processed.count) / 16000.0
            )

            await MainActor.run {
                lastResult = result
                isTranscribing = false
            }

            onTranscriptionResult?(result)
            return result

        } catch {
            await MainActor.run { isTranscribing = false }
            throw TranscriptionError.transcriptionFailed(error.localizedDescription)
        }
    }

    /// Transcribe raw audio Data (Float32 PCM at 16 kHz).
    func transcribe(_ audioData: Data) async throws -> TranscriptionResult {
        guard let samples = audioProcessor.process(audioData) else {
            throw TranscriptionError.audioBufferEmpty
        }
        return try await transcribe(samples)
    }

    // MARK: - Convenience

    var currentTranscription: String {
        lastResult?.text ?? ""
    }

    var isProcessing: Bool {
        isTranscribing
    }

    func getAvailableModels() -> [WhisperModelType] {
        WhisperModelType.allCases
    }

    func handleMemoryWarning() {
        print("[WhisperTranscriber] Memory warning – unloading model")
        unloadModel()
    }
}
