import SwiftUI

/// Live transcription overlay view showing real-time speech-to-text results
/// Designed for keyboard extension with minimal footprint
struct TranscriptionView: View {
    
    // MARK: - Properties
    
    @ObservedObject var transcriber: WhisperTranscriber
    @State private var transcriptionText: String = ""
    @State private var isProcessing = false
    @State private var showConfidence = false
    @State private var opacity: Double = 1.0
    
    // Configuration
    var maxHeight: CGFloat = 120
    var onInsertText: ((String) -> Void)?
    var onDismiss: (() -> Void)?
    
    // MARK: - UI State
    
    @State private var displayText: NSAttributedString?
    @State private var confidenceIndicator: ConfidenceLevel = .none
    @State private var showingResults = false
    
    // MARK: - Confidence Level
    
    enum ConfidenceLevel {
        case none
        case low
        case medium
        case high
        
        var color: Color {
            switch self {
            case .none: return .gray
            case .low: return .orange
            case .medium: return .yellow
            case .high: return .green
            }
        }
        
        var icon: String {
            switch self {
            case .none: return "waveform"
            case .low: return "waveform.path.ecg"
            case .medium: return "waveform"
            case .high: return "checkmark.circle.fill"
            }
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Top bar with status
            topBar
            
            // Transcription content
            transcriptionContent
            
            // Bottom action bar
            actionBar
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        )
        .frame(maxHeight: maxHeight)
        .opacity(opacity)
        .onChange(of: transcriber.lastResult?.text) { _, newValue in
            if let text = newValue {
                updateTranscription(text)
            }
        }
        .onChange(of: transcriber.isTranscribing) { _, isTranscribing in
            withAnimation(.easeInOut(duration: 0.2)) {
                isProcessing = isTranscribing
            }
        }
    }
    
    // MARK: - UI Components
    
    private var topBar: some View {
        HStack {
            // Status indicator
            statusIndicator
            
            Spacer()
            
            // Dismiss button
            dismissButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    private var statusIndicator: some View {
        HStack(spacing: 6) {
            if isProcessing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(0.8)
            } else {
                Circle()
                    .fill(confidenceIndicator.color)
                    .frame(width: 8, height: 8)
            }
            
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private var statusText: String {
        if isProcessing {
            return "Processing..."
        } else if !transcriptionText.isEmpty {
            return "Tap to insert"
        } else {
            return "Speak now"
        }
    }
    
    private var dismissButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.tertiary)
        }
    }
    
    private var transcriptionContent: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                HStack(alignment: .top, spacing: 8) {
                    // Transcription text
                    Text(displayText?.string ?? (transcriptionText.isEmpty ? "Tap microphone and speak..." : transcriptionText))
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                        .id("transcription")
                    
                    Spacer()
                    
                    // Confidence indicator
                    if showConfidence && confidenceIndicator != .none {
                        confidenceBadge
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
    }
    
    private var confidenceBadge: some View {
        VStack(spacing: 2) {
            Image(systemName: confidenceIndicator.icon)
                .font(.caption)
                .foregroundStyle(confidenceIndicator.color)
            
            Text("\(Int((transcriber.lastResult?.confidence ?? 0 * 100)))%")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    
    private var actionBar: some View {
        HStack(spacing: 12) {
            // Clear button
            Button {
                clearTranscription()
            } label: {
                Label("Clear", systemImage: "trash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .disabled(transcriptionText.isEmpty)
            
            Spacer()
            
            // Insert button
            Button {
                insertText()
            } label: {
                Label("Insert", systemImage: "return")
                    .font(.callout)
                    .fontWeight(.medium)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .disabled(transcriptionText.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    // MARK: - Private Methods
    
    private func updateTranscription(_ text: String) {
        withAnimation(.easeInOut(duration: 0.15)) {
            transcriptionText = text
            showingResults = !text.isEmpty
            
            // Update confidence based on transcription confidence
            if let confidence = transcriber.lastResult?.confidence {
                updateConfidenceIndicator(confidence)
            }
        }
    }
    
    private func updateConfidenceIndicator(_ confidence: Float?) {
        guard let confidence = confidence else {
            confidenceIndicator = .none
            return
        }
        
        // Convert Whisper's log probability to confidence level
        // Typically logprob of -0.5 to 0 means good confidence
        let normalizedConfidence = max(0, min(1, (confidence + 1) * 0.5))
        
        if normalizedConfidence > 0.8 {
            confidenceIndicator = .high
        } else if normalizedConfidence > 0.5 {
            confidenceIndicator = .medium
        } else {
            confidenceIndicator = .low
        }
    }
    
    private func insertText() {
        onInsertText?(transcriptionText)
        clearTranscription()
    }
    
    private func clearTranscription() {
        withAnimation(.easeInOut(duration: 0.2)) {
            transcriptionText = ""
            displayText = nil
            confidenceIndicator = .none
        }
    }
    
    private func dismiss() {
        withAnimation(.easeInOut(duration: 0.2)) {
            opacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss?()
        }
    }
}

// MARK: - Preview

#Preview {
    TranscriptionView(
        transcriber: WhisperTranscriber()
    )
    .padding()
    .background(Color(.systemBackground))
}