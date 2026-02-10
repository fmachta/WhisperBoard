import SwiftUI

struct ContentView: View {
    @StateObject private var service = TranscriptionService.shared
    @StateObject private var modelManager = ModelManager()
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // ── Header ──
                    header

                    // ── Transcription Service Card ──
                    serviceCard

                    // ── Setup Instructions ──
                    setupCard

                    // ── Model Status ──
                    modelCard

                    // ── Features ──
                    featuresCard

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("WhisperBoard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    // ──────────────────────────────────────────────

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("WhisperBoard")
                .font(.largeTitle).fontWeight(.bold)
            Text("On-device speech-to-text keyboard powered by Whisper")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.top, 12)
    }

    // ── Service Status ──

    private var serviceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Transcription Service", systemImage: "waveform.circle.fill")
                .font(.headline)

            HStack(spacing: 10) {
                Circle()
                    .fill(service.isRunning ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                Text(service.isRunning ? "Running" : "Stopped")
                    .font(.subheadline)
                    .foregroundStyle(service.isRunning ? .primary : .secondary)
                Spacer()
                Button(service.isRunning ? "Stop" : "Start") {
                    service.isRunning ? service.stop() : service.start()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if service.isModelLoaded {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                    Text("Model loaded – ready to transcribe")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if service.modelLoadProgress > 0 && service.modelLoadProgress < 1 {
                ProgressView(value: service.modelLoadProgress)
                    .progressViewStyle(.linear)
            }

            if service.isTranscribing {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Transcribing…").font(.caption).foregroundStyle(.secondary)
                }
            }

            if !service.lastTranscription.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last transcription:")
                        .font(.caption2).foregroundStyle(.tertiary)
                    Text(service.lastTranscription)
                        .font(.callout)
                        .lineLimit(3)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.tertiarySystemFill))
                        .cornerRadius(8)
                }
            }

            Text(service.statusMessage)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .cardStyle()
    }

    // ── Setup ──

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Keyboard Setup", systemImage: "keyboard")
                .font(.headline)

            SetupStep(n: 1, title: "Open Settings",   detail: "Settings → General → Keyboard → Keyboards")
            SetupStep(n: 2, title: "Add Keyboard",    detail: "Tap \"Add New Keyboard…\" → select WhisperBoard")
            SetupStep(n: 3, title: "Allow Full Access", detail: "Enable Full Access for microphone permissions")
            SetupStep(n: 4, title: "Start Dictating",  detail: "Switch to WhisperBoard and tap the mic button")

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Open Settings", systemImage: "gear")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .cardStyle()
    }

    // ── Models ──

    private var modelCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Whisper Model", systemImage: "cpu")
                .font(.headline)

            HStack(spacing: 12) {
                ForEach(WhisperModelType.allCases) { model in
                    ModelBadge(model: model,
                               isDownloaded: modelManager.downloadedModels.contains(model),
                               isSelected: modelManager.selectedModel == model)
                    .onTapGesture { selectModel(model) }
                }
            }

            HStack {
                Text("Storage:").font(.caption).foregroundStyle(.secondary)
                Text(modelManager.getFormattedStorageUsed()).font(.caption).fontWeight(.medium)
            }
        }
        .cardStyle()
    }

    // ── Features ──

    private var featuresCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Features", systemImage: "star.fill")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                FeatureChip(icon: "mic.fill",          title: "Voice Input",      color: .red)
                FeatureChip(icon: "bolt.fill",         title: "Fast Processing",  color: .yellow)
                FeatureChip(icon: "lock.shield.fill",  title: "Private & Offline", color: .green)
                FeatureChip(icon: "iphone",            title: "On-Device AI",     color: .blue)
            }
        }
        .cardStyle()
    }

    // ── Helpers ──

    private func selectModel(_ model: WhisperModelType) {
        if modelManager.isModelDownloaded(model) {
            modelManager.saveSelectedModel(model)
        } else {
            Task {
                do {
                    try await modelManager.downloadModel(model)
                    modelManager.saveSelectedModel(model)
                } catch {
                    print("[ContentView] Download failed: \(error)")
                }
            }
        }
    }
}

// MARK: - Subviews

private struct SetupStep: View {
    let n: Int; let title: String; let detail: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)")
                .font(.caption).fontWeight(.bold).foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.accentColor))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).fontWeight(.semibold)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct ModelBadge: View {
    let model: WhisperModelType; let isDownloaded: Bool; let isSelected: Bool
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : isDownloaded ? "checkmark.circle" : "arrow.down.circle")
                .font(.title3)
                .foregroundStyle(isSelected ? .blue : isDownloaded ? .green : .gray)
            Text(model.displayName).font(.caption2).fontWeight(.medium)
            Text(model.estimatedSize).font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8).padding(.horizontal, 10)
        .background(isSelected ? Color.blue.opacity(0.12) : Color.clear)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? Color.blue : .clear, lineWidth: 1))
    }
}

private struct FeatureChip: View {
    let icon: String; let title: String; let color: Color
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
            Text(title).font(.caption).fontWeight(.medium)
        }
        .frame(maxWidth: .infinity).padding(12)
        .background(Color(.tertiarySystemBackground)).cornerRadius(10)
    }
}

// MARK: - Card Modifier

extension View {
    func cardStyle() -> some View {
        self.padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(14)
    }
}

#Preview { ContentView() }
