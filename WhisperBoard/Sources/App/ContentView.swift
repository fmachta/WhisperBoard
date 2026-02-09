import SwiftUI

struct ContentView: View {
    @State private var showSettings = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("WhisperBoard")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Button {
                                showSettings = true
                            } label: {
                                Image(systemName: "gearshape.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        Text("Speech-to-text keyboard powered by Whisper")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Setup Instructions Card
                    SetupInstructionsView()
                    
                    // Features Card
                    FeaturesView()
                    
                    // Model Status Card
                    ModelStatusCard()
                    
                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("WhisperBoard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(transcriber: WhisperTranscriber())
            }
        }
        .navigationViewStyle(.stack)
    }
}

struct SetupInstructionsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Keyboard Setup", systemImage: "keyboard")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                SetupStepView(number: 1, title: "Open Settings", description: "Go to Settings > General > Keyboard > Keyboards")
                SetupStepView(number: 2, title: "Add New Keyboard", description: "Tap \"Add New Keyboard...\" and select \"WhisperBoard\"")
                SetupStepView(number: 3, title: "Enable Full Access", description: "Tap WhisperBoard and enable \"Allow Full Access\" for microphone access")
                SetupStepView(number: 4, title: "Start Dictating", description: "Switch to WhisperBoard keyboard and tap the microphone button")
            }
            
            Button(action: openKeyboardSettings) {
                HStack {
                    Image(systemName: "gear")
                    Text("Open Keyboard Settings")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    func openKeyboardSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

struct SetupStepView: View {
    let number: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.blue))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct FeaturesView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Features", systemImage: "star.fill")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                FeatureCardView(icon: "mic.fill", title: "Voice Input", color: .red)
                FeatureCardView(icon: "bolt.fill", title: "Fast Processing", color: .yellow)
                FeatureCardView(icon: "lock.shield.fill", title: "Private & Offline", color: .green)
                FeatureCardView(icon: "iphone", title: "On-Device", color: .blue)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }
}

struct FeatureCardView: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(12)
    }
}

struct ModelStatusCard: View {
    @StateObject private var modelManager = ModelManager()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Model Status", systemImage: "cpu")
                .font(.headline)
            
            HStack(spacing: 16) {
                ForEach(WhisperModelType.allCases) { model in
                    ModelStatusBadge(
                        model: model,
                        isDownloaded: modelManager.downloadedModels.contains(model),
                        isSelected: modelManager.selectedModel == model
                    )
                }
            }
            
            HStack {
                Text("Storage Used:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(modelManager.getFormattedStorageUsed())
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            Button {
                if let url = URL(string: "UIApplication.openSettingsURLString") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Enable Keyboard")
                    .font(.callout)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }
}

struct ModelStatusBadge: View {
    let model: WhisperModelType
    let isDownloaded: Bool
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: statusIcon)
                .font(.title3)
                .foregroundColor(iconColor)
            
            Text(model.displayName)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isSelected ? Color.blue.opacity(0.2) : Color.clear)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1)
        )
    }
    
    private var statusIcon: String {
        if isSelected {
            return "checkmark.circle.fill"
        } else if isDownloaded {
            return "checkmark.circle"
        } else {
            return "arrow.down.circle"
        }
    }
    
    private var iconColor: Color {
        if isSelected {
            return .blue
        } else if isDownloaded {
            return .green
        } else {
            return .gray
        }
    }
}

#Preview {
    ContentView()
}