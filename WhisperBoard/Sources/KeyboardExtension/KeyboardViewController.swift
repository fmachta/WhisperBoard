import UIKit
import AVFoundation

/// Simplified keyboard with dictation button only
/// Optimized for memory efficiency in keyboard extension
class KeyboardViewController: UIInputViewController {
    
    // MARK: - UI
    private var dictateButton: UIButton!
    private var statusLabel: UILabel!
    private var isRecording = false
    private var audioCapture: AudioCapture?
    private var pollTimer: Timer?
    private var recordingStartTime: Date?
    private var maxRecordingTimer: Timer?
    
    // MARK: - Constants
    private let maxRecordingDuration: TimeInterval = 60.0 // 60 seconds max
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupAudioSession()
    }
    
    deinit {
        pollTimer?.invalidate()
        maxRecordingTimer?.invalidate()
        if isRecording {
            audioCapture?.stopRecording()
        }
    }
    
    /// Handle memory warnings - critical for keyboard extensions
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        print("[Keyboard] Memory warning received!")
        if isRecording {
            stopRecording()
            showError("Recording stopped: memory limit")
        }
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)
        
        // Dictate button
        dictateButton = UIButton(type: .system)
        dictateButton.translatesAutoresizingMaskIntoConstraints = false
        dictateButton.backgroundColor = .systemRed
        dictateButton.tintColor = .white
        dictateButton.layer.cornerRadius = 40
        dictateButton.setImage(UIImage(systemName: "mic.fill"), for: .normal)
        dictateButton.titleLabel?.font = UIFont.systemFont(ofSize: 24)
        dictateButton.addTarget(self, action: #selector(dictateTapped), for: .touchUpInside)
        view.addSubview(dictateButton)
        
        // Status label
        statusLabel = UILabel()
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "Tap to dictate"
        statusLabel.textColor = .white
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 2
        view.addSubview(statusLabel)
        
        // Globe button
        let globeButton = UIButton(type: .system)
        globeButton.translatesAutoresizingMaskIntoConstraints = false
        globeButton.setImage(UIImage(systemName: "globe"), for: .normal)
        globeButton.tintColor = .white
        globeButton.addTarget(self, action: #selector(advanceToNextInputMode), for: .touchUpInside)
        view.addSubview(globeButton)
        
        // Delete button
        let deleteButton = UIButton(type: .system)
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.setImage(UIImage(systemName: "delete.left"), for: .normal)
        deleteButton.tintColor = .white
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
        view.addSubview(deleteButton)
        
        NSLayoutConstraint.activate([
            dictateButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            dictateButton.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            dictateButton.widthAnchor.constraint(equalToConstant: 80),
            dictateButton.heightAnchor.constraint(equalToConstant: 80),
            
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: dictateButton.bottomAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            globeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            globeButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            globeButton.widthAnchor.constraint(equalToConstant: 44),
            globeButton.heightAnchor.constraint(equalToConstant: 44),
            
            deleteButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            deleteButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            deleteButton.widthAnchor.constraint(equalToConstant: 44),
            deleteButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(false) // Don't activate yet, just configure
        } catch {
            print("[Keyboard] Audio session setup error: \(error)")
        }
    }
    
    // MARK: - Actions
    @objc private func dictateTapped() {
        isRecording ? stopRecording() : startRecording()
    }
    
    @objc private func deleteTapped() {
        textDocumentProxy.deleteBackward()
    }
    
    // MARK: - Recording
    private func startRecording() {
        guard let containerURL = SharedDefaults.containerURL else {
            showError("App Group error")
            return
        }
        
        let timestamp = Int(Date().timeIntervalSince1970)
        let audioURL = containerURL.appendingPathComponent("audio_\(timestamp).wav")
        
        audioCapture = AudioCapture()
        
        Task {
            guard await audioCapture?.checkPermission() ?? false else {
                showError("Microphone permission required")
                return
            }
            
            do {
                try audioCapture?.startRecording(to: audioURL)
                
                await MainActor.run {
                    isRecording = true
                    recordingStartTime = Date()
                    updateUI(forRecording: true)
                    startMaxRecordingTimer()
                }
                
                audioCapture?.onRecordingFinished = { [weak self] url in
                    self?.processRecording(url)
                }
                
                audioCapture?.onError = { [weak self] error in
                    self?.showError("Recording error")
                    print("[Keyboard] Audio capture error: \(error)")
                }
                
            } catch {
                showError("Failed to start recording")
                print("[Keyboard] Recording error: \(error)")
            }
        }
    }
    
    private func stopRecording() {
        maxRecordingTimer?.invalidate()
        maxRecordingTimer = nil
        
        audioCapture?.stopRecording()
        isRecording = false
        updateUI(forRecording: false)
    }
    
    private func startMaxRecordingTimer() {
        maxRecordingTimer?.invalidate()
        maxRecordingTimer = Timer.scheduledTimer(withTimeInterval: maxRecordingDuration, repeats: false) { [weak self] _ in
            self?.showError("Max duration reached")
            self?.stopRecording()
        }
    }
    
    private func processRecording(_ url: URL) {
        let request = SharedDefaults.TranscriptionRequest(
            audioFileName: url.lastPathComponent,
            language: "en",
            sampleRate: 16000.0,
            timestamp: Date().timeIntervalSince1970
        )
        
        SharedDefaults.writeRequest(request)
        DarwinNotificationCenter.shared.post(SharedDefaults.newAudioNotificationName)
        
        DispatchQueue.main.async { [weak self] in
            self?.statusLabel.text = "Transcribing..."
            self?.startPolling()
        }
        
        // Clean up audio file after transcription is done
        DispatchQueue.global(qos: .background).async {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    private func startPolling() {
        pollTimer?.invalidate()
        var attempts = 0
        let maxAttempts = 60 // 30 seconds timeout (0.5s * 60)
        
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            attempts += 1
            
            guard let result = SharedDefaults.readResult() else {
                if attempts >= maxAttempts {
                    timer.invalidate()
                    self?.showError("Transcription timeout")
                    SharedDefaults.clearRequest()
                }
                return
            }
            
            timer.invalidate()
            
            switch result.status {
            case .completed:
                self?.textDocumentProxy.insertText(result.text)
                self?.statusLabel.text = "Done"
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                    self?.statusLabel.text = "Tap to dictate"
                }
            case .failed:
                self?.showError("Transcription failed: \(result.error ?? "Unknown error")")
            case .pending, .processing:
                self?.statusLabel.text = "Transcribing..."
                return // Keep polling
            }
            
            SharedDefaults.clearResult()
        }
    }
    
    private func updateUI(forRecording: Bool) {
        statusLabel.text = forRecording ? "Recording..." : "Tap to dictate"
        dictateButton.backgroundColor = forRecording ? .systemOrange : .systemRed
    }
    
    private func showError(_ message: String) {
        statusLabel.text = message
        statusLabel.textColor = .systemRed
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.statusLabel.text = "Tap to dictate"
            self?.statusLabel.textColor = .white
        }
    }
}
