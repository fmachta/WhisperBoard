import Foundation
import UIKit
import SwiftUI
import WhisperKit

// MARK: - WhisperTranscriber Stub (Inline for Keyboard Extension)

/// Minimal transcriber stub for keyboard extension use
/// Provides interface compatibility with main app's WhisperTranscriber
final class WhisperTranscriber: ObservableObject {
    
    struct TranscriptionResult {
        let text: String
        let timestamp: Date
        let confidence: Float?
        let isFinal: Bool
        let audioDuration: TimeInterval
    }
    
    // MARK: - Properties
    
    var isModelLoaded: Bool = false
    
    let transcriptionQueue = DispatchQueue(label: "com.whisperboard.transcription", qos: .userInitiated)
    
    // MARK: - Model Management
    
    func loadModel(_ model: Any) async throws {
        // Model loading stub
    }
    
    func transcribe(_ audioData: Data) async throws -> TranscriptionResult {
        // Transcription stub - returns empty result
        return TranscriptionResult(
            text: "",
            timestamp: Date(),
            confidence: nil,
            isFinal: true,
            audioDuration: 0
        )
    }
    
}

// MARK: - Transcription View (Inline for Keyboard Extension)

/// Live transcription overlay view showing real-time speech-to-text results
/// Designed for keyboard extension with minimal footprint
struct TranscriptionView: View {
    
    // MARK: - Properties
    
    @ObservedObject var transcriber: WhisperTranscriber
    @State private var transcriptionText: String = ""
    @State private var isProcessing = false
    
    // Configuration
    var maxHeight: CGFloat = 120
    var onInsertText: ((String) -> Void)?
    var onDismiss: (() -> Void)?
    
    // MARK: - UI State
    
    @State private var displayText: String = ""
    @State private var showingResults = false
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header with status
            HStack {
                Circle()
                    .fill(isProcessing ? Color.orange : Color.green)
                    .frame(width: 8, height: 8)
                
                Text(isProcessing ? "Processing..." : "Ready")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: { onDismiss?() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
            
            // Transcription text area
            Text(displayText.isEmpty ? "Tap mic to start speaking" : displayText)
                .font(.body)
                .foregroundColor(displayText.isEmpty ? .secondary : .primary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            
            // Insert button
            if !displayText.isEmpty {
                HStack {
                    Spacer()
                    Button(action: { onInsertText?(displayText) }) {
                        Label("Insert", systemImage: "arrow.right.circle.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        .frame(maxHeight: maxHeight)
        .onChange(of: transcriber.currentTranscription) { newValue in
            displayText = newValue
            showingResults = !newValue.isEmpty
        }
        .onChange(of: transcriber.isProcessing) { processing in
            isProcessing = processing
        }
    }
}

// MARK: - WhisperTranscriber Extension for Keyboard

extension WhisperTranscriber {
    
    /// Current transcription text for UI binding
    var currentTranscription: String {
        lastResult?.text ?? ""
    }
    
    /// Whether transcription is currently processing
    var isProcessing: Bool {
        // Check current state
        return false
    }
    
    /// Last transcription result
    var lastResult: TranscriptionResult? {
        return nil
    }
}

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