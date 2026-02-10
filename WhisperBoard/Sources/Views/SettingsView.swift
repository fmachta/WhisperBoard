import SwiftUI

/// Settings for model management, language selection, and app info.
struct SettingsView: View {

    @StateObject private var modelManager = ModelManager()
    @State private var selectedLanguage: String = "Auto-detect"
    @State private var showDeleteConfirmation = false
    @State private var modelToDelete: WhisperModelType?
    @Environment(\.dismiss) private var dismiss

    init() {
        // Load persisted language
        if let lang = SharedDefaults.sharedDefaults?.string(forKey: SharedDefaults.selectedLanguageKey) {
            _selectedLanguage = State(initialValue: lang)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                modelSection
                languageSection
                storageSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Delete Model", isPresented: $showDeleteConfirmation, presenting: modelToDelete) { model in
                Button("Delete \(model.displayName)", role: .destructive) { modelManager.deleteModel(model) }
            } message: { model in
                Text("Remove \(model.estimatedSize) of cached model data.")
            }
        }
    }

    // ── Model Section ──

    private var modelSection: some View {
        Section {
            ForEach(WhisperModelType.allCases) { model in
                ModelRow(model: model,
                         modelManager: modelManager,
                         isSelected: modelManager.selectedModel == model,
                         isDownloading: modelManager.currentDownloadTask == model.rawValue,
                         downloadProgress: modelManager.downloadProgress)
                .contentShape(Rectangle())
                .onTapGesture { selectModel(model) }
                .swipeActions(edge: .trailing) {
                    if modelManager.isModelDownloaded(model) {
                        Button(role: .destructive) {
                            modelToDelete = model
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        } header: {
            Text("Whisper Model")
        } footer: {
            Text("Larger models give better accuracy but use more storage.")
        }
    }

    // ── Language Section ──

    private var languageSection: some View {
        Section {
            Picker("Language", selection: $selectedLanguage) {
                Text("Auto-detect").tag("Auto-detect")
                Divider()
                ForEach(["English","Spanish","French","German","Chinese","Japanese","Korean","Arabic","Portuguese","Russian"], id: \.self) {
                    Text($0).tag($0)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
            .onChange(of: selectedLanguage) { _, lang in
                SharedDefaults.sharedDefaults?.set(lang, forKey: SharedDefaults.selectedLanguageKey)
            }
        } header: {
            Text("Language")
        } footer: {
            Text("Auto-detect identifies the spoken language automatically.")
        }
    }

    // ── Storage Section ──

    private var storageSection: some View {
        Section {
            HStack {
                Label("Models Cached", systemImage: "internaldrive")
                Spacer()
                Text(modelManager.getFormattedStorageUsed()).foregroundStyle(.secondary)
            }
            HStack {
                Label("Free Space", systemImage: "externaldrive")
                Spacer()
                Text(ByteCountFormatter.string(fromByteCount: modelManager.getAvailableDiskSpace(), countStyle: .file))
                    .foregroundStyle(.secondary)
            }
            Button(role: .destructive) { modelManager.clearAllModels() } label: {
                Label("Clear All Models", systemImage: "trash")
            }
            .disabled(modelManager.downloadedModels.isEmpty)
        } header: {
            Text("Storage")
        }
    }

    // ── About Section ──

    private var aboutSection: some View {
        Section {
            HStack {
                Label("Version", systemImage: "info.circle")
                Spacer()
                Text("1.0.0").foregroundStyle(.secondary)
            }
            if let url = URL(string: "https://github.com/fmachta/WhisperBoard") {
                Link(destination: url) {
                    Label("GitHub Repository", systemImage: "chevron.left.forwardslash.chevron.right")
                }
            }
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 8) {
                    VoiceCommandRow(command: "period", result: ".")
                    VoiceCommandRow(command: "comma", result: ",")
                    VoiceCommandRow(command: "question mark", result: "?")
                    VoiceCommandRow(command: "exclamation mark", result: "!")
                    VoiceCommandRow(command: "new line", result: "↵")
                    VoiceCommandRow(command: "new paragraph", result: "↵↵")
                }
                .padding(.vertical, 6)
            } label: {
                Label("Voice Commands", systemImage: "mic.badge.plus")
            }
        } header: {
            Text("About")
        }
    }

    // ── Actions ──

    private func selectModel(_ model: WhisperModelType) {
        if modelManager.isModelDownloaded(model) {
            modelManager.saveSelectedModel(model)
        } else {
            Task {
                do {
                    try await modelManager.downloadModel(model)
                    modelManager.saveSelectedModel(model)
                } catch {
                    print("[Settings] Download failed: \(error)")
                }
            }
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
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? .blue : .secondary)

            VStack(alignment: .leading, spacing: 3) {
                Text(model.displayName).fontWeight(.medium)
                Text("\(model.estimatedSize) · \(model.recommendedUse)")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            if isDownloading {
                ProgressView(value: downloadProgress).progressViewStyle(.linear).frame(width: 60)
            } else if modelManager.isModelDownloaded(model) {
                Image(systemName: "checkmark").foregroundStyle(.green).font(.caption)
            } else {
                Image(systemName: "icloud.and.arrow.down").foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct VoiceCommandRow: View {
    let command: String; let result: String
    var body: some View {
        HStack {
            Text("\"\(command)\"").font(.system(.callout, design: .monospaced)).foregroundStyle(.secondary)
            Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.tertiary)
            Text("\"\(result)\"").font(.system(.callout, design: .monospaced))
        }
    }
}

#Preview { SettingsView() }
