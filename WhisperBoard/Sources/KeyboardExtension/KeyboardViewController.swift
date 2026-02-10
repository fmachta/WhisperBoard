import UIKit
import AVFoundation

// MARK: - KeyboardViewController
/// A lightweight, memory-efficient custom keyboard with full QWERTY layout
/// and integrated voice-to-text via the main app's WhisperKit transcription service.
///
/// Architecture:
///  - Keyboard captures audio → saves to App Group → Darwin-notifies main app
///  - Main app transcribes with WhisperKit → writes result to App Group → notifies keyboard
///  - Keyboard reads result and lets user insert it
///
/// Memory budget: ~20-25 MB (well under the ~50 MB Jetsam limit).
/// No WhisperKit, no SwiftUI, no heavy frameworks in the extension process.

final class KeyboardViewController: UIInputViewController {

    // MARK: - Types

    private enum KeyboardMode { case letters, numbers, symbols }

    private enum VoiceState {
        case idle
        case recording
        case processing
        case result(String)
        case error(String)
    }

    // MARK: - Layout Constants

    private enum K {
        static let keyboardHeight: CGFloat   = 291
        static let voiceBarHeight: CGFloat   = 40
        static let rowHeight: CGFloat        = 42
        static let rowSpacing: CGFloat       = 6
        static let keySpacing: CGFloat       = 6
        static let keyCornerRadius: CGFloat  = 5
        static let hPad: CGFloat             = 3
        static let vPad: CGFloat             = 4
        static let micSize: CGFloat          = 34
    }

    // MARK: - Key Definitions

    private static let letterRow1 = ["q","w","e","r","t","y","u","i","o","p"]
    private static let letterRow2 = ["a","s","d","f","g","h","j","k","l"]
    private static let letterRow3 = ["z","x","c","v","b","n","m"]

    private static let numberRow1 = ["1","2","3","4","5","6","7","8","9","0"]
    private static let numberRow2 = ["-","/",":",";","(",")","$","&","@"]
    private static let numberRow3 = [".",",","?","!","'"]

    private static let symbolRow1 = ["[","]","{","}","#","%","^","*","+","="]
    private static let symbolRow2 = ["_","\\","|","~","<",">","€","£","¥"]
    private static let symbolRow3 = [".",",","?","!","'"]

    // MARK: - Properties – UI

    private var voiceBar: UIView!
    private var voiceIcon: UIImageView!
    private var voiceLabel: UILabel!
    private var insertButton: UIButton!

    private var rowStacks: [UIStackView] = []          // the four key-row stacks
    private var letterButtons: [[UIButton]] = []       // row0-2 letter/number/symbol buttons
    private var shiftButton: UIButton!
    private var backspaceButton: UIButton!
    private var modeButton: UIButton!                  // "123" / "ABC"
    private var globeButton: UIButton!
    private var micButton: UIButton!
    private var spaceButton: UIButton!
    private var returnButton: UIButton!
    private var symbolToggle: UIButton!                // "#+=", shown in number mode

    // MARK: - Properties – State

    private var mode: KeyboardMode = .letters
    private var voiceState: VoiceState = .idle {
        didSet { updateVoiceBar() }
    }
    private var isShifted = false
    private var isCapsLocked = false
    private var lastShiftTime: Date?
    private var isDark: Bool { textDocumentProxy.keyboardAppearance == .dark ||
                               traitCollection.userInterfaceStyle == .dark }

    // MARK: - Properties – Audio & Timers

    private lazy var audioCapture = AudioCapture(maxDuration: 30)
    private lazy var vad = VoiceActivityDetector.keyboardOptimal
    private var backspaceTimer: Timer?
    private var pollTimer: Timer?
    private var recordingStartTime: Date?

    // MARK: - Haptics

    private let tapHaptic   = UIImpactFeedbackGenerator(style: .light)
    private let micHaptic   = UIImpactFeedbackGenerator(style: .medium)
    private let alertHaptic = UINotificationFeedbackGenerator()

    // ──────────────────────────────────────────────
    // MARK: - Lifecycle
    // ──────────────────────────────────────────────

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        tapHaptic.prepare()
        setupAudioCallbacks()
        observeTranscriptionResults()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        applyTheme()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        applyTheme()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopRecordingIfNeeded()
        DarwinNotificationCenter.shared.removeObserver(SharedDefaults.transcriptionDoneNotificationName)
        pollTimer?.invalidate()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        print("[Keyboard] Memory warning – stopping audio if active")
        stopRecordingIfNeeded()
    }

    // ──────────────────────────────────────────────
    // MARK: - Build UI
    // ──────────────────────────────────────────────

    private func buildUI() {
        guard let root = view else { return }
        root.backgroundColor = isDarkMode ? UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0) : UIColor(red: 0.82, green: 0.83, blue: 0.85, alpha: 1.0)

        // Main container
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(container)
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            container.topAnchor.constraint(equalTo: root.topAnchor),
            container.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            container.heightAnchor.constraint(equalToConstant: 200)
        ])

        // Dictate button
        let dictateButton = UIButton(type: .system)
        dictateButton.translatesAutoresizingMaskIntoConstraints = false
        dictateButton.backgroundColor = .systemRed
        dictateButton.tintColor = .white
        dictateButton.layer.cornerRadius = 40
        dictateButton.layer.shadowColor = UIColor.black.cgColor
        dictateButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        dictateButton.layer.shadowOpacity = 0.3
        dictateButton.layer.shadowRadius = 8
        dictateButton.setImage(UIImage(systemName: "mic.fill"), for: .normal)
        dictateButton.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .medium)
        dictateButton.addTarget(self, action: #selector(dictateTapped), for: .touchUpInside)
        container.addSubview(dictateButton)

        NSLayoutConstraint.activate([
            dictateButton.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            dictateButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            dictateButton.widthAnchor.constraint(equalToConstant: 80),
            dictateButton.heightAnchor.constraint(equalToConstant: 80)
        ])

        // Status label
        let statusLabel = UILabel()
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "Tap to dictate"
        statusLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        statusLabel.textColor = isDarkMode ? .white : .black
        statusLabel.textAlignment = .center
        container.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: dictateButton.bottomAnchor, constant: 16)
        ])

        // Globe button (to switch keyboards)
        let globeButton = UIButton(type: .system)
        globeButton.translatesAutoresizingMaskIntoConstraints = false
        globeButton.setImage(UIImage(systemName: "globe"), for: .normal)
        globeButton.tintColor = isDarkMode ? .white : .black
        globeButton.addTarget(self, action: #selector(globeTapped), for: .touchUpInside)
        container.addSubview(globeButton)

        NSLayoutConstraint.activate([
            globeButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            globeButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20),
            globeButton.widthAnchor.constraint(equalToConstant: 44),
            globeButton.heightAnchor.constraint(equalToConstant: 44)
        ])

        // Delete button
        let deleteButton = UIButton(type: .system)
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.setImage(UIImage(systemName: "delete.left"), for: .normal)
        deleteButton.tintColor = isDarkMode ? .white : .black
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
        container.addSubview(deleteButton)

        NSLayoutConstraint.activate([
            deleteButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            deleteButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20),
            deleteButton.widthAnchor.constraint(equalToConstant: 44),
            deleteButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
        // --- Voice bar ---
        voiceBar = UIView()
        voiceBar.translatesAutoresizingMaskIntoConstraints = false
        voiceBar.layer.cornerRadius = 8
        voiceBar.clipsToBounds = true
        voiceBar.isUserInteractionEnabled = true
        voiceBar.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(voiceBarTapped)))
        container.addSubview(voiceBar)

        voiceIcon = UIImageView()
        voiceIcon.translatesAutoresizingMaskIntoConstraints = false
        voiceIcon.contentMode = .scaleAspectFit
        voiceIcon.tintColor = .secondaryLabel
        voiceBar.addSubview(voiceIcon)

        voiceLabel = UILabel()
        voiceLabel.translatesAutoresizingMaskIntoConstraints = false
        voiceLabel.font = .systemFont(ofSize: 14)
        voiceLabel.textColor = .secondaryLabel
        voiceBar.addSubview(voiceLabel)

        insertButton = UIButton(type: .system)
        insertButton.translatesAutoresizingMaskIntoConstraints = false
        insertButton.setTitle("Insert", for: .normal)
        insertButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        insertButton.isHidden = true
        insertButton.addTarget(self, action: #selector(insertTapped), for: .touchUpInside)
        voiceBar.addSubview(insertButton)

        NSLayoutConstraint.activate([
            voiceBar.topAnchor.constraint(equalTo: container.topAnchor, constant: K.vPad),
            voiceBar.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: K.hPad),
            voiceBar.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -K.hPad),
            voiceBar.heightAnchor.constraint(equalToConstant: K.voiceBarHeight),

            voiceIcon.leadingAnchor.constraint(equalTo: voiceBar.leadingAnchor, constant: 10),
            voiceIcon.centerYAnchor.constraint(equalTo: voiceBar.centerYAnchor),
            voiceIcon.widthAnchor.constraint(equalToConstant: 18),
            voiceIcon.heightAnchor.constraint(equalToConstant: 18),

            voiceLabel.leadingAnchor.constraint(equalTo: voiceIcon.trailingAnchor, constant: 8),
            voiceLabel.centerYAnchor.constraint(equalTo: voiceBar.centerYAnchor),
            voiceLabel.trailingAnchor.constraint(lessThanOrEqualTo: insertButton.leadingAnchor, constant: -8),

            insertButton.trailingAnchor.constraint(equalTo: voiceBar.trailingAnchor, constant: -10),
            insertButton.centerYAnchor.constraint(equalTo: voiceBar.centerYAnchor),
        ])

        // --- Keyboard rows ---
        let keyboardStack = UIStackView()
        keyboardStack.axis = .vertical
        keyboardStack.spacing = K.rowSpacing
        keyboardStack.distribution = .fillEqually
        keyboardStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(keyboardStack)
        NSLayoutConstraint.activate([
            keyboardStack.topAnchor.constraint(equalTo: voiceBar.bottomAnchor, constant: K.vPad),
            keyboardStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: K.hPad),
            keyboardStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -K.hPad),
            keyboardStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -K.vPad),
        ])

        // Row 0 – letters (q-p) / numbers / symbols
        let row0 = makeLetterRow(Self.letterRow1)
        keyboardStack.addArrangedSubview(row0)
        rowStacks.append(row0)

        // Row 1 – letters (a-l) / numbers / symbols
        let row1 = makeLetterRow(Self.letterRow2)
        keyboardStack.addArrangedSubview(row1)
        rowStacks.append(row1)

        // Row 2 – shift + letters (z-m) + backspace
        let row2 = makeRow2()
        keyboardStack.addArrangedSubview(row2)
        rowStacks.append(row2)

        // Row 3 – mode, globe, mic, space, return
        let row3 = makeRow3()
        keyboardStack.addArrangedSubview(row3)
        rowStacks.append(row3)

        applyTheme()
        updateVoiceBar()
    }

    // ──────────────────────────────────────────────
    // MARK: - Row Builders
    // ──────────────────────────────────────────────

    /// Creates a horizontal stack of equal-width character buttons.
    private func makeLetterRow(_ chars: [String]) -> UIStackView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = K.keySpacing
        stack.distribution = .fillEqually

        var buttons: [UIButton] = []
        for ch in chars {
            let btn = makeCharKey(ch)
            stack.addArrangedSubview(btn)
            buttons.append(btn)
        }
        letterButtons.append(buttons)
        return stack
    }

    /// Row 2: shift + letter keys + backspace.
    private func makeRow2() -> UIStackView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = K.keySpacing
        stack.distribution = .fill

        // Shift / symbol toggle
        shiftButton = makeSpecialKey(image: "shift")
        shiftButton.addTarget(self, action: #selector(shiftTapped), for: .touchUpInside)
        stack.addArrangedSubview(shiftButton)
        shiftButton.widthAnchor.constraint(equalToConstant: 42).isActive = true

        // Symbol toggle (hidden unless in number mode)
        symbolToggle = makeSpecialKey(title: "#+=")
        symbolToggle.titleLabel?.font = .systemFont(ofSize: 15, weight: .regular)
        symbolToggle.addTarget(self, action: #selector(symbolToggleTapped), for: .touchUpInside)
        symbolToggle.isHidden = true
        stack.addArrangedSubview(symbolToggle)
        symbolToggle.widthAnchor.constraint(equalToConstant: 42).isActive = true

        // Letter / number / symbol keys
        var buttons: [UIButton] = []
        for ch in Self.letterRow3 {
            let btn = makeCharKey(ch)
            stack.addArrangedSubview(btn)
            buttons.append(btn)
        }
        letterButtons.append(buttons)

        // Backspace
        backspaceButton = makeSpecialKey(image: "delete.left")
        backspaceButton.addTarget(self, action: #selector(backspaceTapped), for: .touchUpInside)
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(backspaceLongPress(_:)))
        longPress.minimumPressDuration = 0.3
        backspaceButton.addGestureRecognizer(longPress)
        stack.addArrangedSubview(backspaceButton)
        backspaceButton.widthAnchor.constraint(equalToConstant: 42).isActive = true

        return stack
    }

    /// Row 3: 123/ABC, globe, mic, space, return.
    private func makeRow3() -> UIStackView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = K.keySpacing
        stack.distribution = .fill

        // 123 / ABC
        modeButton = makeSpecialKey(title: "123")
        modeButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .regular)
        modeButton.addTarget(self, action: #selector(modeTapped), for: .touchUpInside)
        stack.addArrangedSubview(modeButton)
        modeButton.widthAnchor.constraint(equalToConstant: 48).isActive = true

        // Globe
        globeButton = makeSpecialKey(image: "globe")
        globeButton.addTarget(self, action: #selector(globeTapped), for: .touchUpInside)
        stack.addArrangedSubview(globeButton)
        globeButton.widthAnchor.constraint(equalToConstant: 40).isActive = true

        // Mic button – accent color, slightly taller feel
        micButton = UIButton(type: .system)
        micButton.translatesAutoresizingMaskIntoConstraints = false
        let micConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        micButton.setImage(UIImage(systemName: "mic.fill", withConfiguration: micConfig), for: .normal)
        micButton.tintColor = .white
        micButton.backgroundColor = .systemBlue
        micButton.layer.cornerRadius = K.keyCornerRadius
        micButton.addTarget(self, action: #selector(micTapped), for: .touchUpInside)
        stack.addArrangedSubview(micButton)
        micButton.widthAnchor.constraint(equalToConstant: 44).isActive = true

        // Space
        spaceButton = UIButton(type: .system)
        spaceButton.translatesAutoresizingMaskIntoConstraints = false
        spaceButton.setTitle("space", for: .normal)
        spaceButton.titleLabel?.font = .systemFont(ofSize: 16)
        spaceButton.layer.cornerRadius = K.keyCornerRadius
        spaceButton.addTarget(self, action: #selector(spaceTapped), for: .touchUpInside)
        stack.addArrangedSubview(spaceButton)
        // space fills remaining width (no explicit width)

        // Return
        returnButton = UIButton(type: .system)
        returnButton.translatesAutoresizingMaskIntoConstraints = false
        returnButton.setTitle("return", for: .normal)
        returnButton.titleLabel?.font = .systemFont(ofSize: 15)
        returnButton.layer.cornerRadius = K.keyCornerRadius
        returnButton.addTarget(self, action: #selector(returnTapped), for: .touchUpInside)
        stack.addArrangedSubview(returnButton)
        returnButton.widthAnchor.constraint(equalToConstant: 88).isActive = true

        return stack
    }

    // ──────────────────────────────────────────────
    // MARK: - Button Factory Helpers
    // ──────────────────────────────────────────────

    private func makeCharKey(_ ch: String) -> UIButton {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setTitle(ch, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 22)
        btn.layer.cornerRadius = K.keyCornerRadius
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOffset = CGSize(width: 0, height: 1)
        btn.layer.shadowOpacity = 0.15
        btn.layer.shadowRadius = 0
        btn.layer.masksToBounds = false
        btn.tag = 100 // marks as character key
        btn.addTarget(self, action: #selector(charKeyTapped(_:)), for: .touchUpInside)
        return btn
    }

    private func makeSpecialKey(title: String? = nil, image: String? = nil) -> UIButton {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        if let title = title {
            btn.setTitle(title, for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        }
        if let image = image {
            let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
            btn.setImage(UIImage(systemName: image, withConfiguration: config), for: .normal)
        }
        btn.layer.cornerRadius = K.keyCornerRadius
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOffset = CGSize(width: 0, height: 1)
        btn.layer.shadowOpacity = 0.10
        btn.layer.shadowRadius = 0
        btn.layer.masksToBounds = false
        return btn
    }

    // ──────────────────────────────────────────────
    // MARK: - Theme / Appearance
    // ──────────────────────────────────────────────

    private func applyTheme() {
        let dark = isDark

        view.backgroundColor = .clear
        // Container background
        if let container = view.subviews.first {
            container.backgroundColor = dark
                ? UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)
                : UIColor(red: 0.82, green: 0.83, blue: 0.85, alpha: 1)
        }

        let keyBG   = dark ? UIColor(white: 0.40, alpha: 1) : UIColor.white
        let specBG  = dark ? UIColor(white: 0.24, alpha: 1) : UIColor(red: 0.68, green: 0.70, blue: 0.73, alpha: 1)
        let keyText = dark ? UIColor.white : UIColor.black
        let specTint = dark ? UIColor.white : UIColor.black

        // Letter / number buttons
        for row in letterButtons {
            for btn in row {
                btn.backgroundColor = keyBG
                btn.setTitleColor(keyText, for: .normal)
            }
        }

        // Special keys
        for btn in [shiftButton, backspaceButton, modeButton, globeButton, symbolToggle] {
            btn?.backgroundColor = specBG
            btn?.tintColor = specTint
            btn?.setTitleColor(specTint, for: .normal)
        }

        // Space
        spaceButton.backgroundColor = keyBG
        spaceButton.setTitleColor(keyText, for: .normal)

        // Return
        returnButton.backgroundColor = dark
            ? UIColor(red: 0.18, green: 0.31, blue: 0.88, alpha: 1)
            : UIColor(red: 0.20, green: 0.45, blue: 0.89, alpha: 1)
        returnButton.setTitleColor(.white, for: .normal)

        // Voice bar
        voiceBar.backgroundColor = dark
            ? UIColor(white: 0.18, alpha: 1)
            : UIColor(red: 0.93, green: 0.93, blue: 0.95, alpha: 1)

        // Mic button (accent stays blue/red regardless of theme)
        updateMicButtonAppearance()

        // Shift icon update
        updateShiftIcon()
    }

    private func updateMicButtonAppearance() {
        switch voiceState {
        case .idle:
            micButton.backgroundColor = .systemBlue
        case .recording:
            micButton.backgroundColor = .systemRed
        case .processing:
            micButton.backgroundColor = .systemOrange
        case .result:
            micButton.backgroundColor = .systemGreen
        case .error:
            micButton.backgroundColor = .systemRed
        }
    }

    private func updateShiftIcon() {
        let name: String
        if isCapsLocked {
            name = "capslock.fill"
        } else if isShifted {
            name = "shift.fill"
        } else {
            name = "shift"
        }
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        shiftButton.setImage(UIImage(systemName: name, withConfiguration: config), for: .normal)
    }

    // ──────────────────────────────────────────────
    // MARK: - Voice Bar
    // ──────────────────────────────────────────────

    private func updateVoiceBar() {
        updateMicButtonAppearance()
        switch voiceState {
        case .idle:
            voiceIcon.image = UIImage(systemName: "mic")
            voiceLabel.text = "Tap \u{1F3A4} to dictate"
            voiceLabel.textColor = .secondaryLabel
            insertButton.isHidden = true
        case .recording:
            voiceIcon.image = UIImage(systemName: "waveform")
            voiceIcon.tintColor = .systemRed
            voiceLabel.text = "Listening…"
            voiceLabel.textColor = .label
            insertButton.isHidden = true
        case .processing:
            voiceIcon.image = UIImage(systemName: "ellipsis.circle")
            voiceIcon.tintColor = .systemOrange
            voiceLabel.text = "Transcribing…"
            voiceLabel.textColor = .label
            insertButton.isHidden = true
        case .result(let text):
            voiceIcon.image = UIImage(systemName: "checkmark.circle.fill")
            voiceIcon.tintColor = .systemGreen
            voiceLabel.text = text
            voiceLabel.textColor = .label
            insertButton.isHidden = false
        case .error(let msg):
            voiceIcon.image = UIImage(systemName: "exclamationmark.triangle")
            voiceIcon.tintColor = .systemRed
            voiceLabel.text = msg
            voiceLabel.textColor = .systemRed
            insertButton.isHidden = true
        }
    }

    // ──────────────────────────────────────────────
    // MARK: - Key Actions
    // ──────────────────────────────────────────────

    @objc private func charKeyTapped(_ sender: UIButton) {
        guard let ch = sender.currentTitle else { return }
        tapHaptic.impactOccurred()
        textDocumentProxy.insertText(ch)
        animatePress(sender)

        // Auto-unshift after a letter
        if mode == .letters && isShifted && !isCapsLocked {
            isShifted = false
            relabelKeys()
            updateShiftIcon()
        }
    }

    @objc private func shiftTapped() {
        tapHaptic.impactOccurred()
        guard mode == .letters else { return }

        let now = Date()
        if let last = lastShiftTime, now.timeIntervalSince(last) < 0.4 {
            // Double-tap → caps lock
            isCapsLocked = true
            isShifted = true
        } else if isCapsLocked {
            isCapsLocked = false
            isShifted = false
        } else {
            isShifted.toggle()
        }
        lastShiftTime = now
        relabelKeys()
        updateShiftIcon()
    }

    @objc private func backspaceTapped() {
        tapHaptic.impactOccurred()
        textDocumentProxy.deleteBackward()
    }

    @objc private func backspaceLongPress(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            backspaceTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
                self?.textDocumentProxy.deleteBackward()
            }
        case .ended, .cancelled:
            backspaceTimer?.invalidate()
            backspaceTimer = nil
        default: break
        }
    }

    @objc private func spaceTapped() {
        tapHaptic.impactOccurred()
        textDocumentProxy.insertText(" ")
    }

    @objc private func returnTapped() {
        tapHaptic.impactOccurred()
        textDocumentProxy.insertText("\n")
    }

    @objc private func globeTapped() {
        tapHaptic.impactOccurred()
        advanceToNextInputMode()
    }

    @objc private func modeTapped() {
        tapHaptic.impactOccurred()
        switch mode {
        case .letters:
            mode = .numbers
            modeButton.setTitle("ABC", for: .normal)
            shiftButton.isHidden = true
            symbolToggle.isHidden = false
            symbolToggle.setTitle("#+=", for: .normal)
        case .numbers, .symbols:
            mode = .letters
            modeButton.setTitle("123", for: .normal)
            shiftButton.isHidden = false
            symbolToggle.isHidden = true
        }
        relabelKeys()
    }

    @objc private func symbolToggleTapped() {
        tapHaptic.impactOccurred()
        if mode == .numbers {
            mode = .symbols
            symbolToggle.setTitle("123", for: .normal)
        } else {
            mode = .numbers
            symbolToggle.setTitle("#+=", for: .normal)
        }
        relabelKeys()
    }
    // MARK: - Layout Switching

    private func relabelKeys() {
        let rows: [[String]]
        switch mode {
        case .letters:
            rows = [Self.letterRow1, Self.letterRow2, Self.letterRow3]
        case .numbers:
            rows = [Self.numberRow1, Self.numberRow2, Self.numberRow3]
        case .symbols:
            rows = [Self.symbolRow1, Self.symbolRow2, Self.symbolRow3]
        }

        for (rowIdx, charRow) in rows.enumerated() {
            guard rowIdx < letterButtons.count else { break }
            let btnRow = letterButtons[rowIdx]
            for (colIdx, btn) in btnRow.enumerated() {
                if colIdx < charRow.count {
                    var ch = charRow[colIdx]
                    if mode == .letters && (isShifted || isCapsLocked) {
                        ch = ch.uppercased()
                    }
                    btn.setTitle(ch, for: .normal)
                    btn.isHidden = false
                } else {
                    btn.isHidden = true
                }
            }
        }

        applyTheme()
    }

    // ──────────────────────────────────────────────
    // MARK: - Voice Bar Actions
    // ──────────────────────────────────────────────

    @objc private func voiceBarTapped() {
        if case .result(let text) = voiceState {
            insertTranscription(text)
        }
    }

    @objc private func insertTapped() {
        if case .result(let text) = voiceState {
            insertTranscription(text)
        }
    }

    private func insertTranscription(_ text: String) {
        textDocumentProxy.insertText(text)
        alertHaptic.notificationOccurred(.success)
        voiceState = .idle
        SharedDefaults.clearResult()
    }

    // ──────────────────────────────────────────────
    // MARK: - Mic / Recording
    // ──────────────────────────────────────────────

    @objc private func micTapped() {
        micHaptic.impactOccurred()
        switch voiceState {
        case .idle, .result, .error:
            startRecording()
        case .recording:
            stopRecordingAndTranscribe()
        case .processing:
            break // ignore tap while processing
        }
    }

    private func startRecording() {
        Task {
            let granted = await audioCapture.checkPermission()
            guard granted else {
                await MainActor.run { voiceState = .error("Mic access denied – enable in Settings") }
                return
            }
            do {
                try audioCapture.start()
                await MainActor.run {
                    voiceState = .recording
                    recordingStartTime = Date()
                }
            } catch {
                await MainActor.run { voiceState = .error("Could not start recording") }
            }
        }
    }

    private func stopRecordingAndTranscribe() {
        audioCapture.stop()

        guard let samples = audioCapture.getAudioSamples(), !samples.isEmpty else {
            voiceState = .error("No audio captured")
            return
        }

        voiceState = .processing

        // Save audio to App Group
        let fileName = "recording_\(Int(Date().timeIntervalSince1970)).pcm"
        guard SharedDefaults.saveAudio(samples, fileName: fileName) != nil else {
            voiceState = .error("Failed to save audio")
            return
        }

        // Determine language preference
        let lang = SharedDefaults.sharedDefaults?.string(forKey: SharedDefaults.selectedLanguageKey) ?? "auto"

        // Write transcription request
        let request = SharedDefaults.TranscriptionRequest(
            audioFileName: fileName,
            language: lang,
            sampleRate: 16000,
            timestamp: Date().timeIntervalSince1970
        )
        guard SharedDefaults.writeRequest(request) else {
            voiceState = .error("Failed to create request")
            return
        }

        // Notify main app
        DarwinNotificationCenter.shared.post(SharedDefaults.newAudioNotificationName)

        // Poll for result with timeout
        startPollingForResult(requestTimestamp: request.timestamp)
    }
    private func stopRecordingIfNeeded() {
        if case .recording = voiceState {
            audioCapture.stop()
            voiceState = .idle
        }
        backspaceTimer?.invalidate()
        pollTimer?.invalidate()
    }

    // MARK: - Audio Callbacks

    private func setupAudioCallbacks() {
        audioCapture.onAudioBufferAvailable = { [weak self] _ in
            // Feed VAD for auto-stop after silence
            guard let self = self else { return }
            if let samples = self.audioCapture.getAudioSamples(), samples.count > 1600 {
                let tail = Array(samples.suffix(1600)) // last 100ms
                let result = self.vad.process(tail)
                if !result.isVoice, let silenceDur = self.vad.shouldStopRecording() {
                    // Only auto-stop if we've been recording for > 1s
                    if let start = self.recordingStartTime,
                       Date().timeIntervalSince(start) > 1.0, silenceDur > 2.0 {
                        DispatchQueue.main.async { self.stopRecordingAndTranscribe() }
                    }
                }
            }
        }
    }

    // MARK: - Result Polling

    private func observeTranscriptionResults() {
        DarwinNotificationCenter.shared.observe(SharedDefaults.transcriptionDoneNotificationName) { [weak self] in
            self?.checkForResult()
        }
    }

    private func startPollingForResult(requestTimestamp: TimeInterval) {
        pollTimer?.invalidate()
        var elapsed: TimeInterval = 0
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            elapsed += 0.5
            self?.checkForResult()

            // Timeout after 15 seconds
            if elapsed >= 15 {
                timer.invalidate()
                if case .processing = self?.voiceState {
                    self?.voiceState = .error("Transcription timed out – is WhisperBoard app running?")
                }
            }
        }
    }

    private func checkForResult() {
        guard case .processing = voiceState else { return }
        guard let result = SharedDefaults.readResult() else { return }

        switch result.status {
        case .completed:
            pollTimer?.invalidate()
            voiceState = .result(result.text)
            alertHaptic.notificationOccurred(.success)
        case .failed:
            pollTimer?.invalidate()
            voiceState = .error(result.error ?? "Transcription failed")
            alertHaptic.notificationOccurred(.error)
        case .processing, .pending:
            break // keep waiting
        }
    }

    // ──────────────────────────────────────────────
    // MARK: - Animations
    // ──────────────────────────────────────────────

    private func animatePress(_ button: UIButton) {
        UIView.animate(withDuration: 0.04, animations: {
            button.transform = CGAffineTransform(scaleX: 0.93, y: 0.93)
        }) { _ in
            UIView.animate(withDuration: 0.04) {
                button.transform = .identity
            }
        }
    }

    // MARK: - Dictate Button Actions

    @objc private func dictateTapped() {
        print("[Keyboard] Dictate button tapped")
        // TODO: Start/stop recording
        // For now, just show feedback
        alertHaptic.notificationOccurred(.success)
    }

    @objc private func globeTapped() {
        print("[Keyboard] Globe button tapped - advancing to next input mode")
        advanceToNextInputMode()
    }

    @objc private func deleteTapped() {
        print("[Keyboard] Delete button tapped")
        textDocumentProxy.deleteBackward()
        tapHaptic.impactOccurred()
    }
}
