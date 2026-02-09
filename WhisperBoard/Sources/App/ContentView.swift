import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("WhisperBoard")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Speech-to-text keyboard powered by Whisper")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Setup Instructions Card
                    SetupInstructionsView()
                    
                    // Features Card
                    FeaturesView()
                    
                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("WhisperBoard")
            .navigationBarTitleDisplayMode(.inline)
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

#Preview {
    ContentView()
}