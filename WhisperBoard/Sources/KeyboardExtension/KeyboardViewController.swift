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
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
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
    
    // MARK: - Actions
    @objc private func dictateTapped() {
        isRecording ? stopRecording() : startRecording()
    }
    
    @objc private func deleteTapped() {
        textDocumentProxy.deleteBackward()
    }
    
    // MARK: - Recording
    private func startRecording() {
        guard let containerURL = SharedDefaults.containerURL else { return }
        
        let timestamp = Int(Date().timeIntervalSince1970)
        let audioURL = containerURL.appendingPathComponent("audio_\(timestamp).wav")
        
        audioCapture = AudioCapture()
        
        Task {
            guard await audioCapture?.checkPermission() ?? false else { return }
            
            do {
                try audioCapture?.startRecording(to: audioURL)
                isRecording = true
                updateUI(forRecording: true)
                
                audioCapture?.onRecordingFinished = { [weak self] url in
                    self?.processRecording(url)
                }
            } catch {
                print("[Keyboard] Recording error: \(error)")
            }
        }
    }
    
    private func stopRecording() {
        audioCapture?.stopRecording()
        isRecording = false
        updateUI(forRecording: false)
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
        
        // Poll for result
        startPolling()
    }
    
    private func startPolling() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let result = SharedDefaults.readResult() else { return }
            timer.invalidate()
            
            if case .completed = result.status {
                self?.textDocumentProxy.insertText(result.text)
                SharedDefaults.clearResult()
            }
        }
    }
    
    private func updateUI(forRecording: Bool) {
        statusLabel.text = forRecording ? "Recording..." : "Tap to dictate"
        dictateButton.backgroundColor = forRecording ? .systemOrange : .systemRed
    }
}
