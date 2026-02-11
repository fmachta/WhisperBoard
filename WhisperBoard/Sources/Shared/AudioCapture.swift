import AVFoundation
import Foundation

/// Memory-efficient audio capture for keyboard extensions
/// Writes directly to file in App Group container, never buffers in memory
final class AudioCapture {
    
    enum AudioCaptureError: Error {
        case engineSetupFailed
        case permissionDenied
        case audioSessionError(Error)
        case captureInProgress
        case notCapturing
        case fileWriteFailed
    }
    
    enum CaptureState: Equatable {
        case idle
        case capturing(URL) // URL of the output file
        case error(String)
    }
    
    // MARK: - Properties
    
    private let audioEngine = AVAudioEngine()
    private let inputNode: AVAudioInputNode
    private var state: CaptureState = .idle
    private var outputFile: AVAudioFile?
    
    private let sampleRate: Double = 16000
    private let channels: AVAudioChannelCount = 1
    
    // Callbacks
    var onStateChanged: ((CaptureState) -> Void)?
    var onError: ((Error) -> Void)?
    var onRecordingFinished: ((URL) -> Void)?
    
    // Thread safety
    private let stateQueue = DispatchQueue(label: "com.whisperboard.audiocapture.state")
    
    // MARK: - Initialization
    
    init() {
        self.inputNode = audioEngine.inputNode
    }
    
    // MARK: - Public Methods
    
    /// Check microphone permission status
    func checkPermission() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            return await requestPermission()
        @unknown default:
            return false
        }
    }
    
    /// Request microphone permission
    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    /// Start recording audio directly to file in App Group container
    func startRecording(to outputURL: URL) throws {
        let currentState = stateQueue.sync { state }
        guard case .idle = currentState else {
            throw AudioCaptureError.captureInProgress
        }
        
        // Configure audio session for recording
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            throw AudioCaptureError.audioSessionError(error)
        }
        
        // Setup audio format (16kHz, mono, Float32 for WhisperKit)
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channels,
            interleaved: false
        ) else {
            throw AudioCaptureError.engineSetupFailed
        }
        
        // Create output file
        do {
            outputFile = try AVAudioFile(forWriting: outputURL, settings: format.settings)
        } catch {
            throw AudioCaptureError.fileWriteFailed
        }
        
        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self = self, let outputFile = self.outputFile else { return }
            
            do {
                try outputFile.write(from: buffer)
            } catch {
                self.stateQueue.async {
                    self.state = .error("Failed to write audio: \(error.localizedDescription)")
                    self.onError?(error)
                }
            }
        }
        
        // Start engine
        do {
            try audioEngine.start()
            stateQueue.async {
                self.state = .capturing(outputURL)
                self.onStateChanged?(.capturing(outputURL))
            }
            print("[AudioCapture] Started recording to: \(outputURL.path)")
        } catch {
            throw AudioCaptureError.engineSetupFailed
        }
    }
    
    /// Stop recording
    func stopRecording() {
        stateQueue.async { [weak self] in
            guard let self = self else { return }
            
            guard case .capturing(let url) = self.state else {
                return
            }
            
            // Stop engine and remove tap
            self.audioEngine.stop()
            self.inputNode.removeTap(onBus: 0)
            
            // Close file
            self.outputFile = nil
            
            // Deactivate audio session
            do {
                try AVAudioSession.sharedInstance().setActive(false)
            } catch {
                print("[AudioCapture] Warning: Failed to deactivate audio session: \(error)")
            }
            
            self.state = .idle
            self.onStateChanged?(.idle)
            self.onRecordingFinished?(url)
            
            print("[AudioCapture] Stopped recording. File saved to: \(url.path)")
        }
    }
    
    /// Get current state
    func getState() -> CaptureState {
        return stateQueue.sync { state }
    }
    
    /// Check if currently recording
    func isRecording() -> Bool {
        if case .capturing = getState() {
            return true
        }
        return false
    }
}
