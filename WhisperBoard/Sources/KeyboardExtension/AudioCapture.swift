import AVFoundation
import Foundation

/// Audio capture manager using AVAudioEngine for real-time microphone input
/// Optimized for keyboard extension with limited memory
final class AudioCapture {
    
    // MARK: - Types
    
    enum AudioCaptureError: Error {
        case engineSetupFailed
        case permissionDenied
        case audioSessionError(Error)
        case captureInProgress
        case notCapturing
    }
    
    enum CaptureState: Equatable {
        case idle
        case capturing
        case paused
        case error(String)
    }
    
    // MARK: - Properties
    
    private let audioEngine = AVAudioEngine()
    private let inputNode: AVAudioInputNode
    private var audioBuffer: CircularBuffer
    private var state: CaptureState = .idle
    
    private let sampleRate: Double = 16000
    private let channels: AVAudioChannelCount = 1
    private let bufferSize: AVAudioFrameCount = 4096
    
    // Callbacks
    var onAudioBufferAvailable: ((Data) -> Void)?
    var onStateChanged: ((CaptureState) -> Void)?
    var onError: ((Error) -> Void)?
    
    // Thread safety
    private let stateQueue = DispatchQueue(label: "com.whisperboard.audiocapture.state")
    
    // MARK: - Initialization
    
    init(maxDuration: TimeInterval = 30.0) {
        self.inputNode = audioEngine.inputNode
        self.audioBuffer = CircularBuffer(
            sampleRate: sampleRate,
            maxDuration: maxDuration,
            channels: Int(channels)
        )
        
        setupAudioFormat()
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
    
    /// Start audio capture
    func start() throws {
        let currentState = stateQueue.sync { state }
        if currentState == .capturing {
            throw AudioCaptureError.captureInProgress
        }
        
        let format = setupAudioFormat()
        
        // Configure input node
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer, time: time)
        }
        
        // Start audio engine
        do {
            try audioEngine.start()
            stateQueue.async { [weak self] in
                guard let self = self else { return }
                self.state = .capturing
                self.onStateChanged?(.capturing)
            }
            print("[AudioCapture] Started capturing at \(Int(sampleRate))Hz")
        } catch {
            stateQueue.async { [weak self] in
                guard let self = self else { return }
                self.state = .error(error.localizedDescription)
                self.onError?(AudioCaptureError.engineSetupFailed)
            }
            throw AudioCaptureError.engineSetupFailed
        }
    }
    
    /// Stop audio capture
    func stop() {
        stateQueue.sync {
            guard state == .capturing else { return }
        }
        
        inputNode.removeTap(onBus: 0)
        
        do {
            audioEngine.stop()
            stateQueue.async { [weak self] in
                guard let self = self else { return }
                self.state = .idle
                self.onStateChanged?(.idle)
            }
            print("[AudioCapture] Stopped capturing")
        } catch {
            print("[AudioCapture] Error stopping engine: \(error)")
        }
    }
    
    /// Pause audio capture (keeps engine running)
    func pause() {
        stateQueue.async { [weak self] in
            guard let self = self else { return }
            self.state = .paused
            self.onStateChanged?(.paused)
        }
    }
    
    /// Resume audio capture
    func resume() throws {
        let currentState = stateQueue.sync { state }
        guard currentState == .paused else {
            return
        }
        
        do {
            try audioEngine.start()
            stateQueue.async { [weak self] in
                guard let self = self else { return }
                self.state = .capturing
                self.onStateChanged?(.capturing)
            }
        } catch {
            throw AudioCaptureError.engineSetupFailed
        }
    }
    
    /// Get current state
    func getState() -> CaptureState {
        return stateQueue.sync { state }
    }
    
    /// Get audio buffer for transcription
    func getAudioData() -> Data? {
        return audioBuffer.readAll()
    }
    
    /// Get audio buffer as float array
    func getAudioSamples() -> [Float]? {
        return audioBuffer.readAllSamples()
    }
    
    // MARK: - Private Methods
    
    private func setupAudioFormat() -> AVAudioFormat {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channels,
            interleaved: false
        )!
        
        print("[AudioCapture] Audio format: \(Int(sampleRate))Hz, Mono, Float32")
        return format
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        // Only process if capturing
        if stateQueue.sync(execute: { state }) != .capturing {
            return
        }
        
        // Add to circular buffer
        audioBuffer.write(buffer)
        
        // Notify callback
        if let audioData = audioBuffer.readAll() {
            onAudioBufferAvailable?(audioData)
        }
    }
}

/// Circular buffer for efficient audio sample storage
/// Implements a sliding window for real-time audio processing
final class CircularBuffer {
    
    // MARK: - Properties
    
    private let sampleRate: Double
    private let maxDuration: TimeInterval
    private let channels: Int
    
    private var buffer: [Float]
    private var writeIndex: Int = 0
    private var readIndex: Int = 0
    private let capacity: Int
    
    private let lock = NSLock()
    
    // MARK: - Initialization
    
    init(sampleRate: Double, maxDuration: TimeInterval, channels: Int) {
        self.sampleRate = sampleRate
        self.maxDuration = maxDuration
        self.channels = channels
        
        let samplesPerChannel = Int(sampleRate * maxDuration)
        self.capacity = samplesPerChannel * channels
        self.buffer = [Float](repeating: 0, count: capacity)
        
        print("[CircularBuffer] Created with capacity: \(capacity) samples (\(maxDuration)s at \(Int(sampleRate))Hz)")
    }
    
    // MARK: - Public Methods
    
    /// Write audio buffer to circular buffer
    func write(_ audioBuffer: AVAudioPCMBuffer) {
        guard let channelData = audioBuffer.floatChannelData else { return }
        
        let frameCount = Int(audioBuffer.frameLength)
        
        lock.lock()
        defer { lock.unlock() }
        
        for frame in 0..<frameCount {
            for channel in 0..<channels {
                let sample = channelData[channel][frame]
                buffer[writeIndex] = sample
                writeIndex = (writeIndex + 1) % capacity
                
                // Handle buffer overflow - advance read index to drop oldest
                if writeIndex == readIndex {
                    readIndex = (readIndex + 1) % capacity
                }
            }
        }
    }
    
    /// Read all available samples
    func readAll() -> Data? {
        lock.lock()
        defer { lock.unlock() }
        
        let availableSamples = availableToRead()
        guard availableSamples > 0 else { return nil }
        
        var samples = [Float]()
        samples.reserveCapacity(availableSamples)
        
        var currentIndex = readIndex
        while currentIndex != writeIndex {
            samples.append(buffer[currentIndex])
            currentIndex = (currentIndex + 1) % capacity
        }
        
        return Data(bytes: samples, count: samples.count * MemoryLayout<Float>.size)
    }
    
    /// Read all samples as float array
    func readAllSamples() -> [Float]? {
        lock.lock()
        defer { lock.unlock() }
        
        let availableSamples = availableToRead()
        guard availableSamples > 0 else { return nil }
        
        var samples = [Float]()
        samples.reserveCapacity(availableSamples)
        
        var currentIndex = readIndex
        while currentIndex != writeIndex {
            samples.append(buffer[currentIndex])
            currentIndex = (currentIndex + 1) % capacity
        }
        
        return samples
    }
    
    /// Read samples as Data for a specific duration
    func read(duration: TimeInterval) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        
        let targetSamples = Int(sampleRate * duration)
        let availableSamples = availableToRead()
        let samplesToRead = min(targetSamples, availableSamples)
        
        guard samplesToRead > 0 else { return nil }
        
        var samples = [Float]()
        samples.reserveCapacity(samplesToRead)
        
        var currentIndex = readIndex
        for _ in 0..<samplesToRead {
            samples.append(buffer[currentIndex])
            currentIndex = (currentIndex + 1) % capacity
        }
        
        readIndex = currentIndex
        return Data(bytes: samples, count: samples.count * MemoryLayout<Float>.size)
    }
    
    /// Clear buffer
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        
        buffer = [Float](repeating: 0, count: capacity)
        writeIndex = 0
        readIndex = 0
    }
    
    /// Get current buffer duration
    var currentDuration: TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        
        return Double(availableToRead()) / sampleRate
    }
    
    /// Get buffer capacity
    var maxSamples: Int {
        return capacity
    }
    
    // MARK: - Private Methods
    
    private func availableToRead() -> Int {
        if writeIndex >= readIndex {
            return writeIndex - readIndex
        } else {
            return capacity - readIndex + writeIndex
        }
    }
}