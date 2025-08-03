import SwiftUI

@main
struct StashApp: App {
    
    init() {
        // Notification permission request is now handled within SnapshotStorage init
        // to ensure it's requested when the storage is ready and frequency is loaded.
    }

    var body: some Scene {
        WindowGroup {
            SnapshotListView()
        }
    }
}
