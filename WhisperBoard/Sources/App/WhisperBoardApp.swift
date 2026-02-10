import SwiftUI

@main
struct WhisperBoardApp: App {

    init() {
        // Start the transcription service so it's ready for keyboard requests
        TranscriptionService.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
