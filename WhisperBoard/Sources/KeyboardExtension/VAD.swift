import Foundation

/// Voice Activity Detection using energy-based algorithm
/// Detects speech vs silence for automatic recording control
final class VoiceActivityDetector {
    
    // MARK: - Types
    
    struct VADConfig {
        let silenceThreshold: Float
        let speechThreshold: Float
        let silenceDuration: TimeInterval
        let speechDuration: TimeInterval
        let sampleRate: Double
        
        static let `default` = VADConfig(
            silenceThreshold: 0.01,  // Energy threshold for silence
            speechThreshold: 0.015, // Energy threshold for speech
            silenceDuration: 2.0,   // Stop after 2s of silence
            speechDuration: 0.1,     // Minimum speech duration
            sampleRate: 16000
        )
        
        static let sensitive = VADConfig(
            silenceThreshold: 0.005,
            speechThreshold: 0.008,
            silenceDuration: 1.5,
            speechDuration: 0.1,
            sampleRate: 16000
        )
        
        static let conservative = VADConfig(
            silenceThreshold: 0.02,
            speechThreshold: 0.03,
            silenceDuration: 3.0,
            speechDuration: 0.2,
            sampleRate: 16000
        )
    }
    
    enum VADState {
        case silence
        case speech
        case transitioning
    }
    
    struct VADResult {
        let isVoice: Bool
        let energy: Float
        let energyDB: Float
        let state: VADState
        let silenceDuration: TimeInterval
    }
    
    // MARK: - Properties
    
    private let config: VADConfig
    private let audioProcessor: AudioProcessor
    
    private var currentState: VADState = .silence
    private var silenceStartTime: Date?
    private var speechStartTime: Date?
    private var totalSilenceDuration: TimeInterval = 0
    
    private var recentEnergies: [Float] = []
    private let energyHistorySize = 10
    
    // Callbacks
    var onVoiceActivityChanged: ((Bool) -> Void)?
    var onSilenceDetected: ((TimeInterval) -> Void)?
    var onSpeechDetected: (() -> Void)?
    
    // MARK: - Initialization
    
    init(config: VADConfig = .default) {
        self.config = config
        self.audioProcessor = AudioProcessor()
        
        print("[VAD] Initialized with config: silenceThresh=\(config.silenceThreshold), speechThresh=\(config.speechThreshold)")
    }
    
    // MARK: - Public Methods
    
    /// Process audio samples and determine voice activity
    /// - Parameter samples: Audio samples as Float array
    /// - Returns: VADResult with detection details
    func process(_ samples: [Float]) -> VADResult {
        // Compute energy
        let energy = audioProcessor.computeEnergy(samples)
        let energyDB = audioProcessor.computeEnergyDB(samples)
        
        // Update energy history
        recentEnergies.append(energy)
        if recentEnergies.count > energyHistorySize {
            recentEnergies.removeFirst()
        }
        
        // Smooth energy with moving average
        let smoothedEnergy = recentEnergies.reduce(0, +) / Float(recentEnergies.count)
        
        // Determine voice activity based on thresholds
        let isVoice: Bool
        switch currentState {
        case .silence:
            isVoice = smoothedEnergy > config.speechThreshold
        case .speech:
            isVoice = smoothedEnergy > config.silenceThreshold
        case .transitioning:
            // Use higher threshold during transition to avoid flickering
            isVoice = smoothedEnergy > (config.speechThreshold + config.silenceThreshold) / 2
        }
        
        // Update state and timing
        let previousState = currentState
        updateState(isVoice: isVoice)
        
        // Fire callbacks on state changes
        if currentState != previousState {
            if isVoice {
                onSpeechDetected?()
            } else {
                onSilenceDetected?(totalSilenceDuration)
            }
        }
        
        return VADResult(
            isVoice: isVoice,
            energy: smoothedEnergy,
            energyDB: energyDB,
            state: currentState,
            silenceDuration: totalSilenceDuration
        )
    }
    
    /// Process audio data
    func process(_ audioData: Data) -> VADResult {
        guard let samples = audioProcessor.process(audioData) else {
            return VADResult(
                isVoice: false,
                energy: 0,
                energyDB: -Float.infinity,
                state: currentState,
                silenceDuration: totalSilenceDuration
            )
        }
        return process(samples)
    }
    
    /// Check if should stop recording based on silence duration
    /// - Returns: Optional TimeInterval if should stop, nil otherwise
    func shouldStopRecording() -> TimeInterval? {
        if currentState == .silence, let silenceStart = silenceStartTime {
            let duration = Date().timeIntervalSince(silenceStart)
            totalSilenceDuration = duration
            
            if duration >= config.silenceDuration {
                return duration
            }
        }
        return nil
    }
    
    /// Get current voice activity status
    func isVoiceActive() -> Bool {
        return currentState == .speech
    }
    
    /// Reset the VAD state
    func reset() {
        currentState = .silence
        silenceStartTime = nil
        speechStartTime = nil
        totalSilenceDuration = 0
        recentEnergies.removeAll()
        
        print("[VAD] Reset to silence state")
    }
    
    /// Update configuration at runtime
    func updateConfig(_ config: VADConfig) {
        self.config = config
        print("[VAD] Config updated: silenceThresh=\(config.silenceThreshold), speechThresh=\(config.speechThreshold)")
    }
    
    /// Get current configuration
    func getConfig() -> VADConfig {
        return config
    }
    
    // MARK: - Private Methods
    
    private func updateState(isVoice: Bool) {
        let now = Date()
        
        switch (currentState, isVoice) {
        case (.silence, true):
            currentState = .speech
            speechStartTime = now
            silenceStartTime = nil
            print("[VAD] Speech detected at \(now)")
            
        case (.speech, false):
            currentState = .silence
            silenceStartTime = now
            print("[VAD] Silence detected")
            
        case (.transitioning, _):
            // Handle transitioning state
            break
            
        case (.silence, false), (.speech, true):
            // No state change
            break
        }
    }
}

// MARK: - Convenience Extensions

extension VoiceActivityDetector {
    /// Create a VAD optimized for keyboard extension use
    static var keyboardOptimal: VoiceActivityDetector {
        return VoiceActivityDetector(config: .default)
    }
    
    /// Create a sensitive VAD for quiet environments
    static var sensitive: VoiceActivityDetector {
        return VoiceActivityDetector(config: .sensitive)
    }
    
    /// Create a conservative VAD for noisy environments
    static var conservative: VoiceActivityDetector {
        return VoiceActivityDetector(config: .conservative)
    }
}