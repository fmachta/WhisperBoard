import Foundation
import UIKit
import SwiftUI

/// Integration helpers for wiring WhisperKit to KeyboardViewController
/// Handles text insertion, UI updates, and keyboard-specific adaptations
struct WhisperKitIntegration {
    
    // MARK: - Text Insertion
    
    /// Insert transcribed text into the host app
    /// - Parameters:
    ///   - text: Text to insert
    ///   - proxy: Text document proxy from keyboard view controller
    ///   - completion: Callback when insertion is complete
    static func insertTranscribedText(_ text: String, into proxy: UITextDocumentProxy, completion: (() -> Void)? = nil) {
        // Process any voice commands that may have been detected
        let processedText = processVoiceCommands(text)
        
        // Insert text at cursor position
        proxy.insertText(processedText)
        
        // Provide haptic feedback
        provideTextInsertionFeedback()
        
        completion?()
    }
    
    /// Process voice commands in transcribed text
    private static func processVoiceCommands(_ text: String) -> String {
        var processedText = text
        
        // Common voice command patterns
        let voiceCommands: [(pattern: String, replacement: String)] = [
            (pattern: #"\bperiod\b\.?\s*$"#, replacement: "."),
            (pattern: #"\bcomma\b,?\s*$"#, replacement: ","),
            (pattern: #"\bquestion mark\b\??\s*$"#, replacement: "?"),
            (pattern: #"\bexclamation mark\b!\s*$"#, replacement: "!"),
            (pattern: #"\bnew line\b\s*$"#, replacement: "\n"),
            (pattern: #"\bnew paragraph\b\s*$"#, replacement: "\n\n"),
            (pattern: #"\bdelete last word\b\s*$"#, replacement: "←"),
            (pattern: #"\bbackspace\b\s*$"#, replacement: "←"),
        ]
        
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
    
    // MARK: - Haptic Feedback
    
    /// Provide haptic feedback for text insertion
    static func provideTextInsertionFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    /// Provide haptic feedback for recording start
    static func provideRecordingStartFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    /// Provide haptic feedback for recording stop
    static func provideRecordingStopFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    /// Provide error feedback
    static func provideErrorFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
    
    // MARK: - UI Overlay Hosting
    
    /// Create a SwiftUI hosting controller for transcription overlay
    static func createTranscriptionOverlay(
        transcriber: WhisperTranscriber,
        onInsert: @escaping (String) -> Void,
        onDismiss: @escaping () -> Void
    ) -> UIHostingController<TranscriptionView> {
        let view = TranscriptionView(
            transcriber: transcriber,
            onInsertText: onInsert,
            onDismiss: onDismiss
        )
        
        let hostingController = UIHostingController(rootView: view)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        
        return hostingController
    }
    
    // MARK: - Audio Pipeline Integration
    
    /// Connect AudioCapture to WhisperTranscriber for streaming transcription
    static func connectAudioCapture(
        _ audioCapture: AudioCapture,
        to transcriber: WhisperTranscriber,
        onResult: @escaping (WhisperTranscriber.TranscriptionResult) -> Void
    ) {
        // Set up audio buffer callback
        audioCapture.onAudioBufferAvailable = { [weak transcriber] audioData in
            guard let transcriber = transcriber, transcriber.isModelLoaded else { return }
            
            // Process in background
            transcriber.transcriptionQueue.async {
                // Accumulate audio for chunk-based transcription
            }
        }
    }
}

// MARK: - Keyboard-Specific Extensions

extension WhisperTranscriber {
    
    /// Create a transcriber optimized for keyboard extension use
    static func forKeyboard() -> WhisperTranscriber {
        let manager = ModelManager()
        let transcriber = WhisperTranscriber(modelManager: manager)
        
        // Pre-load base model for keyboard
        Task {
            try? await transcriber.loadModel(.base)
        }
        
        return transcriber
    }
}

// MARK: - UI State Management

enum KeyboardTranscriptionState {
    case idle
    case recording
    case processing
    case ready(String)
    case error(String)
    
    var displayText: String {
        switch self {
        case .idle:
            return "Tap to speak"
        case .recording:
            return "Listening..."
        case .processing:
            return "Processing..."
        case .ready(let text):
            return text
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    var iconName: String {
        switch self {
        case .idle:
            return "mic"
        case .recording:
            return "waveform"
        case .processing:
            return "arrow.triangle.2.circlepath"
        case .ready:
            return "checkmark.circle"
        case .error:
            return "exclamationmark.triangle"
        }
    }
}