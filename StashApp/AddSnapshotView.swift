import SwiftUI

struct AddSnapshotView: View {
    @ObservedObject var storage: SnapshotStorage
    @State private var accounts: [Snapshot.AccountBalance] = []
    @State private var newInstitution = ""
    @State private var newAmount = ""
    @State private var newCategory: Snapshot.AccountCategory = .savings
    @State private var snapshotDate = Date()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        Form {
            Section(header: Text("New Account")) {
                TextField("Institution", text: $newInstitution)

                TextField("Amount", text: $newAmount)
                    .keyboardType(.decimalPad)

                Picker("Category", selection: $newCategory) {
                    ForEach(Snapshot.AccountCategory.allCases) { category in
                        Text(category.rawValue).tag(category)
                    }
                }

                Button("Add Account") {
                    if let amount = Double(newAmount), !newInstitution.isEmpty {
                        let account = Snapshot.AccountBalance(
                            institution: newInstitution,
                            amount: amount,
                            category: newCategory
                        )
                        accounts.append(account)
                        newInstitution = ""
                        newAmount = ""
                        newCategory = .savings
                    }
                }
            }

            DatePicker("Snapshot Date", selection: $snapshotDate, displayedComponents: .date)

            Section(header: Text("Accounts")) {
                if !accounts.isEmpty {
                    Text("Swipe left on an account to delete it.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                ForEach(accounts) { account in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(account.institution)
                            Text(account.category.rawValue)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Text("\(storage.currencySymbol)\(account.amount, specifier: "%.2f")")
                    }
                }
                .onDelete { offsets in
                    accounts.remove(atOffsets: offsets)
                }
            }

            Button("Save Snapshot") {
                let snapshot = Snapshot(date: snapshotDate, accounts: accounts)
                storage.add(snapshot: snapshot)
                dismiss()
            }
        }
        .navigationTitle("Add Snapshot")
    }
}
