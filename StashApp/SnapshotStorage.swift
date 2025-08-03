import Foundation
import UserNotifications // Import UserNotifications for NotificationManager

enum ReminderFrequency: String, CaseIterable, Codable, Identifiable {
    case none
    case weekly
    case biweekly
    case monthly

    var id: String { self.rawValue }
}

class SnapshotStorage: ObservableObject {
    @Published var snapshots: [Snapshot] = []
    @Published var errorMessage: String? // New property for error messages

    @Published var currencySymbol: String {
        didSet {
            UserDefaults.standard.set(currencySymbol, forKey: "currencySymbol")
        }
    }

    @Published var reminderFrequency: ReminderFrequency {
        didSet {
            saveFrequency()
            NotificationManager.shared.scheduleNotification(for: reminderFrequency)
        }
    }

    init() {
        self.currencySymbol = UserDefaults.standard.string(forKey: "currencySymbol") ?? "£"
        self.reminderFrequency = {
            if let rawValue = UserDefaults.standard.string(forKey: "reminderFrequency"),
               let frequency = ReminderFrequency(rawValue: rawValue) {
                return frequency
            }
            return .none
        }()
        load()
        // Request notification permission when the storage is initialized
        NotificationManager.shared.requestPermission()
    }

    func add(snapshot: Snapshot) {
        snapshots.append(snapshot)
        save()
    }

    func delete(at offsets: IndexSet) {
        snapshots.remove(atOffsets: offsets)
        save()
    }
    
    func update(snapshot: Snapshot) {
        if let index = snapshots.firstIndex(where: { $0.id == snapshot.id }) {
            snapshots[index] = snapshot
            save()
        }
    }
    
    private func save() {
        let url = getDocumentsDirectory().appendingPathComponent("snapshots.json")
        DispatchQueue.global(qos: .background).async {
            do {
                let data = try JSONEncoder().encode(self.snapshots)
                try data.write(to: url)
                // Clear error message on successful save
                DispatchQueue.main.async {
                    self.errorMessage = nil
                }
            } catch {
                print("Failed to save snapshots:", error)
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to save data: \(error.localizedDescription)"
                }
            }
        }
    }

    private func load() {
        let url = getDocumentsDirectory().appendingPathComponent("snapshots.json")
        DispatchQueue.global(qos: .background).async {
            do {
                let data = try Data(contentsOf: url)
                let loaded = try JSONDecoder().decode([Snapshot].self, from: data)
                DispatchQueue.main.async {
                    self.snapshots = loaded
                    self.errorMessage = nil // Clear error message on successful load
                }
            } catch {
                print("Failed to load snapshots:", error)
                DispatchQueue.main.async {
                    // Only set error message if it's not a "file not found" error for initial load
                    if !(error is CocoaError && (error as! CocoaError).errorCode == 260) { // 260 is NSFileReadNoSuchFileError
                        self.errorMessage = "Failed to load data: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    private func saveFrequency() {
        UserDefaults.standard.set(reminderFrequency.rawValue, forKey: "reminderFrequency")
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
