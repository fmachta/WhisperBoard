import UIKit
import SwiftUI

// MARK: - Keyboard Row Configuration
struct KeyboardRow {
    let keys: [Key]
}

struct Key {
    let displayText: String
    let outputText: String
    let keyType: KeyType
    let width: CGFloat
    
    enum KeyType {
        case letter
        case shift
        case backspace
        case returnKey
        case space
        case mic
        case globe
        case numbers
        case special
    }
}

// MARK: - Keyboard View Controller
class KeyboardViewController: UIInputViewController {
    
    // MARK: - Properties
    private var keyboardView: UIView!
    private var isShiftEnabled = false
    private var isCapsLock = false
    private var isDarkMode = false
    private var isNumberMode = false
    
    // MARK: - Keyboard Layout
    private let row1: [Key] = [
        Key(displayText: "Q", outputText: "q", type: .letter, width: 42),
        Key(displayText: "W", outputText: "w", type: .letter, width: 42),
        Key(displayText: "E", outputText: "e", type: .letter, width: 42),
        Key(displayText: "R", outputText: "r", type: .letter, width: 42),
        Key(displayText: "T", outputText: "t", type: .letter, width: 42),
        Key(displayText: "Y", outputText: "y", type: .letter, width: 42),
        Key(displayText: "U", outputText: "u", type: .letter, width: 42),
        Key(displayText: "I", outputText: "i", type: .letter, width: 42),
        Key(displayText: "O", outputText: "o", type: .letter, width: 42),
        Key(displayText: "P", outputText: "p", type: .letter, width: 42),
    ]
    
    private let row2: [Key] = [
        Key(displayText: "A", outputText: "a", type: .letter, width: 42),
        Key(displayText: "S", outputText: "s", type: .letter, width: 42),
        Key(displayText: "D", outputText: "d", type: .letter, width: 42),
        Key(displayText: "F", outputText: "f", type: .letter, width: 42),
        Key(displayText: "G", outputText: "g", type: .letter, width: 42),
        Key(displayText: "H", outputText: "h", type: .letter, width: 42),
        Key(displayText: "J", outputText: "j", type: .letter, width: 42),
        Key(displayText: "K", outputText: "k", type: .letter, width: 42),
        Key(displayText: "L", outputText: "l", type: .letter, width: 42),
    ]
    
    private let row3: [Key] = [
        Key(displayText: "⇧", outputText: "", type: .shift, width: 52),
        Key(displayText: "Z", outputText: "z", type: .letter, width: 42),
        Key(displayText: "X", outputText: "x", type: .letter, width: 42),
        Key(displayText: "C", outputText: "c", type: .letter, width: 42),
        Key(displayText: "V", outputText: "v", type: .letter, width: 42),
        Key(displayText: "B", outputText: "b", type: .letter, width: 42),
        Key(displayText: "N", outputText: "n", type: .letter, width: 42),
        Key(displayText: "M", outputText: "m", type: .letter, width: 42),
        Key(displayText: "⌫", outputText: "", type: .backspace, width: 52),
    ]
    
    private let row4: [Key] = [
        Key(displayText: "123", outputText: "", type: .numbers, width: 52),
        Key(displayText: "🌐", outputText: "", type: .globe, width: 44),
        Key(displayText: "", outputText: " ", type: .space, width: 150),
        Key(displayText: "", outputText: "", type: .mic, width: 68),
        Key(displayText: "return", outputText: "\n", type: .returnKey, width: 88),
    ]
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupKeyboard()
        observeAppearanceChanges()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateKeyboardAppearance()
    }
    
    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        updateKeyboardAppearance()
    }
    
    // MARK: - Setup
    private func setupKeyboard() {
        keyboardView = UIView()
        keyboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(keyboardView)
        
        NSLayoutConstraint.activate([
            keyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboardView.topAnchor.constraint(equalTo: view.topAnchor),
            keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            keyboardView.heightAnchor.constraint(equalToConstant: 280)
        ])
        
        buildKeyboard()
    }
    
    private func observeAppearanceChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(interfaceStyleChanged),
            name: NSNotification.Name("UIDeviceInterfaceStyleChangedNotification"),
            object: nil
        )
    }
    
    @objc private func interfaceStyleChanged() {
        updateKeyboardAppearance()
    }
    
    private func updateKeyboardAppearance() {
        if let textInput = textDocumentProxy {
            let textStyle = textInput.keyboardAppearance
            isDarkMode = textStyle == .dark
        }
        
        keyboardView.backgroundColor = isDarkMode ? UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0) : UIColor(red: 0.82, green: 0.83, blue: 0.85, alpha: 1.0)
        rebuildKeyboard()
    }
    
    // MARK: - Build Keyboard
    private func buildKeyboard() {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.distribution = .fillEqually
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        keyboardView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: keyboardView.leadingAnchor, constant: 4),
            stackView.trailingAnchor.constraint(equalTo: keyboardView.trailingAnchor, constant: -4),
            stackView.topAnchor.constraint(equalTo: keyboardView.topAnchor, constant: 8),
            stackView.bottomAnchor.constraint(equalTo: keyboardView.bottomAnchor, constant: -4)
        ])
        
        addKeyRow(to: stackView, keys: row1)
        addKeyRow(to: stackView, keys: row2)
        addKeyRow(to: stackView, keys: row3)
        addKeyRow(to: stackView, keys: row4)
    }
    
    private func rebuildKeyboard() {
        keyboardView.subviews.forEach { $0.removeFromSuperview() }
        buildKeyboard()
    }
    
    private func addKeyRow(to stackView: UIStackView, keys: [Key]) {
        let rowStack = UIStackView()
        rowStack.axis = .horizontal
        rowStack.distribution = .fill
        rowStack.alignment = .fill
        rowStack.spacing = 6
        
        let totalSpacing = keys.count - 1
        let totalKeyWidth = keys.reduce(0) { $0 + $1.width }
        let remainingSpace = 320 - totalKeyWidth - totalSpacing * 6
        let extraSpacing = remainingSpace / CGFloat(keys.count + 1)
        
        for key in keys {
            let button = createKeyButton(key: key)
            rowStack.addArrangedSubview(button)
            
            if key.keyType == .mic {
                button.widthAnchor.constraint(equalToConstant: key.width).isActive = true
            } else if key.keyType != .letter {
                button.widthAnchor.constraint(equalToConstant: key.width).isActive = true
            }
        }
        
        stackView.addArrangedSubview(rowStack)
    }
    
    // MARK: - Create Key Button
    private func createKeyButton(key: Key) -> UIButton {
        let button = KeyboardButton(type: .custom)
        button.key = key
        button.layer.cornerRadius = 5
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.layer.shadowOpacity = isDarkMode ? 0.3 : 0.2
        button.layer.shadowRadius = 0
        button.layer.masksToBounds = false
        
        configureButtonAppearance(button)
        
        if key.keyType == .mic {
            // Make mic button bigger and more prominent
            button.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .medium)
            button.layer.cornerRadius = 10
            addMicButtonHighlight(button)
        } else {
            button.titleLabel?.font = UIFont.systemFont(ofSize: 22, weight: .regular)
        }
        
        button.addTarget(self, action: #selector(keyTapped(_:)), for: .touchUpInside)
        
        // Add long press for backspace
        if key.keyType == .backspace {
            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(backspaceLongPress(_:)))
            longPress.minimumPressDuration = 0.3
            button.addGestureRecognizer(longPress)
        }
        
        return button
    }
    
    private func configureButtonAppearance(_ button: KeyboardButton) {
        guard let key = button.key else { return }
        
        if key.keyType == .letter {
            button.backgroundColor = .white
            button.setTitleColor(.black, for: .normal)
        } else if key.keyType == .shift {
            button.backgroundColor = isDarkMode ? UIColor(red: 0.37, green: 0.37, blue: 0.40, alpha: 1.0) : UIColor(red: 0.75, green: 0.76, blue: 0.78, alpha: 1.0)
            button.setTitleColor(isDarkMode ? .white : .black, for: .normal)
        } else if key.keyType == .mic {
            // Star of the show - red/mic color
            button.backgroundColor = UIColor.systemRedColor
            let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
            let micImage = UIImage(systemName: "mic.fill", withConfiguration: config)
            button.setImage(micImage, for: .normal)
            button.tintColor = .white
            button.layer.shadowColor = UIColor.systemRed.cgColor
            button.layer.shadowOffset = CGSize(width: 0, height: 2)
            button.layer.shadowOpacity = 0.4
            button.layer.shadowRadius = 4
        } else if key.keyType == .globe {
            button.backgroundColor = isDarkMode ? UIColor(red: 0.37, green: 0.37, blue: 0.40, alpha: 1.0) : UIColor(red: 0.75, green: 0.76, blue: 0.78, alpha: 1.0)
            let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)
            let globeImage = UIImage(systemName: "globe", withConfiguration: config)
            button.setImage(globeImage, for: .normal)
            button.tintColor = isDarkMode ? .white : .black
        } else if key.keyType == .backspace {
            button.backgroundColor = isDarkMode ? UIColor(red: 0.37, green: 0.37, blue: 0.40, alpha: 1.0) : UIColor(red: 0.75, green: 0.76, blue: 0.78, alpha: 1.0)
            let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)
            let backspaceImage = UIImage(systemName: "delete.left", withConfiguration: config)
            button.setImage(backspaceImage, for: .normal)
            button.tintColor = isDarkMode ? .white : .black
        } else if key.keyType == .returnKey {
            button.backgroundColor = isDarkMode ? UIColor(red: 0.18, green: 0.31, blue: 0.88, alpha: 1.0) : UIColor(red: 0.20, green: 0.45, blue: 0.89, alpha: 1.0)
            button.setTitle("return", for: .normal)
            button.setTitleColor(.white, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        } else if key.keyType == .numbers {
            button.backgroundColor = isDarkMode ? UIColor(red: 0.37, green: 0.37, blue: 0.40, alpha: 1.0) : UIColor(red: 0.75, green: 0.76, blue: 0.78, alpha: 1.0)
            button.setTitleColor(isDarkMode ? .white : .black, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        } else if key.keyType == .space {
            button.backgroundColor = .white
            button.setTitleColor(.black, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        }
    }
    
    private func addMicButtonHighlight(_ button: UIButton) {
        button.layer.shadowColor = UIColor.systemRed.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 3)
        button.layer.shadowOpacity = 0.5
        button.layer.shadowRadius = 6
        
        // Add pulse animation on hold
        let pulseAnimation = CABasicAnimation(keyPath: "shadowRadius")
        pulseAnimation.fromValue = 6
        pulseAnimation.toValue = 12
        pulseAnimation.duration = 0.8
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity
        // pulseAnimation is not added here as it should be triggered when mic is active
    }
    
    // MARK: - Key Actions
    @objc private func keyTapped(_ sender: KeyboardButton) {
        guard let key = sender.key else { return }
        
        switch key.keyType {
        case .letter:
            handleLetterKey(key)
        case .shift:
            handleShiftKey(sender)
        case .backspace:
            textDocumentProxy.deleteBackward()
            animateKeyPress(sender)
        case .returnKey:
            textDocumentProxy.insertText("\n")
            animateKeyPress(sender)
        case .space:
            textDocumentProxy.insertText(" ")
            animateKeyPress(sender)
        case .mic:
            handleMicButton(sender)
        case .globe:
            advanceToNextInputMode()
        case .numbers:
            // Toggle number mode - for now just animate
            animateKeyPress(sender)
        case .special:
            break
        }
    }
    
    @objc private func backspaceLongPress(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began, .changed:
            while let _ = textDocumentProxy.documentContextBeforeInput {
                textDocumentProxy.deleteBackward()
            }
        default:
            break
        }
    }
    
    private func handleLetterKey(_ key: Key) {
        var output = key.outputText
        
        if isShiftEnabled || isCapsLock {
            output = output.uppercased()
        }
        
        textDocumentProxy.insertText(output)
        animateKeyPressKey(key)
        
        // Auto-disable shift after typing (unless caps lock)
        if isShiftEnabled && !isCapsLock {
            isShiftEnabled = false
            rebuildKeyboard()
        }
    }
    
    private func handleShiftKey(_ button: UIButton) {
        if isShiftEnabled {
            // Double tap for caps lock
            isCapsLock = true
        } else {
            isShiftEnabled = true
            isCapsLock = false
        }
        
        animateKeyPress(button)
        rebuildKeyboard()
    }
    
    private func handleMicButton(_ button: UIButton) {
        // Mic button pressed - for Phase 1, just animate
        // Phase 3 will implement actual recording
        animateKeyPress(button)
        
        // Visual feedback for mic press
        UIView.animate(withDuration: 0.1, animations: {
            button.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                button.transform = .identity
            }
        }
        
        // Show toast or feedback
        showMicFeedback()
    }
    
    private func showMicFeedback() {
        let label = UILabel()
        label.text = "Voice input coming in Phase 3"
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = .white
        label.backgroundColor = UIColor.systemGray.withAlphaComponent(0.9)
        label.textAlignment = .center
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: view.topAnchor, constant: -10),
            label.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
            label.heightAnchor.constraint(equalToConstant: 36)
        ])
        
        label.alpha = 0
        UIView.animate(withDuration: 0.3) {
            label.alpha = 1
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            UIView.animate(withDuration: 0.3) {
                label.alpha = 0
            } completion: { _ in
                label.removeFromSuperview()
            }
        }
    }
    
    private func animateKeyPress(_ button: UIButton) {
        UIView.animate(withDuration: 0.05, animations: {
            button.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            button.alpha = 0.7
        }) { _ in
            UIView.animate(withDuration: 0.05) {
                button.transform = .identity
                button.alpha = 1.0
            }
        }
    }
    
    private func animateKeyPressKey(_ key: Key) {
        // Additional animation logic if needed
    }
}

// MARK: - Keyboard Button Subclass
class KeyboardButton: UIButton {
    var key: Key?
    
    override var isHighlighted: Bool {
        didSet {
            updateHighlightAppearance()
        }
    }
    
    private func updateHighlightAppearance() {
        if isHighlighted {
            backgroundColor = key?.keyType == .letter ? UIColor(red: 0.85, green: 0.85, blue: 0.87, alpha: 1.0) : backgroundColor?.withAlphaComponent(0.8)
        } else {
            configureButtonAppearance()
        }
    }
    
    private func configureButtonAppearance() {
        guard let key = key else { return }
        if key.keyType == .letter {
            backgroundColor = .white
        }
        // Add other key type configurations...
    }
}

// MARK: - UIKeyboardAppearance Extension
extension UIKeyboardAppearance {
    static var dark: UIKeyboardAppearance { .dark }
    static var light: UIKeyboardAppearance { .light }
    static var `default`: UIKeyboardAppearance { .default }
}

// MARK: - UIColor Extension
extension UIColor {
    static var systemRedColor: UIColor {
        return UIColor(red: 255/255, green: 59/255, blue: 48/255, alpha: 1.0)
    }
}