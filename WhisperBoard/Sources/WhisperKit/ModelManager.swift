import Foundation
import WhisperKit

/// Manages Whisper model downloads and availability
/// Uses WhisperKit's built-in model downloading
final class ModelManager: ObservableObject {
    
    // MARK: - Types
    
    enum ModelError: Error, LocalizedError {
        case downloadFailed(String)
        case modelNotFound(String)
        case initializationFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .downloadFailed(let msg):
                return "Download failed: \(msg)"
            case .modelNotFound(let name):
                return "Model not found: \(name)"
            case .initializationFailed(let msg):
                return "Initialization failed: \(msg)"
            }
        }
    }
    
    // MARK: - Properties
    
    @Published private(set) var downloadedModels: Set<WhisperModelType> = []
    @Published private(set) var isDownloading = false
    @Published private(set) var downloadProgress: Double = 0
    @Published private(set) var currentDownloadTask: String?
    @Published private(set) var lastDownloadError: ModelError?
    
    @Published var selectedModel: WhisperModelType = .base
    
    // Callbacks
    var onDownloadProgress: ((Double) -> Void)?
    var onDownloadComplete: ((WhisperModelType) -> Void)?
    var onDownloadError: ((ModelError) -> Void)?
    
    // WhisperKit instance for model downloading
    private var whisperKit: WhisperKit?
    
    // MARK: - Initialization
    
    init() {
        loadDownloadedModels()
    }
    
    // MARK: - Public Methods
    
    /// Download a model using WhisperKit's built-in downloader
    /// - Parameters:
    ///   - modelType: Model to download
    ///   - progress: Optional progress callback
    func downloadModel(_ modelType: WhisperModelType, progress: ((Double) -> Void)? = nil) async throws {
        guard !isDownloading else {
            throw ModelError.downloadFailed("Another download is in progress")
        }
        
        await MainActor.run {
            isDownloading = true
            currentDownloadTask = modelType.rawValue
            self.downloadProgress = 0
        }
        
        do {
            // Use WhisperKit's built-in model downloading
            let config = WhisperKitConfig(model: modelType.rawValue)
            whisperKit = try await WhisperKit(config)
            
            await MainActor.run {
                downloadedModels.insert(modelType)
                isDownloading = false
                currentDownloadTask = nil
                downloadProgress = 1.0
            }
            
            onDownloadComplete?(modelType)
            print("[ModelManager] Successfully loaded \(modelType.rawValue)")
            
        } catch {
            await MainActor.run {
                isDownloading = false
                currentDownloadTask = nil
                lastDownloadError = .downloadFailed(error.localizedDescription)
            }
            
            onDownloadError?(.downloadFailed(error.localizedDescription))
            throw ModelError.downloadFailed(error.localizedDescription)
        }
    }
    
    /// Check if a model is downloaded
    func isModelDownloaded(_ modelType: WhisperModelType) -> Bool {
        return downloadedModels.contains(modelType)
    }
    
    /// Delete a downloaded model reference
    func deleteModel(_ modelType: WhisperModelType) {
        Task { @MainActor in
            downloadedModels.remove(modelType)
            print("[ModelManager] Removed \(modelType.rawValue) from downloaded list")
        }
    }
    
    /// Cancel current download
    func cancelDownload() {
        Task { @MainActor in
            isDownloading = false
            currentDownloadTask = nil
            downloadProgress = 0
        }
    }
    
    /// Get model info for display
    func getModelInfo(_ modelType: WhisperModelType) -> ModelInfo {
        ModelInfo(
            type: modelType,
            isDownloaded: downloadedModels.contains(modelType),
            size: modelType.estimatedSize,
            recommendedUse: modelType.recommendedUse
        )
    }
    
    /// Get all model infos
    func getAllModelInfos() -> [ModelInfo] {
        WhisperModelType.allCases.map { getModelInfo($0) }
    }
    
    /// Get formatted storage used string
    func getFormattedStorageUsed() -> String {
        // WhisperKit manages its own cache, return placeholder
        return "Managed by WhisperKit"
    }
    
    /// Get available disk space
    func getAvailableDiskSpace() -> Int64 {
        do {
            let fileURL = URL(fileURLWithPath: NSHomeDirectory() as String)
            let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            return values.volumeAvailableCapacityForImportantUsage ?? 0
        } catch {
            return 0
        }
    }
    
    /// Save selected model preference
    func saveSelectedModel(_ model: WhisperModelType) {
        selectedModel = model
        // Persist to UserDefaults
        UserDefaults.standard.set(model.rawValue, forKey: "selectedWhisperModel")
    }
    
    /// Clear all models (just clears our tracking, WhisperKit manages its own cache)
    func clearAllModels() throws {
        Task { @MainActor in
            downloadedModels.removeAll()
        }
    }
    
    // MARK: - Private Methods
    
    /// Load all previously downloaded models from storage
    private func loadDownloadedModels() {
        // WhisperKit manages its own model cache
        // We'll check availability on demand
        Task { @MainActor in
            // For now, assume no models are pre-downloaded
            // They will be downloaded on first use
            downloadedModels = []
        }
    }
}

// MARK: - Model Info

struct ModelInfo: Identifiable {
    let id = UUID()
    let type: WhisperModelType
    let isDownloaded: Bool
    let size: String
    let recommendedUse: String
}
