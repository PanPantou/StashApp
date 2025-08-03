import SwiftUI

struct EditSnapshotView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var storage: SnapshotStorage
    var snapshot: Snapshot

    @State private var date: Date
    @State private var accounts: [Snapshot.AccountBalance]

    let categories = Snapshot.AccountCategory.allCases

    init(storage: SnapshotStorage, snapshot: Snapshot) {
        self.storage = storage
        self.snapshot = snapshot
        _date = State(initialValue: snapshot.date)
        _accounts = State(initialValue: snapshot.accounts)
    }

    var body: some View {
        NavigationView {
            Form {
                DatePicker("Date", selection: $date, displayedComponents: .date)

                Section(header: Text("Accounts")) {
                    Text("Swipe left on an account to delete it.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(accounts.indices, id: \.self) { index in
                        VStack(alignment: .leading) {
                            TextField("Institution", text: $accounts[index].institution)

                            TextField("Amount", value: $accounts[index].amount, format: .number)
                                .keyboardType(.decimalPad)

                            Picker("Category", selection: $accounts[index].category) {
                                ForEach(categories) { cat in
                                    Text(cat.rawValue).tag(cat)
                                }
                            }
                        }
                        .padding(.vertical, 5)
                    }
                    .onDelete { offsets in
                        accounts.remove(atOffsets: offsets)
                    }

                    Button("Add Account") {
                        accounts.append(Snapshot.AccountBalance(institution: "", amount: 0, category: .savings))
                    }
                }
            }
            .navigationTitle("Edit Snapshot")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func saveChanges() {
        let updated = Snapshot(id: snapshot.id, date: date, accounts: accounts)
        storage.update(snapshot: updated)
    }
}
