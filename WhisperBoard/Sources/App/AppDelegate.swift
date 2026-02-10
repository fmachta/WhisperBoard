import UIKit

/// App delegate for handling system-level events.
/// Wired up via `@UIApplicationDelegateAdaptor` if needed in the future.
/// Currently, TranscriptionService is started directly in WhisperBoardApp.init().

class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Keep transcription service alive briefly for any in-progress work
        let taskID = application.beginBackgroundTask {
            // Expiration handler – nothing critical to do
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            application.endBackgroundTask(taskID)
        }
    }
}
