import Foundation

/// Whisper model sizes supported by the app.
/// `modelId` is the string passed to `WhisperKitConfig(model:)`.
enum WhisperModelType: String, CaseIterable, Identifiable, Codable {
    case tiny  = "tiny"
    case base  = "base"
    case small = "small"

    var id: String { rawValue }

    /// The identifier WhisperKit uses to resolve the model.
    var modelId: String {
        switch self {
        case .tiny:  return "openai_whisper-tiny"
        case .base:  return "openai_whisper-base"
        case .small: return "openai_whisper-small"
        }
    }

    var displayName: String {
        switch self {
        case .tiny:  return "Tiny"
        case .base:  return "Base"
        case .small: return "Small"
        }
    }

    var estimatedSize: String {
        switch self {
        case .tiny:  return "~39 MB"
        case .base:  return "~75 MB"
        case .small: return "~244 MB"
        }
    }

    var recommendedUse: String {
        switch self {
        case .tiny:  return "Fast, lower accuracy"
        case .base:  return "Balanced speed & accuracy"
        case .small: return "Best accuracy, slower"
        }
    }
}
