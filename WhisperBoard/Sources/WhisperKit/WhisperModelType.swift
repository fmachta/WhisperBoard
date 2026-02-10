import Foundation

/// Whisper model types supported by WhisperKit
enum WhisperModelType: String, CaseIterable, Identifiable {
    case tiny = "tiny"
    case base = "base"
    case small = "small"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .tiny: return "Tiny"
        case .base: return "Base"
        case .small: return "Small"
        }
    }
    
    var estimatedSize: String {
        switch self {
        case .tiny: return "~39 MB"
        case .base: return "~75 MB"
        case .small: return "~244 MB"
        }
    }
    
    var recommendedUse: String {
        switch self {
        case .tiny: return "Fast, lower accuracy"
        case .base: return "Balanced speed/accuracy"
        case .small: return "Better accuracy, slower"
        }
    }
}
