import UIKit

/// Ultra-lightweight keyboard extension that delegates recording to main app
/// Keyboard extensions cannot use AVAudioSession - must use main app
class KeyboardViewController: UIInputViewController {
    
    // MARK: - UI
    private var dictateButton: UIButton!
    private var statusLabel: UILabel!
    private var pollTimer: Timer?
    private var isWaitingForTranscription = false
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        observeTranscriptionResults()
    }
    
    deinit {
        pollTimer?.invalidate()
        DarwinNotificationCenter.shared.removeObserver(SharedDefaults.transcriptionDoneNotificationName)
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
    
    private func observeTranscriptionResults() {
        DarwinNotificationCenter.shared.observe(
            SharedDefaults.transcriptionDoneNotificationName
        ) { [weak self] in
            DispatchQueue.main.async {
                self?.handleTranscriptionResult()
            }
        }
    }
    
    // MARK: - Actions
    @objc private func dictateTapped() {
        if isWaitingForTranscription {
            // Cancel/close
            isWaitingForTranscription = false
            pollTimer?.invalidate()
            updateUI()
        } else {
            startDictation()
        }
    }
    
    @objc private func deleteTapped() {
        textDocumentProxy.deleteBackward()
    }
    
    // MARK: - Dictation
    private func startDictation() {
        // Check if main app can record
        let canRecord = SharedDefaults.sharedDefaults?.bool(forKey: "canRecordAudio") ?? false
        
        if canRecord {
            // Signal main app to start recording
            SharedDefaults.sharedDefaults?.set(true, forKey: "shouldStartRecording")
            SharedDefaults.sharedDefaults?.synchronize()
            DarwinNotificationCenter.shared.post("com.fmachta.whisperboard.startRecording")
            
            isWaitingForTranscription = true
            statusLabel.text = "Recording in app...\n(Tap to cancel)"
            dictateButton.backgroundColor = .systemOrange
            
            // Start polling for result
            startPolling()
        } else {
            // Open main app to grant permission/setup
            statusLabel.text = "Open WhisperBoard app first"
            openMainApp()
        }
    }
    
    private func openMainApp() {
        // Try to open the container app
        if let url = URL(string: "whisperboard://") {
            extensionContext?.open(url) { success in
                if !success {
                    self.statusLabel.text = "Please open WhisperBoard app"
                }
            }
        }
    }
    
    private func startPolling() {
        pollTimer?.invalidate()
        var attempts = 0
        let maxAttempts = 120 // 60 second timeout (0.5s * 120)
        
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            attempts += 1
            
            guard self.isWaitingForTranscription else {
                timer.invalidate()
                return
            }
            
            if attempts >= maxAttempts {
                timer.invalidate()
                self.isWaitingForTranscription = false
                self.showError("Timeout - no response")
                return
            }
            
            // Check for result
            if let result = SharedDefaults.readResult() {
                timer.invalidate()
                self.handleResult(result)
            }
        }
    }
    
    private func handleTranscriptionResult() {
        guard isWaitingForTranscription else { return }
        
        if let result = SharedDefaults.readResult() {
            handleResult(result)
        }
    }
    
    private func handleResult(_ result: SharedDefaults.TranscriptionResult) {
        isWaitingForTranscription = false
        
        switch result.status {
        case .completed:
            textDocumentProxy.insertText(result.text)
            statusLabel.text = "Inserted ✓"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.updateUI()
            }
        case .failed:
            showError("Failed: \(result.error ?? "Unknown")")
        case .pending, .processing:
            // Still processing, keep waiting
            isWaitingForTranscription = true
            statusLabel.text = "Processing..."
            return
        }
        
        SharedDefaults.clearResult()
    }
    
    private func updateUI() {
        statusLabel.text = "Tap to dictate"
        statusLabel.textColor = .white
        dictateButton.backgroundColor = .systemRed
    }
    
    private func showError(_ message: String) {
        statusLabel.text = message
        statusLabel.textColor = .systemRed
        dictateButton.backgroundColor = .systemRed
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.updateUI()
        }
    }
}