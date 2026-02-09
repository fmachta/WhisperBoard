import Foundation
import WhisperKit
import Combine

/// Main transcription coordinator using WhisperKit for on-device speech recognition
/// Handles model loading, transcription, and voice command processing
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
            case .modelNotLoaded:
                return "Whisper model not loaded"
            case .modelDownloadFailed(let msg):
                return "Model download failed: \(msg)"
            case .transcriptionFailed(let msg):
                return "Transcription failed: \(msg)"
            case .audioBufferEmpty:
                return "No audio data available for transcription"
            case .unsupportedLanguage:
                return "Unsupported language for transcription"
            case .initializationFailed(let msg):
                return "Initialization failed: \(msg)"
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
    
    struct VoiceCommand {
        let pattern: String
        let replacement: String
    }
    
    // MARK: - Voice Commands
    
    static let defaultVoiceCommands: [VoiceCommand] = [
        VoiceCommand(pattern: "\\bperiod\\b\\.?\\s*$", replacement: "."),
        VoiceCommand(pattern: "\\bcomma\\b,?\\s*$", replacement: ","),
        VoiceCommand(pattern: "\\bquestion mark\\b\\??\\s*$", replacement: "?"),
        VoiceCommand(pattern: "\\bexclamation mark\\b!?\\s*$", replacement: "!"),
        VoiceCommand(pattern: "\\bnew line\\b\\s*$", replacement: "\n"),
        VoiceCommand(pattern: "\\bnew paragraph\\b\\s*$", replacement: "\n\n"),
        VoiceCommand(pattern: "\\bdelete last word\\b\\s*$", replacement: "<<BACKSPACE>>"),
        VoiceCommand(pattern: "\\bbackspace\\b\\s*$", replacement: "<<BACKSPACE>>"),
        VoiceCommand(pattern: "\\bundo\\b\\s*$", replacement: "<<UNDO>>"),
    ]
    
    // MARK: - Properties
    
    @Published private(set) var isModelLoaded = false
    @Published private(set) var isTranscribing = false
    @Published private(set) var currentModel: WhisperModelType = .base
    @Published private(set) var lastResult: TranscriptionResult?
    @Published private(set) var downloadProgress: Double = 0
    
    private var whisper: WhisperKit?
    private var transcriber: AutomaticSpeechRecognizer?
    private var currentModelType: WhisperModelType = .base
    
    private let modelManager: ModelManager
    private var audioProcessor: AudioProcessor
    private var voiceCommands: [VoiceCommand]
    
    // Callbacks
    var onTranscriptionResult: ((TranscriptionResult) -> Void)?
    var onPartialTranscription: ((String) -> Void)?
    var onError: ((TranscriptionError) -> Void)?
    var onModelLoaded: (() -> Void)?
    
    // Thread safety
    private let transcriptionQueue = DispatchQueue(label: "com.whisperboard.transcription", qos: .userInitiated)
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(modelManager: ModelManager? = nil, voiceCommands: [VoiceCommand]? = nil) {
        self.modelManager = modelManager ?? ModelManager()
        self.audioProcessor = AudioProcessor()
        self.voiceCommands = voiceCommands ?? Self.defaultVoiceCommands
        self.currentModelType = modelManager?.selectedModel ?? .base
        
        setupModelManagerCallbacks()
    }
    
    // MARK: - Public Methods
    
    /// Load the Whisper model for transcription
    /// - Parameter modelType: Model size to load (default: base)
    /// - Returns: Async throwable result
    func loadModel(_ modelType: WhisperModelType = .base) async throws {
        await MainActor.run {
            isTranscribing = true
        }
        
        do {
            print("[WhisperTranscriber] Loading \(modelType.rawValue) model...")
            
            // Check if model is downloaded
            let isDownloaded = try await modelManager.isModelDownloaded(modelType)
            
            if !isDownloaded {
                print("[WhisperTranscriber] Model not found, downloading...")
                try await modelManager.downloadModel(modelType) { progress in
                    Task { @MainActor in
                        self.downloadProgress = progress
                    }
                }
            }
            
            // Load the model
            let modelPath = try await modelManager.getModelPath(modelType)
            
            // Initialize WhisperKit
            try await initializeWhisperKit(modelPath: modelPath, modelType: modelType)
            
            currentModelType = modelType
            
            await MainActor.run {
                isModelLoaded = true
                isTranscribing = false
                currentModel = modelType
            }
            
            print("[WhisperTranscriber] Model loaded successfully: \(modelType.rawValue)")
            onModelLoaded?()
            
        } catch {
            await MainActor.run {
                isTranscribing = false
            }
            throw TranscriptionError.initializationFailed(error.localizedDescription)
        }
    }
    
    /// Transcribe audio samples
    /// - Parameter audioSamples: Raw audio samples as Float array
    /// - Returns: TranscriptionResult with transcribed text
    func transcribe(_ audioSamples: [Float]) async throws -> TranscriptionResult {
        guard isModelLoaded, let transcriber = transcriber else {
            throw TranscriptionError.modelNotLoaded
        }
        
        guard !audioSamples.isEmpty else {
            throw TranscriptionError.audioBufferEmpty
        }
        
        await MainActor.run {
            isTranscribing = true
        }
        
        do {
            // Process audio (normalize, etc.)
            let processedSamples = audioProcessor.process(audioSamples)
            
            // Create audio buffer
            let audioBuffer = AudioProcessor.floatToData(processedSamples)
            
            // Run transcription using WhisperKit streaming API
            let result = try await transcriber.transcribe(audioBuffer, language: nil, task: .transcribe)
            
            let transcriptionResult = TranscriptionResult(
                text: result.text,
                timestamp: Date(),
                confidence: result.avgLogProb,
                isFinal: true,
                audioDuration: Double(processedSamples.count) / 16000.0
            )
            
            // Apply voice commands
            let processedText = applyVoiceCommands(transcriptionResult.text)
            
            let finalResult = TranscriptionResult(
                text: processedText,
                timestamp: Date(),
                confidence: transcriptionResult.confidence,
                isFinal: true,
                audioDuration: transcriptionResult.audioDuration
            )
            
            await MainActor.run {
                lastResult = finalResult
                isTranscribing = false
            }
            
            onTranscriptionResult?(finalResult)
            
            return finalResult
            
        } catch {
            await MainActor.run {
                isTranscribing = false
            }
            throw TranscriptionError.transcriptionFailed(error.localizedDescription)
        }
    }
    
    /// Transcribe audio data
    /// - Parameter audioData: Raw audio data
    /// - Returns: TranscriptionResult with transcribed text
    func transcribe(_ audioData: Data) async throws -> TranscriptionResult {
        guard let samples = audioProcessor.process(audioData) else {
            throw TranscriptionError.audioBufferEmpty
        }
        return try await transcribe(samples)
    }
    
    /// Transcribe with streaming (for real-time feedback)
    /// - Parameters:
    ///   - audioSamples: Audio samples to transcribe
    ///   - progress: Callback for partial results
    /// - Returns: Final transcription result
    func transcribeStreaming(
        _ audioSamples: [Float],
        progress: @escaping (String) -> Void
    ) async throws -> TranscriptionResult {
        guard isModelLoaded, let transcriber = transcriber else {
            throw TranscriptionError.modelNotLoaded
        }
        
        await MainActor.run {
            isTranscribing = true
        }
        
        do {
            let processedSamples = audioProcessor.process(audioSamples)
            let audioBuffer = AudioProcessor.floatToData(processedSamples)
            
            // Use WhisperKit's streaming transcription
            let result = try await transcriber.transcribe(audioBuffer, language: nil, task: .transcribe)
            
            let finalText = applyVoiceCommands(result.text)
            
            let transcriptionResult = TranscriptionResult(
                text: finalText,
                timestamp: Date(),
                confidence: result.avgLogProb,
                isFinal: true,
                audioDuration: Double(processedSamples.count) / 16000.0
            )
            
            await MainActor.run {
                lastResult = transcriptionResult
                isTranscribing = false
            }
            
            progress(finalText)
            onTranscriptionResult?(transcriptionResult)
            
            return transcriptionResult
            
        } catch {
            await MainActor.run {
                isTranscribing = false
            }
            throw TranscriptionError.transcriptionFailed(error.localizedDescription)
        }
    }
    
    /// Unload model to free memory
    func unloadModel() {
        whisper = nil
        transcriber = nil
        
        Task { @MainActor in
            isModelLoaded = false
            currentModel = .base
        }
        
        print("[WhisperTranscriber] Model unloaded")
    }
    
    /// Get available model sizes
    func getAvailableModels() -> [WhisperModelType] {
        return [.tiny, .base, .small]
    }
    
    /// Add custom voice command
    /// - Parameter command: Voice command to add
    func addVoiceCommand(_ command: VoiceCommand) {
        voiceCommands.append(command)
    }
    
    /// Remove voice command by pattern
    /// - Parameter pattern: Pattern to match and remove
    func removeVoiceCommand(pattern: String) {
        voiceCommands.removeAll { $0.pattern == pattern }
    }
    
    /// Get all voice commands
    func getVoiceCommands() -> [VoiceCommand] {
        return voiceCommands
    }
    
    /// Set voice commands
    /// - Parameter commands: Array of voice commands
    func setVoiceCommands(_ commands: [VoiceCommand]) {
        self.voiceCommands = commands
    }
    
    // MARK: - Memory Management
    
    /// Signal memory warning - should release non-essential resources
    func handleMemoryWarning() {
        print("[WhisperTranscriber] Memory warning received")
        unloadModel()
    }
    
    // MARK: - Private Methods
    
    private func setupModelManagerCallbacks() {
        modelManager.onDownloadProgress = { [weak self] progress in
            Task { @MainActor in
                self?.downloadProgress = progress
            }
        }
    }
    
    private func initializeWhisperKit(modelPath: URL, modelType: WhisperModelType) async throws {
        // Initialize WhisperKit with the model
        whisper = try await WhisperKit(
            modelPath: modelPath,
            computeUnits: .all
        )
        
        // Create transcriber
        transcriber = try await AutomaticSpeechRecognizer(whisper: whisper!)
    }
    
    private func applyVoiceCommands(_ text: String) -> String {
        var processedText = text
        
        for command in voiceCommands {
            if let regex = try? NSRegularExpression(pattern: command.pattern, options: .caseInsensitive) {
                let range = NSRange(processedText.startIndex..., in: processedText)
                processedText = regex.stringByReplacingMatches(
                    in: processedText,
                    options: [],
                    range: range,
                    withTemplate: command.replacement
                )
            }
        }
        
        return processedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Convenience Initializers

extension WhisperTranscriber {
    /// Create transcriber with default settings
    convenience init() {
        self.init(modelManager: nil, voiceCommands: nil)
    }
    
    /// Create transcriber with specific model
    convenience init(modelType: WhisperModelType) {
        self.init(modelManager: nil, voiceCommands: nil)
        Task {
            try? await loadModel(modelType)
        }
    }
}

// MARK: - Model Type Alias for compatibility

enum WhisperModelType: String, CaseIterable, Identifiable {
    case tiny = "whisper-tiny"
    case base = "whisper-base"
    case small = "whisper-small"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .tiny: return "Tiny"
        case .base: return "Base"
        case .small: return "Small"
        }
    }
    
    var estimatedSize: String {
        switch self {
        case .tiny: return "~39 MB"
        case .base: return "~75 MB"
        case .small: return "~244 MB"
        }
    }
    
    var recommendedUse: String {
        switch self {
        case .tiny: return "Fast, lower accuracy"
        case .base: return "Balanced speed/accuracy"
        case .small: return "Better accuracy, slower"
        }
    }
}