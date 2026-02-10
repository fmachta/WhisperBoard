import Foundation
import Combine
import UIKit
import AVFoundation
import WhisperKit

/// Background service running in the main app that monitors the App Group
/// shared container for new audio from the keyboard extension, transcribes
/// it with WhisperKit, and writes the result back for the keyboard to pick up.
///
/// Lifecycle:
///  1. `start()` – called at app launch; begins observing Darwin notifications.
///  2. Keyboard writes audio + request → posts Darwin notification.
///  3. Service reads request, loads model if needed, transcribes, writes result.
///  4. Posts Darwin notification back to keyboard.
///
/// The service also supports manual transcription from within the main app.

final class TranscriptionService: ObservableObject {

    // MARK: - Published State

    @Published private(set) var isRunning = false
    @Published private(set) var isTranscribing = false
    @Published private(set) var isModelLoaded = false
    @Published private(set) var lastTranscription: String = ""
    @Published private(set) var statusMessage: String = "Service stopped"
    @Published private(set) var modelLoadProgress: Double = 0

    // MARK: - Properties

    private var whisperKit: WhisperKit?
    private let queue = DispatchQueue(label: "com.whisperboard.transcription", qos: .userInitiated)
    private var cancellables = Set<AnyCancellable>()
    private var audioCapture: AudioCapture?
    private var currentRecordingURL: URL?

    // MARK: - Singleton

    static let shared = TranscriptionService()
    private init() {}

    // MARK: - Service Lifecycle

    func start() {
        guard !isRunning else { return }
        isRunning = true
        statusMessage = "Listening for keyboard requests…"

        // Observe Darwin notification from keyboard (legacy - audio already recorded)
        DarwinNotificationCenter.shared.observe(SharedDefaults.newAudioNotificationName) { [weak self] in
            self?.handleNewAudioRequest()
        }
        
        // Observe request to start recording (new - keyboard asks main app to record)
        DarwinNotificationCenter.shared.observe("com.fmachta.whisperboard.startRecording") { [weak self] in
            self?.handleStartRecordingRequest()
        }

        // Mark service as running in shared defaults
        SharedDefaults.sharedDefaults?.set(true, forKey: SharedDefaults.serviceRunningKey)

        // Periodic cleanup of old audio files
        SharedDefaults.cleanupOldAudio()

        // Auto-load model if one was previously selected
        if let modelName = SharedDefaults.sharedDefaults?.string(forKey: SharedDefaults.selectedModelKey) {
            Task { try? await loadModel(named: modelName) }
        }

        print("[TranscriptionService] Started")
    }

    func stop() {
        isRunning = false
        statusMessage = "Service stopped"
        DarwinNotificationCenter.shared.removeObserver(SharedDefaults.newAudioNotificationName)
        SharedDefaults.sharedDefaults?.set(false, forKey: SharedDefaults.serviceRunningKey)
        print("[TranscriptionService] Stopped")
    }

    // MARK: - Model Management

    /// Load a WhisperKit model by name (e.g. "tiny", "base", "small")
    /// or full model ID (e.g. "openai_whisper-base").
    func loadModel(named modelName: String) async throws {
        // Resolve short names ("base") to full model IDs ("openai_whisper-base")
        let resolvedModelId: String
        if let modelType = WhisperModelType(rawValue: modelName) {
            resolvedModelId = modelType.modelId
        } else {
            resolvedModelId = modelName  // Already a full ID or custom
        }

        await MainActor.run {
            statusMessage = "Loading model \(modelName)…"
            modelLoadProgress = 0
        }

        do {
            let config = WhisperKitConfig(model: resolvedModelId)
            let kit = try await WhisperKit(config)
            whisperKit = kit

            await MainActor.run {
                isModelLoaded = true
                modelLoadProgress = 1.0
                statusMessage = "Model loaded: \(modelName)"
            }
            print("[TranscriptionService] Model loaded: \(resolvedModelId)")
        } catch {
            await MainActor.run {
                isModelLoaded = false
                modelLoadProgress = 0
                statusMessage = "Failed to load model: \(error.localizedDescription)"
            }
            throw error
        }
    }

    func unloadModel() {
        whisperKit = nil
        isModelLoaded = false
        statusMessage = "Model unloaded"
    }

    // MARK: - Recording (triggered by keyboard)
    
    private func handleStartRecordingRequest() {
        print("[TranscriptionService] Received start recording request from keyboard")
        
        Task {
            await MainActor.run {
                statusMessage = "Recording from keyboard..."
            }
            
            // Check microphone permission
            guard await checkMicrophonePermission() else {
                writeRecordingFailure(error: "Microphone permission denied")
                return
            }
            
            // Generate unique filename
            let timestamp = Int(Date().timeIntervalSince1970)
            guard let audioURL = SharedDefaults.containerURL?.appendingPathComponent("kb_\(timestamp).wav") else {
                writeRecordingFailure(error: "Cannot create audio file")
                return
            }
            
            // Start recording
            audioCapture = AudioCapture()
            currentRecordingURL = audioURL
            
            do {
                try audioCapture?.startRecording(to: audioURL)
                
                // Set up callback for when recording finishes
                audioCapture?.onRecordingFinished = { [weak self] url in
                    Task {
                        await self?.processRecordedAudio(url)
                    }
                }
                
                // Auto-stop after 60 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
                    self?.stopRecording()
                }
                
            } catch {
                writeRecordingFailure(error: "Failed to start recording: \(error.localizedDescription)")
            }
        }
    }
    
    func stopRecording() {
        audioCapture?.stopRecording()
        audioCapture = nil
    }
    
    private func processRecordedAudio(_ url: URL) async {
        guard let request = createTranscriptionRequest(for: url) else {
            writeRecordingFailure(error: "Failed to create request")
            return
        }
        
        // Save request and transcribe
        SharedDefaults.writeRequest(request)
        await transcribeRequest(request)
    }
    
    private func createTranscriptionRequest(for url: URL) -> SharedDefaults.TranscriptionRequest? {
        return SharedDefaults.TranscriptionRequest(
            audioFileName: url.lastPathComponent,
            language: SharedDefaults.sharedDefaults?.string(forKey: SharedDefaults.selectedLanguageKey) ?? "en",
            sampleRate: 16000.0,
            timestamp: Date().timeIntervalSince1970
        )
    }
    
    private func writeRecordingFailure(error: String) {
        let result = SharedDefaults.TranscriptionResult(
            text: "",
            status: .failed,
            requestTimestamp: Date().timeIntervalSince1970,
            completedTimestamp: Date().timeIntervalSince1970,
            error: error
        )
        SharedDefaults.writeResult(result)
        DarwinNotificationCenter.shared.post(SharedDefaults.transcriptionDoneNotificationName)
        
        Task { @MainActor in
            statusMessage = "Recording error: \(error)"
        }
    }
    
    private func checkMicrophonePermission() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
    }

    // MARK: - Transcription (from keyboard request)

    private func handleNewAudioRequest() {
        guard let request = SharedDefaults.readRequest() else {
            print("[TranscriptionService] No valid request found")
            return
        }

        // Write "processing" status so keyboard can show spinner
        let processingResult = SharedDefaults.TranscriptionResult(
            text: "",
            status: .processing,
            requestTimestamp: request.timestamp,
            completedTimestamp: Date().timeIntervalSince1970,
            error: nil
        )
        SharedDefaults.writeResult(processingResult)

        Task {
            await transcribeRequest(request)
        }
    }

    private func transcribeRequest(_ request: SharedDefaults.TranscriptionRequest) async {
        await MainActor.run { isTranscribing = true }

        // Load audio samples
        guard let samples = SharedDefaults.loadAudio(fileName: request.audioFileName) else {
            writeFailure(request: request, error: "Could not read audio file")
            return
        }

        guard !samples.isEmpty else {
            writeFailure(request: request, error: "Audio file was empty")
            return
        }

        // Ensure model is loaded
        if !isModelLoaded {
            let modelName = SharedDefaults.sharedDefaults?.string(forKey: SharedDefaults.selectedModelKey) ?? "base"
            do {
                try await loadModel(named: modelName)
            } catch {
                writeFailure(request: request, error: "Failed to load model: \(error.localizedDescription)")
                return
            }
        }

        // Transcribe
        do {
            let text = try await transcribe(samples: samples, language: request.language)

            let result = SharedDefaults.TranscriptionResult(
                text: text,
                status: .completed,
                requestTimestamp: request.timestamp,
                completedTimestamp: Date().timeIntervalSince1970,
                error: nil
            )
            SharedDefaults.writeResult(result)
            SharedDefaults.clearRequest()

            // Notify keyboard
            DarwinNotificationCenter.shared.post(SharedDefaults.transcriptionDoneNotificationName)

            await MainActor.run {
                isTranscribing = false
                lastTranscription = text
                statusMessage = "Transcribed: \(text.prefix(60))…"
            }

            print("[TranscriptionService] Transcription complete: \(text.prefix(80))")

        } catch {
            writeFailure(request: request, error: error.localizedDescription)
        }
    }

    private func writeFailure(request: SharedDefaults.TranscriptionRequest, error: String) {
        let result = SharedDefaults.TranscriptionResult(
            text: "",
            status: .failed,
            requestTimestamp: request.timestamp,
            completedTimestamp: Date().timeIntervalSince1970,
            error: error
        )
        SharedDefaults.writeResult(result)
        DarwinNotificationCenter.shared.post(SharedDefaults.transcriptionDoneNotificationName)

        Task { @MainActor in
            isTranscribing = false
            statusMessage = "Error: \(error)"
        }
        print("[TranscriptionService] Transcription failed: \(error)")
    }

    // MARK: - Core Transcription

    /// Transcribe raw Float32 audio samples using WhisperKit.
    func transcribe(samples: [Float], language: String = "auto") async throws -> String {
        guard let kit = whisperKit else {
            throw TranscriptionError.modelNotLoaded
        }

        // WhisperKit's transcribe expects [Float] at 16 kHz mono
        let options = DecodingOptions(
            language: language == "auto" ? nil : language,
            temperature: 0.0,
            temperatureFallbackCount: 3,
            sampleLength: 224,
            usePrefillPrompt: true,
            usePrefillCache: true,
            skipSpecialTokens: true,
            withoutTimestamps: true
        )

        let segments = try await kit.transcribe(audioArray: samples, decodeOptions: options)

        // Combine all segment texts (WhisperKit returns [TranscriptionResult])
        let text = segments.map { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)

        // Apply voice command processing
        return applyVoiceCommands(text)
    }

    // MARK: - Voice Commands

    private static let voiceCommands: [(pattern: String, replacement: String)] = [
        (#"\bperiod\b\.?\s*$"#,            "."),
        (#"\bcomma\b,?\s*$"#,              ","),
        (#"\bquestion mark\b\??\s*$"#,     "?"),
        (#"\bexclamation mark\b!\s*$"#,     "!"),
        (#"\bnew line\b\s*$"#,             "\n"),
        (#"\bnew paragraph\b\s*$"#,         "\n\n"),
    ]

    private func applyVoiceCommands(_ text: String) -> String {
        var result = text
        for (pattern, replacement) in Self.voiceCommands {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: replacement)
            }
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Errors

    enum TranscriptionError: LocalizedError {
        case modelNotLoaded
        case audioEmpty
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .modelNotLoaded: return "No Whisper model loaded"
            case .audioEmpty:     return "Audio buffer is empty"
            case .failed(let m):  return m
            }
        }
    }
}
