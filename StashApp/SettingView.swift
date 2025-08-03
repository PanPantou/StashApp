import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var storage: SnapshotStorage
    @State private var showingAlert = false

    let currencies = ["£", "€", "$", "¥", "₹", "CHF"]

    var body: some View {
        NavigationView {
            Form {
                // Currency Picker
                Section {
                    Picker("Currency", selection: $storage.currencySymbol) {
                        ForEach(currencies, id: \.self) { symbol in
                            Text(symbol)
                        }
                    }
                }

                // Reminder Frequency Picker
                Section(header: Text("Reminders")) {
                    Picker("Reminder", selection: $storage.reminderFrequency) {
                        ForEach(ReminderFrequency.allCases) { freq in
                            Text(freq.rawValue.capitalized)
                                .tag(freq)
                        }
                    }
                }

                // Import from CSV
                Section(header: Text("Data Management")) {
                    CSVImporterView(storage: storage)
                }

                // Buy Me a Coffee Section
                Section {
                    Text("Hey! If you’re vibin’ with Stash App and it’s helping you boss up your savings, feel free to buy me a coffee ☕️ — totally chill if not, no perks unlocked or anything. Thanks a ton for the support!")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.vertical)

                    Button(action: {
                        showingAlert = true
                    }) {
                        HStack {
                            Image(systemName: "cup.and.saucer.fill")
                                .foregroundColor(.orange)
                            Text("Buy Me a Coffee")
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .alert("Support Stash App?", isPresented: $showingAlert) {
                        Button("Yes") { openBuyMeACoffee() }
                        Button("No", role: .cancel) {}
                    } message: {
                        Text("Would you like to open the Buy Me a Coffee page?")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Label("Back", systemImage: "chevron.left")
                    }
                }
            }
        }
    }

    private func openBuyMeACoffee() {
        if let url = URL(string: "https://coff.ee/panpantou") {
            #if canImport(UIKit)
            UIApplication.shared.open(url)
            #endif
        }
    }
}
