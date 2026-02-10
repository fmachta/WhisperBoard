import Foundation

// MARK: - App Group Communication Layer
/// Provides shared state, file transfer, and Darwin notification signaling
/// between the main WhisperBoard app and the keyboard extension.

enum SharedDefaults {

    // MARK: - Identifiers

    static let appGroupIdentifier = "group.com.fmachta.whisperboard"

    // Darwin notification names
    static let newAudioNotificationName    = "com.fmachta.whisperboard.newAudio"
    static let transcriptionDoneNotificationName = "com.fmachta.whisperboard.transcriptionDone"

    // UserDefaults keys (shared)
    static let selectedModelKey   = "selectedWhisperModel"
    static let selectedLanguageKey = "selectedLanguage"
    static let serviceRunningKey  = "isTranscriptionServiceRunning"

    // File names
    private static let requestFile = "transcription_request.json"
    private static let resultFile  = "transcription_result.json"
    private static let audioDir    = "audio"

    // MARK: - Shared Containers

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    static var audioDirectoryURL: URL? {
        guard let container = containerURL else { return nil }
        let url = container.appendingPathComponent(audioDir, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: - Data Models

    struct TranscriptionRequest: Codable {
        let audioFileName: String
        let language: String
        let sampleRate: Double
        let timestamp: TimeInterval
    }

    struct TranscriptionResult: Codable {
        let text: String
        let status: Status
        let requestTimestamp: TimeInterval
        let completedTimestamp: TimeInterval
        let error: String?

        enum Status: String, Codable {
            case pending
            case processing
            case completed
            case failed
        }
    }

    // MARK: - Audio File I/O

    /// Save raw Float32 PCM audio samples to the shared audio directory.
    @discardableResult
    static func saveAudio(_ samples: [Float], fileName: String) -> URL? {
        guard let dir = audioDirectoryURL else { return nil }
        let url = dir.appendingPathComponent(fileName)
        let data = samples.withUnsafeBufferPointer { Data(buffer: $0) }
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            print("[SharedDefaults] saveAudio failed: \(error)")
            return nil
        }
    }

    /// Load raw Float32 PCM audio samples from the shared audio directory.
    static func loadAudio(fileName: String) -> [Float]? {
        guard let dir = audioDirectoryURL else { return nil }
        let url = dir.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        let count = data.count / MemoryLayout<Float>.size
        return data.withUnsafeBytes { ptr -> [Float] in
            let buffer = ptr.bindMemory(to: Float.self)
            return Array(buffer)
        }
    }

    // MARK: - Request / Result I/O

    static func writeRequest(_ request: TranscriptionRequest) -> Bool {
        guard let container = containerURL else { return false }
        let url = container.appendingPathComponent(requestFile)
        do {
            let data = try JSONEncoder().encode(request)
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            print("[SharedDefaults] writeRequest failed: \(error)")
            return false
        }
    }

    static func readRequest() -> TranscriptionRequest? {
        guard let container = containerURL else { return nil }
        let url = container.appendingPathComponent(requestFile)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(TranscriptionRequest.self, from: data)
    }

    static func clearRequest() {
        guard let container = containerURL else { return }
        let url = container.appendingPathComponent(requestFile)
        try? FileManager.default.removeItem(at: url)
    }

    static func writeResult(_ result: TranscriptionResult) -> Bool {
        guard let container = containerURL else { return false }
        let url = container.appendingPathComponent(resultFile)
        do {
            let data = try JSONEncoder().encode(result)
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            print("[SharedDefaults] writeResult failed: \(error)")
            return false
        }
    }

    static func readResult() -> TranscriptionResult? {
        guard let container = containerURL else { return nil }
        let url = container.appendingPathComponent(resultFile)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(TranscriptionResult.self, from: data)
    }

    static func clearResult() {
        guard let container = containerURL else { return }
        let url = container.appendingPathComponent(resultFile)
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Cleanup

    /// Remove audio files older than the given interval (default 1 hour).
    static func cleanupOldAudio(olderThan interval: TimeInterval = 3600) {
        guard let dir = audioDirectoryURL else { return }
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.creationDateKey]) else { return }
        let cutoff = Date().addingTimeInterval(-interval)
        for url in urls {
            if let values = try? url.resourceValues(forKeys: [.creationDateKey]),
               let created = values.creationDate, created < cutoff {
                try? fm.removeItem(at: url)
            }
        }
    }
}

// MARK: - Darwin Notification Helpers

/// Lightweight singleton for posting/observing Darwin notifications across processes.
final class DarwinNotificationCenter {

    static let shared = DarwinNotificationCenter()

    private var callbacks: [String: () -> Void] = [:]
    private let lock = NSLock()

    private init() {}

    /// Post a Darwin notification visible to all processes.
    func post(_ name: String) {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(center, CFNotificationName(name as CFString), nil, nil, true)
    }

    /// Observe a Darwin notification. Only one callback per name is kept.
    func observe(_ name: String, callback: @escaping () -> Void) {
        lock.lock()
        callbacks[name] = callback
        lock.unlock()

        let center = CFNotificationCenterGetDarwinNotifyCenter()
        // Remove existing observer for this name first
        CFNotificationCenterRemoveObserver(center, Unmanaged.passUnretained(self).toOpaque(),
                                           CFNotificationName(name as CFString), nil)
        CFNotificationCenterAddObserver(
            center,
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, notifName, _, _ in
                guard let notifName = notifName?.rawValue as String? else { return }
                DarwinNotificationCenter.shared.fire(notifName)
            },
            name as CFString,
            nil,
            .deliverImmediately
        )
    }

    /// Remove observer for a given notification name.
    func removeObserver(_ name: String) {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterRemoveObserver(center, Unmanaged.passUnretained(self).toOpaque(),
                                           CFNotificationName(name as CFString), nil)
        lock.lock()
        callbacks.removeValue(forKey: name)
        lock.unlock()
    }

    /// Remove all observers.
    func removeAll() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterRemoveEveryObserver(center, Unmanaged.passUnretained(self).toOpaque())
        lock.lock()
        callbacks.removeAll()
        lock.unlock()
    }

    private func fire(_ name: String) {
        lock.lock()
        let cb = callbacks[name]
        lock.unlock()
        DispatchQueue.main.async { cb?() }
    }
}
