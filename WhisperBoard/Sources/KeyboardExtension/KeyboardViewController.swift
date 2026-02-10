// ULTRA-MINIMAL KEYBOARD FOR TESTING
// This is a bare-bones keyboard to test if ANY keyboard works

import UIKit

class KeyboardViewController: UIInputViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Minimal UI - just one button
        let button = UIButton(type: .system)
        button.setTitle("Tap Me", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.frame = CGRect(x: 20, y: 20, width: 100, height: 44)
        button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        view.addSubview(button)
        
        print("[MinimalKeyboard] Loaded successfully")
    }
    
    @objc func buttonTapped() {
        textDocumentProxy.insertText("Hello from minimal keyboard!")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("[MinimalKeyboard] Will appear")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("[MinimalKeyboard] Did appear")
    }
}
