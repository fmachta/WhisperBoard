import Foundation
import WhisperKit

/// Manages Whisper model downloads, selection, and storage state.
/// Uses WhisperKit's built-in model downloading and caching.

final class ModelManager: ObservableObject {

    // MARK: - Types

    enum ModelError: Error, LocalizedError {
        case downloadFailed(String)
        case modelNotFound(String)
        case initializationFailed(String)

        var errorDescription: String? {
            switch self {
            case .downloadFailed(let m):      return "Download failed: \(m)"
            case .modelNotFound(let n):       return "Model not found: \(n)"
            case .initializationFailed(let m): return "Init failed: \(m)"
            }
        }
    }

    // MARK: - Published

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

    // MARK: - Init

    init() {
        loadPersistedState()
    }

    // MARK: - Public API

    /// Check if a model has been downloaded (synchronous, in-memory check).
    func isModelDownloaded(_ modelType: WhisperModelType) -> Bool {
        downloadedModels.contains(modelType)
    }

    /// Download (or verify) a model using WhisperKit's built-in downloader.
    func downloadModel(_ modelType: WhisperModelType, progress: ((Double) -> Void)? = nil) async throws {
        guard !isDownloading else {
            throw ModelError.downloadFailed("Another download is in progress")
        }

        await MainActor.run {
            isDownloading = true
            currentDownloadTask = modelType.rawValue
            downloadProgress = 0
        }

        do {
            // WhisperKit downloads + caches the model during init
            let config = WhisperKitConfig(model: modelType.modelId)
            _ = try await WhisperKit(config)

            await MainActor.run {
                downloadedModels.insert(modelType)
                isDownloading = false
                currentDownloadTask = nil
                downloadProgress = 1.0
            }

            persistDownloaded()
            onDownloadComplete?(modelType)
            print("[ModelManager] Downloaded \(modelType.displayName)")

        } catch {
            let modelError = ModelError.downloadFailed(error.localizedDescription)
            await MainActor.run {
                isDownloading = false
                currentDownloadTask = nil
                lastDownloadError = modelError
            }
            onDownloadError?(modelError)
            throw modelError
        }
    }

    /// Remove a model from the downloaded set.
    func deleteModel(_ modelType: WhisperModelType) {
        downloadedModels.remove(modelType)
        persistDownloaded()
        if selectedModel == modelType {
            selectedModel = .base
        }
        print("[ModelManager] Removed \(modelType.displayName)")
    }

    func cancelDownload() {
        Task { @MainActor in
            isDownloading = false
            currentDownloadTask = nil
            downloadProgress = 0
        }
    }

    /// Persist the selected model to shared UserDefaults.
    func saveSelectedModel(_ model: WhisperModelType) {
        selectedModel = model
        SharedDefaults.sharedDefaults?.set(model.rawValue, forKey: SharedDefaults.selectedModelKey)
        UserDefaults.standard.set(model.rawValue, forKey: SharedDefaults.selectedModelKey)
    }

    func clearAllModels() {
        downloadedModels.removeAll()
        persistDownloaded()
    }

    // MARK: - Info

    func getModelInfo(_ modelType: WhisperModelType) -> ModelInfo {
        ModelInfo(type: modelType,
                  isDownloaded: downloadedModels.contains(modelType),
                  size: modelType.estimatedSize,
                  recommendedUse: modelType.recommendedUse)
    }

    func getAllModelInfos() -> [ModelInfo] {
        WhisperModelType.allCases.map { getModelInfo($0) }
    }

    func getFormattedStorageUsed() -> String {
        let count = downloadedModels.count
        return count == 0 ? "No models" : "\(count) model(s) cached"
    }

    func getAvailableDiskSpace() -> Int64 {
        do {
            let url = URL(fileURLWithPath: NSHomeDirectory())
            let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            return values.volumeAvailableCapacityForImportantUsage ?? 0
        } catch { return 0 }
    }

    // MARK: - Persistence

    private func loadPersistedState() {
        if let raw = UserDefaults.standard.string(forKey: SharedDefaults.selectedModelKey),
           let model = WhisperModelType(rawValue: raw) {
            selectedModel = model
        }
        if let savedList = UserDefaults.standard.stringArray(forKey: "downloadedModels") {
            downloadedModels = Set(savedList.compactMap { WhisperModelType(rawValue: $0) })
        }
    }

    private func persistDownloaded() {
        UserDefaults.standard.set(downloadedModels.map(\.rawValue), forKey: "downloadedModels")
    }
}

// MARK: - ModelInfo

struct ModelInfo: Identifiable {
    let id = UUID()
    let type: WhisperModelType
    let isDownloaded: Bool
    let size: String
    let recommendedUse: String
}
