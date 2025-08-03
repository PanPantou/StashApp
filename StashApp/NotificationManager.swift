import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    
    // Private initializer to ensure singleton pattern
    private init() {}

    func scheduleNotification(for frequency: ReminderFrequency) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        guard frequency != .none else { return }

        let content = UNMutableNotificationContent()
        content.title = "Log Your Savings 💰"
        content.body = "Don't forget to take your savings snapshot!"
        content.sound = .default

        var trigger: UNNotificationTrigger?

        switch frequency {
        case .weekly:
            var dateComponents = DateComponents()
            dateComponents.weekday = 2 // Monday
            dateComponents.hour = 9    // 9 AM
            dateComponents.minute = 0  // 0 minutes
            trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        case .biweekly:
            // For bi-weekly, UNTimeIntervalNotificationTrigger is still the most straightforward
            // if we don't want to manage specific dates to ensure exact bi-weekly intervals
            // across month boundaries.
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60 * 60 * 24 * 14, repeats: true)
        case .monthly:
            var dateComponents = DateComponents()
            dateComponents.day = 1 // 1st day of the month
            dateComponents.hour = 9 // 9 AM
            dateComponents.minute = 0 // 0 minutes
            trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        case .none:
            return // No notification needed
        }

        if let trigger = trigger {
            let request = UNNotificationRequest(identifier: "snapshotReminder", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error scheduling notification: \(error.localizedDescription)")
                }
            }
        }
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Error requesting notification permission: \(error.localizedDescription)")
            }
            print("Notification permission granted: \(granted)")
        }
    }
}
