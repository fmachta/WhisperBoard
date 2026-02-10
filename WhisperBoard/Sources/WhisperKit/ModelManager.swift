import Foundation

/// Manages Whisper model downloads, caching, and storage
/// Handles model versioning and App Group shared container access
final class ModelManager: ObservableObject {
    
    // MARK: - Types
    
    enum ModelError: Error, LocalizedError {
        case downloadFailed(String)
        case modelNotFound(String)
        case invalidURL
        case storageError(String)
        case verificationFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .downloadFailed(let msg):
                return "Download failed: \(msg)"
            case .modelNotFound(let name):
                return "Model not found: \(name)"
            case .invalidURL:
                return "Invalid model URL"
            case .storageError(let msg):
                return "Storage error: \(msg)"
            case .verificationFailed(let msg):
                return "Model verification failed: \(msg)"
            }
        }
    }
    
    struct DownloadProgress {
        let bytesDownloaded: Int64
        let totalBytes: Int64
        var percentage: Double {
            guard totalBytes > 0 else { return 0 }
            return Double(bytesDownloaded) / Double(totalBytes)
        }
    }
    
    // MARK: - Properties
    
    @Published private(set) var downloadedModels: Set<WhisperModelType> = []
    @Published private(set) var isDownloading = false
    @Published private(set) var downloadProgress: Double = 0
    @Published private(set) var currentDownloadTask: String?
    @Published private(set) var lastDownloadError: ModelError?
    
    @Published var selectedModel: WhisperModelType = .base
    
    // Storage paths
    private let appGroupIdentifier = "group.com.fmachta.whisperboard"
    private let modelsSubdirectory = "WhisperModels"
    
    // Callbacks
    var onDownloadProgress: ((Double) -> Void)?
    var onDownloadComplete: ((WhisperModelType) -> Void)?
    var onDownloadError: ((ModelError) -> Void)?
    
    // Download session
    private var downloadSession: URLSession?
    
    // MARK: - Initialization
    
    init() {
        setupDownloadSession()
        loadDownloadedModels()
    }
    
    // MARK: - Public Methods
    
    /// Get the shared container URL for model storage
    func getModelDirectory() -> URL {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            // Fallback to documents directory
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            return documentsPath.appendingPathComponent(modelsSubdirectory)
        }
        
        let modelDir = containerURL.appendingPathComponent(modelsSubdirectory)
        
        // Create directory if needed
        if !FileManager.default.fileExists(atPath: modelDir.path) {
            try? FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)
        }
        
        return modelDir
    }
    
    /// Check if a model is downloaded
    func isModelDownloaded(_ modelType: WhisperModelType) async throws -> Bool {
        let modelPath = getModelPath(for: modelType)
        return FileManager.default.fileExists(atPath: modelPath.path)
    }
    
    /// Get the path to a specific model
    func getModelPath(_ modelType: WhisperModelType) async throws -> URL {
        let modelPath = getModelPath(for: modelType)
        
        guard FileManager.default.fileExists(atPath: modelPath.path) else {
            throw ModelError.modelNotFound(modelType.rawValue)
        }
        
        return modelPath
    }
    
    /// Get local path for a model (synchronous)
    func getModelPath(for modelType: WhisperModelType) -> URL {
        let modelDir = getModelDirectory()
        return modelDir.appendingPathComponent(modelType.rawValue)
    }
    
    /// Download a model
    /// - Parameters:
    ///   - modelType: Model to download
    ///   - progress: Optional progress callback
    func downloadModel(_ modelType: WhisperModelType, progress: ((Double) -> Void)? = nil) async throws {
        guard !isDownloading else {
            throw ModelError.downloadFailed("Another download is in progress")
        }
        
        let modelURL = try getModelDownloadURL(modelType)
        let destinationURL = getModelPath(for: modelType)
        
        // Check if already downloaded
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            print("[ModelManager] Model \(modelType.rawValue) already downloaded")
            if !downloadedModels.contains(modelType) {
                await MainActor.run {
                    downloadedModels.insert(modelType)
                }
            }
            return
        }
        
        await MainActor.run {
            isDownloading = true
            currentDownloadTask = modelType.rawValue
            self.downloadProgress = 0
        }
        
        // Provide progress callback
        let progressCallback: (Double) -> Void = { [weak self] progressValue in
            Task { @MainActor in
                self?.downloadProgress = progressValue
                progress?(progressValue)
                self?.onDownloadProgress?(progressValue)
            }
        }
        
        do {
            try await downloadFile(from: modelURL, to: destinationURL, progress: progressCallback)
            
            // Verify download
            try await verifyModel(at: destinationURL, modelType: modelType)
            
            await MainActor.run {
                downloadedModels.insert(modelType)
                isDownloading = false
                currentDownloadTask = nil
                downloadProgress = 1.0
            }
            
            onDownloadComplete?(modelType)
            print("[ModelManager] Successfully downloaded \(modelType.rawValue)")
            
        } catch {
            await MainActor.run {
                isDownloading = false
                currentDownloadTask = nil
                lastDownloadError = error as? ModelError
            }
            
            onDownloadError?(error as? ModelError ?? .downloadFailed(error.localizedDescription))
            throw error
        }
    }
    
    /// Delete a downloaded model
    func deleteModel(_ modelType: WhisperModelType) throws {
        let modelPath = getModelPath(for: modelType)
        
        guard FileManager.default.fileExists(atPath: modelPath.path) else {
            return
        }
        
        do {
            try FileManager.default.removeItem(at: modelPath)
            
            Task { @MainActor in
                downloadedModels.remove(modelType)
            }
            
            print("[ModelManager] Deleted \(modelType.rawValue)")
        } catch {
            throw ModelError.storageError(error.localizedDescription)
        }
    }
    
    /// Get total storage used by all models
    func getTotalStorageUsed() -> Int64 {
        let modelDir = getModelDirectory()
        
        guard let enumerator = FileManager.default.enumerator(
            at: modelDir,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        
        for case let fileURL as URL in enumerator {
            if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += Int64(fileSize)
            }
        }
        
        return totalSize
    }
    
    /// Get formatted storage string
    func getFormattedStorageUsed() -> String {
        let bytes = getTotalStorageUsed()
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
    
    /// Cancel current download
    func cancelDownload() {
        downloadSession?.invalidateAndCancel()
        setupDownloadSession()
        
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
            recommendedUse: modelType.recommendedUse,
            path: getModelPath(for: modelType).path
        )
    }
    
    /// Get all model infos
    func getAllModelInfos() -> [ModelInfo] {
        WhisperModelType.allCases.map { getModelInfo($0) }
    }
    
    /// Load all previously downloaded models from storage
    private func loadDownloadedModels() {
        Task {
            var downloaded: Set<WhisperModelType> = []
            
            for modelType in WhisperModelType.allCases {
                let modelPath = getModelPath(for: modelType)
                if FileManager.default.fileExists(atPath: modelPath.path) {
                    downloaded.insert(modelType)
                }
            }
            
            await MainActor.run {
                downloadedModels = downloaded
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupDownloadSession() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 600
        downloadSession = URLSession(configuration: config)
    }
    
    private func getModelDownloadURL(_ modelType: WhisperModelType) throws -> URL {
        // WhisperKit model URLs - using HuggingFace or Apple's model servers
        let baseURL = "https://huggingface.co/argmax/whisper-kit/resolve/main"
        
        // Map model types to actual model filenames
        let modelFilename: String
        switch modelType {
        case .tiny:
            modelFilename = "whisper-tiny.mlpackage"
        case .base:
            modelFilename = "whisper-base.mlpackage"
        case .small:
            modelFilename = "whisper-small.mlpackage"
        }
        
        guard let url = URL(string: "\(baseURL)/\(modelFilename)") else {
            throw ModelError.invalidURL
        }
        
        return url
    }
    
    private func downloadFile(from remoteURL: URL, to destinationURL: URL, progress: @escaping (Double) -> Void) async throws {
        guard let session = downloadSession else {
            throw ModelError.downloadFailed("Session not configured")
        }
        
        let (tempURL, response) = try await session.download(from: remoteURL)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ModelError.downloadFailed("Invalid response")
        }
        
        // Move to final destination
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        
        try FileManager.default.moveItem(at: tempURL, to: destinationURL)
    }
    
    private func verifyModel(at path: URL, modelType: WhisperModelType) async throws {
        // Basic verification - check file exists and has content
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw ModelError.verificationFailed("Model file not found")
        }
        
        // Check file size is reasonable
        let attributes = try FileManager.default.attributesOfItem(atPath: path.path)
        if let size = attributes[.size] as? Int, size < 1000 {
            throw ModelError.verificationFailed("Model file too small - download may have failed")
        }
        
        print("[ModelManager] Model verified: \(modelType.rawValue)")
    }
}

// MARK: - Supporting Types

struct ModelInfo: Identifiable {
    let id = UUID()
    let type: WhisperModelType
    let isDownloaded: Bool
    let size: String
    let recommendedUse: String
    let path: String
}

// MARK: - App Group UserDefaults Helper

extension ModelManager {
    /// Get shared UserDefaults for app group
    static var sharedDefaults: UserDefaults? {
        return UserDefaults(suiteName: "group.com.whisperboard.shared")
    }
    
    /// Save selected model to shared defaults
    func saveSelectedModel(_ model: WhisperModelType) {
        ModelManager.sharedDefaults?.set(model.rawValue, forKey: "selectedModel")
    }
    
    /// Load selected model from shared defaults
    func loadSelectedModel() -> WhisperModelType {
        guard let savedModel = ModelManager.sharedDefaults?.string(forKey: "selectedModel"),
              let modelType = WhisperModelType(rawValue: savedModel) else {
            return .base
        }
        return modelType
    }
}

// MARK: - Storage Cleanup

extension ModelManager {
    /// Clear all downloaded models
    func clearAllModels() throws {
        for modelType in downloadedModels {
            try deleteModel(modelType)
        }
    }
    
    /// Get available disk space
    func getAvailableDiskSpace() -> Int64 {
        let path = getModelDirectory()
        do {
            let values = try path.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            return values.volumeAvailableCapacityForImportantUsage ?? 0
        } catch {
            return 0
        }
    }
}