import UIKit
import SwiftUI
import Combine

// MARK: - WhisperKit Extension for KeyboardViewController
extension KeyboardViewController {
    
    // MARK: - Properties
    
    /// Whisper transcriber for speech-to-text
    private(set) var whisperTranscriber: WhisperTranscriber?
    
    /// Transcription overlay hosting controller
    private var transcriptionOverlay: UIHostingController<TranscriptionView>?
    
    /// UIView that hosts the transcription overlay
    private var transcriptionOverlayContainer: UIView?
    
    /// Combine cancellables
    private var cancellables = Set<AnyCancellable>()
    
    /// Current transcription state
    @Published private(set) var transcriptionState: KeyboardTranscriptionState = .idle
    
    /// Model loading progress
    @Published private(set) var modelLoadProgress: Double = 0
    
    /// Flag for model loading state
    private var isModelLoading = false
    
    // MARK: - Setup Methods
    
    /// Setup WhisperKit integration
    func setupWhisperKit() {
        print("[KeyboardViewController] Setting up WhisperKit...")
        
        // Initialize transcriber
        whisperTranscriber = WhisperTranscriber()
        
        // Setup callbacks
        setupTranscriberCallbacks()
        
        // Pre-load model
        preloadModel()
        
        print("[KeyboardViewController] WhisperKit setup complete")
    }
    
    /// Pre-load Whisper model to reduce latency
    private func preloadModel() {
        guard let transcriber = whisperTranscriber, !isModelLoading else { return }
        
        isModelLoading = true
        Task { @MainActor in
            modelLoadProgress = 0.1
        }
        
        Task {
            do {
                try await transcriber.loadModel()
                
                await MainActor.run {
                    isModelLoading = false
                    modelLoadProgress = 1.0
                    print("[KeyboardViewController] Model pre-loaded successfully")
                }
            } catch {
                await MainActor.run {
                    isModelLoading = false
                    transcriptionState = .error("Model load failed: \(error.localizedDescription)")
                    print("[KeyboardViewController] Model pre-load failed: \(error)")
                }
            }
        }
    }
    
    /// Setup transcriber callbacks
    private func setupTranscriberCallbacks() {
        guard let transcriber = whisperTranscriber else { return }
        
        // Listen for transcription results
        transcriber.onTranscriptionResult = { [weak self] result in
            Task { @MainActor in
                self?.transcriptionState = .ready(result.text)
                self?.handleTranscriptionResult(result)
            }
        }
        
        // Listen for partial results
        transcriber.onPartialTranscription = { [weak self] partialText in
            Task { @MainActor in
                self?.transcriptionState = .processing
            }
        }
        
        // Listen for errors
        transcriber.onError = { [weak self] error in
            Task { @MainActor in
                self?.transcriptionState = .error(error.localizedDescription)
                self?.showError(error.localizedDescription)
            }
        }
        
        // Listen for model loaded
        transcriber.onModelLoaded = { [weak self] in
            Task { @MainActor in
                self?.print("[KeyboardViewController] Model loaded notification received")
            }
        }
    }
    
    // MARK: - Transcription Methods
    
    /// Start transcription with current audio buffer
    func startTranscription() async throws {
        guard let transcriber = whisperTranscriber else {
            throw TranscriptionError.transcriberNotInitialized
        }
        
        // Wait for model to load
        if !transcriber.isModelLoaded && !isModelLoading {
            try await transcriber.loadModel()
        }
        
        await MainActor.run {
            transcriptionState = .processing
        }
        
        // Get audio data from capture
        guard let audioData = audioCapture?.getAudioData() else {
            throw TranscriptionError.noAudioData
        }
        
        // Transcribe
        let result = try await transcriber.transcribe(audioData)
        
        await MainActor.run {
            handleTranscriptionResult(result)
        }
    }
    
    /// Handle transcription result
    private func handleTranscriptionResult(_ result: WhisperTranscriber.TranscriptionResult) {
        // Show transcription overlay
        showTranscriptionOverlay(with: result.text)
        
        // Provide feedback
        WhisperKitIntegration.provideTextInsertionFeedback()
        
        // Auto-insert after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.insertTranscribedTextAndDismiss(result.text)
        }
    }
    
    /// Insert transcribed text and dismiss overlay
    private func insertTranscribedTextAndDismiss(_ text: String) {
        // Process voice commands
        let processedText = processVoiceCommands(text)
        
        // Insert text
        textDocumentProxy.insertText(processedText)
        
        // Dismiss overlay
        hideTranscriptionOverlay()
        
        // Reset state
        transcriptionState = .idle
    }
    
    /// Process voice commands in text
    private func processVoiceCommands(_ text: String) -> String {
        return WhisperKitIntegration.processVoiceCommands(text)
    }
    
    // MARK: - Transcription Overlay UI
    
    /// Show transcription overlay
    private func showTranscriptionOverlay(with text: String) {
        guard let transcriber = whisperTranscriber else { return }
        
        // Create container view if needed
        if transcriptionOverlayContainer == nil {
            let container = UIView()
            container.backgroundColor = .clear
            container.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(container)
            
            NSLayoutConstraint.activate([
                container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
                container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
                container.bottomAnchor.constraint(equalTo: keyboardView.topAnchor, constant: -8),
                container.heightAnchor.constraint(lessThanOrEqualToConstant: 130)
            ])
            
            transcriptionOverlayContainer = container
        }
        
        // Create hosting controller if needed
        if transcriptionOverlay == nil {
            let overlayView = TranscriptionView(
                transcriber: transcriber,
                onInsertText: { [weak self] text in
                    self?.textDocumentProxy.insertText(text)
                    self?.hideTranscriptionOverlay()
                    self?.transcriptionState = .idle
                },
                onDismiss: { [weak self] in
                    self?.hideTranscriptionOverlay()
                    self?.transcriptionState = .idle
                }
            )
            
            let hostingController = UIHostingController(rootView: overlayView)
            hostingController.view.backgroundColor = .clear
            hostingController.view.translatesAutoresizingMaskIntoConstraints = false
            
            container.addSubview(hostingController.view)
            
            NSLayoutConstraint.activate([
                hostingController.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                hostingController.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                hostingController.view.topAnchor.constraint(equalTo: container.topAnchor),
                hostingController.view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])
            
            transcriptionOverlay = hostingController
        }
        
        // Show with animation
        transcriptionOverlayContainer?.alpha = 0
        transcriptionOverlayContainer?.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        
        UIView.animate(withDuration: 0.2) {
            self.transcriptionOverlayContainer?.alpha = 1
            self.transcriptionOverlayContainer?.transform = .identity
        }
    }
    
    /// Hide transcription overlay
    private func hideTranscriptionOverlay() {
        guard let container = transcriptionOverlayContainer else { return }
        
        UIView.animate(withDuration: 0.2, animations: {
            container.alpha = 0
            container.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            self.transcriptionOverlay?.rootView = EmptyView()
            self.transcriptionOverlay = nil
            container.removeFromSuperview()
            self.transcriptionOverlayContainer = nil
        }
    }
    
    // MARK: - Updated Mic Button Handling
    
    /// Updated handleMicButton with WhisperKit integration
    @objc func handleMicButtonWhisperKit(_ sender: KeyboardButton) {
        micButton = sender
        
        if isRecording {
            stopRecordingWithTranscription()
        } else {
            startRecordingWithWhisperKit()
        }
    }
    
    /// Start recording and prepare for transcription
    private func startRecordingWithWhisperKit() {
        Task {
            do {
                // Check model status
                if let transcriber = whisperTranscriber {
                    if !transcriber.isModelLoaded && !isModelLoading {
                        transcriptionState = .processing
                        try await transcriber.loadModel()
                    }
                }
                
                // Start audio capture
                try await startRecording()
                
                // Provide feedback
                WhisperKitIntegration.provideRecordingStartFeedback()
                
                await MainActor.run {
                    transcriptionState = .recording
                }
                
            } catch {
                await MainActor.run {
                    transcriptionState = .error(error.localizedDescription)
                    showError("Failed to start recording: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Stop recording and process transcription
    private func stopRecordingWithTranscription() {
        stopRecording()
        
        // Provide feedback
        WhisperKitIntegration.provideRecordingStopFeedback()
        
        // Start transcription
        Task {
            do {
                try await startTranscription()
            } catch {
                await MainActor.run {
                    transcriptionState = .idle
                    showError("Transcription failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Memory Management
    
    /// Handle memory warning - release non-essential resources
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        whisperTranscriber?.unloadModel()
        hideTranscriptionOverlay()
        
        print("[KeyboardViewController] Memory warning - model unloaded")
    }
    
    // MARK: - Error Display
    
    /// Show error to user
    private func showError(_ message: String) {
        let label = UILabel()
        label.text = message
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = .white
        label.backgroundColor = UIColor.systemRed.withAlphaComponent(0.9)
        label.textAlignment = .center
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: keyboardView.topAnchor, constant: -10),
            label.widthAnchor.constraint(greaterThanOrEqualToConstant: 150),
            label.heightAnchor.constraint(equalToConstant: 36)
        ])
        
        label.alpha = 0
        UIView.animate(withDuration: 0.3) {
            label.alpha = 1
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            UIView.animate(withDuration: 0.3) {
                label.alpha = 0
            } completion: { _ in
                label.removeFromSuperview()
            }
        }
    }
}

// MARK: - Transcription Error

enum TranscriptionError: Error, LocalizedError {
    case transcriberNotInitialized
    case noAudioData
    case transcriptionFailed(String)
    case modelNotLoaded
    
    var errorDescription: String? {
        switch self {
        case .transcriberNotInitialized:
            return "Transcriber not initialized"
        case .noAudioData:
            return "No audio data available"
        case .transcriptionFailed(let msg):
            return "Transcription failed: \(msg)"
        case .modelNotLoaded:
            return "Model not loaded"
        }
    }
}

// MARK: - Empty View for overlay cleanup

struct EmptyView: View {
    var body: some View {
        Color.clear
    }
}