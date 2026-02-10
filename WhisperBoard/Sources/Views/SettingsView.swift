import SwiftUI

/// Settings view for model management, language selection, and app configuration
struct SettingsView: View {
    
    // MARK: - Properties
    
    @StateObject private var modelManager = ModelManager()
    @StateObject private var transcriber: WhisperTranscriber
    
    @State private var selectedLanguage: String = "Auto-detect"
    @State private var showDeleteConfirmation = false
    @State private var modelToDelete: WhisperModelType?
    @State private var showDownloadProgress = false
    
    // Navigation
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Sections
    
    private let sections: [SettingsSection] = [
        .models,
        .language,
        .about,
        .storage
    ]
    
    // MARK: - Initialization
    
    init(transcriber: WhisperTranscriber = WhisperTranscriber()) {
        _transcriber = StateObject(wrappedValue: transcriber)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            List {
                // Model Selection Section
                modelSection
                
                // Language Section
                languageSection
                
                // Storage Section
                storageSection
                
                // About Section
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "Delete Model",
                isPresented: $showDeleteConfirmation,
                presenting: modelToDelete
            ) { model in
                Button("Delete \(model.displayName)", role: .destructive) {
                    deleteModel(model)
                }
            } message: { model in
                Text("This will remove \(model.estimatedSize) of model files from your device.")
            }
        }
    }
    
    // MARK: - Model Section
    
    private var modelSection: some View {
        Section {
            ForEach(WhisperModelType.allCases) { model in
                ModelRow(
                    model: model,
                    modelManager: modelManager,
                    isSelected: modelManager.selectedModel == model,
                    isDownloading: modelManager.currentDownloadTask == model.rawValue,
                    downloadProgress: modelManager.downloadProgress
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    selectModel(model)
                }
            }
        } header: {
            Text("Whisper Model")
        } footer: {
            Text("Larger models are more accurate but use more storage and battery.")
        }
    }
    
    // MARK: - Language Section
    
    private var languageSection: some View {
        Section {
            Picker("Language", selection: $selectedLanguage) {
                Text("Auto-detect").tag("Auto-detect")
                Divider()
                Text("English").tag("English")
                Text("Spanish").tag("Spanish")
                Text("French").tag("French")
                Text("German").tag("German")
                Text("Chinese").tag("Chinese")
                Text("Japanese").tag("Japanese")
                Text("Korean").tag("Korean")
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } header: {
            Text("Language")
        } footer: {
            Text("Auto-detect automatically identifies the spoken language.")
        }
    }
    
    // MARK: - Storage Section
    
    private var storageSection: some View {
        Section {
            HStack {
                Label("Storage Used", systemImage: "internaldrive")
                Spacer()
                Text(modelManager.getFormattedStorageUsed())
                    .foregroundStyle(.secondary)
            }
            
            HStack {
                Label("Available Space", systemImage: "externaldrive")
                Spacer()
                Text(formattedAvailableSpace)
                    .foregroundStyle(.secondary)
            }
            
            Button {
                clearAllModels()
            } label: {
                Label("Clear All Models", systemImage: "trash")
                    .foregroundStyle(.red)
            }
            .disabled(modelManager.downloadedModels.isEmpty)
        } header: {
            Text("Storage")
        }
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        Section {
            HStack {
                Label("Version", systemImage: "info.circle")
                Spacer()
                Text("1.0.0")
                    .foregroundStyle(.secondary)
            }
            
            Link(destination: URL(string: "https://github.com/fmachta/WhisperBoard")!) {
                Label("GitHub Repository", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            
            Link(destination: URL(string: "https://github.com/fmachta/WhisperBoard/issues")!) {
                Label("Report an Issue", systemImage: "exclamationmark.triangle")
            }
            
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Voice Commands:")
                        .font(.headline)
                    
                    VoiceCommandRow(command: "period", result: ".")
                    VoiceCommandRow(command: "comma", result: ",")
                    VoiceCommandRow(command: "question mark", result: "?")
                    VoiceCommandRow(command: "exclamation mark", result: "!")
                    VoiceCommandRow(command: "new line", result: "↵")
                    VoiceCommandRow(command: "delete last word", result: "⌫")
                }
                .padding(.vertical, 8)
            } label: {
                Label("Voice Commands", systemImage: "mic.badge.plus")
            }
        } header: {
            Text("About")
        }
    }
    
    // MARK: - Helper Properties
    
    private var formattedAvailableSpace: String {
        let bytes = modelManager.getAvailableDiskSpace()
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
    
    // MARK: - Actions
    
    private func selectModel(_ model: WhisperModelType) {
        // Check if model is downloaded
        Task {
            let isDownloaded = try await modelManager.isModelDownloaded(model)
            
            await MainActor.run {
                if isDownloaded {
                    modelManager.selectedModel = model
                    modelManager.saveSelectedModel(model)
                } else {
                    // Download model
                    downloadModel(model)
                }
            }
        }
    }
    
    private func downloadModel(_ model: WhisperModelType) {
        Task {
            do {
                try await modelManager.downloadModel(model) { progress in
                    Task { @MainActor in
                        // Update UI progress
                    }
                }
                
                modelManager.selectedModel = model
                modelManager.saveSelectedModel(model)
            } catch {
                print("Failed to download model: \(error)")
            }
        }
    }
    
    private func deleteModel(_ model: WhisperModelType) {
        do {
            try modelManager.deleteModel(model)
            
            if modelManager.selectedModel == model {
                modelManager.selectedModel = .base
            }
        } catch {
            print("Failed to delete model: \(error)")
        }
    }
    
    private func clearAllModels() {
        do {
            try modelManager.clearAllModels()
        } catch {
            print("Failed to clear models: \(error)")
        }
    }
}

// MARK: - Supporting Views

struct ModelRow: View {
    let model: WhisperModelType
    @ObservedObject var modelManager: ModelManager
    let isSelected: Bool
    let isDownloading: Bool
    let downloadProgress: Double
    
    var body: some View {
        HStack {
            // Model selection indicator
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(model.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(model.estimatedSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Status
            if isDownloading {
                ProgressView(value: downloadProgress)
                    .progressViewStyle(.linear)
                    .frame(width: 60)
            } else if modelManager.downloadedModels.contains(model) {
                Image(systemName: "arrow.down.circle")
                    .foregroundStyle(.green)
            } else {
                Image(systemName: "icloud.and.arrow.down")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

struct VoiceCommandRow: View {
    let command: String
    let result: String
    
    var body: some View {
        HStack {
            Text("\"\(command)\"")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
            
            Image(systemName: "arrow.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
            
            Text("\"\(result)\"")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Section Type

enum SettingsSection: String, CaseIterable {
    case models = "Models"
    case language = "Language"
    case storage = "Storage"
    case about = "About"
}

// MARK: - Preview

#Preview {
    SettingsView(transcriber: WhisperTranscriber())
}