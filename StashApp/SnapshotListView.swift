import SwiftUI
import Charts

struct MonthlyCategoryTotal: Identifiable {
    var id = UUID()
    let month: String
    let category: String
    let total: Double
}

struct SnapshotListView: View {
    @StateObject private var storage = SnapshotStorage()
    @State private var showingSettings = false
    @State private var selectedSnapshot: Snapshot?
    @State private var showingErrorAlert = false
    @State private var errorAlertMessage = ""

    // New state variables for delete confirmation
    @State private var showingDeleteConfirmation = false
    @State private var snapshotsToDelete: IndexSet?

    var monthlyTotals: [MonthlyCategoryTotal] {
        let sortedSnapshots = storage.snapshots.sorted(by: { $0.date < $1.date })
        
        if sortedSnapshots.isEmpty {
            return [MonthlyCategoryTotal(month: "No Data", category: "No Data", total: 0)]
        }
        
        // Grouping by a sortable date string (YYYY-MM)
        let groupedByMonth = Dictionary(grouping: sortedSnapshots) { snapshot in
            snapshot.date.formatted(Date.FormatStyle().year(.defaultDigits).month(.twoDigits))
        }
        
        var totals: [MonthlyCategoryTotal] = []
        
        for (monthString, snapshotsInMonth) in groupedByMonth {
            let combinedAccounts = snapshotsInMonth.flatMap { $0.accounts }
            
            // Calculate total for each category
            let groupedByCategory = Dictionary(grouping: combinedAccounts) { account in
                account.category.rawValue
            }
            
            for (category, accountsInCategory) in groupedByCategory {
                let totalAmount = accountsInCategory.reduce(0) { $0 + $1.amount }
                totals.append(MonthlyCategoryTotal(month: monthString, category: category, total: totalAmount))
            }

            // Calculate overall monthly total and add it as a separate line
            let monthlyTotalAmount = combinedAccounts.reduce(0) { $0 + $1.amount }
            totals.append(MonthlyCategoryTotal(month: monthString, category: "Overall Total", total: monthlyTotalAmount))
        }
        
        // Sort by month string (now YYYY-MM), then by category
        return totals.sorted { (item1, item2) in
            if item1.month != item2.month {
                return item1.month < item2.month
            }
            return item1.category < item2.category
        }
    }

    var body: some View {
        NavigationView {
            VStack {
                Chart(monthlyTotals) { item in
                    LineMark(
                        x: .value("Month", item.month),
                        y: .value("Total", item.total),
                        series: .value("Category", item.category)
                    )
                    .symbol(by: .value("Category", item.category))
                    .foregroundStyle(by: .value("Category", item.category))
                }
                .chartXAxis {
                    AxisMarks(preset: .automatic) { value in
                        AxisValueLabel()
                        AxisGridLine()
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text(formattedValue(doubleValue))
                            }
                        }
                        AxisGridLine()
                    }
                }
                .frame(height: 200)
                .padding()
                
                let sortedSnapshots = storage.snapshots.sorted(by: { $0.date < $1.date })

                List {
                    // Note for swipe actions
                    Text("Swipe left to delete a snapshot, or swipe right to edit it.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .listRowSeparator(.hidden) // Hide separator for this text

                    ForEach(sortedSnapshots, id: \.id) { snapshot in
                        VStack(alignment: .leading) {
                            Text(snapshot.date, style: .date)
                                .font(.headline)
                            Text("Total: \(formattedValue(snapshot.total))")
                                .font(.subheadline)
                            
                            // Display account details
                            if !snapshot.accounts.isEmpty {
                                Text("Accounts:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                ForEach(snapshot.accounts) { account in
                                    HStack {
                                        Text(account.institution)
                                        Spacer()
                                        Text("\(account.category.rawValue): \(formattedValue(account.amount))")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                }
                            } else {
                                Text("No accounts recorded for this snapshot.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                        .swipeActions(edge: .leading) { // Swipe right for edit
                            Button {
                                selectedSnapshot = snapshot // Set selectedSnapshot to trigger sheet
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                    // Modified onDelete to show confirmation alert
                    .onDelete { offsets in
                        snapshotsToDelete = offsets
                        showingDeleteConfirmation = true
                    }
                }
                // Confirmation alert for deletion
                .alert("Delete Snapshot?", isPresented: $showingDeleteConfirmation) {
                    Button("Delete", role: .destructive) {
                        if let offsets = snapshotsToDelete {
                            storage.delete(at: offsets)
                        }
                        snapshotsToDelete = nil // Clear the stored offsets
                    }
                    Button("Cancel", role: .cancel) {
                        snapshotsToDelete = nil // Clear the stored offsets
                    }
                } message: {
                    Text("Are you sure you want to delete this snapshot? This action cannot be undone.")
                }

                NavigationLink(destination: AddSnapshotView(storage: storage)) {
                    Text("Add Savings Snapshot")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding()
            }
            .navigationTitle("Stash App")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(storage: storage)
            }
            .sheet(item: $selectedSnapshot) { snapshot in
                EditSnapshotView(storage: storage, snapshot: snapshot)
            }
            // Error alert
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK") { }
            } message: {
                Text(errorAlertMessage)
            }
            .onChange(of: storage.errorMessage) { newErrorMessage in
                if let message = newErrorMessage {
                    errorAlertMessage = message
                    showingErrorAlert = true
                }
            }
        }
    }

    // MARK: - Formatting Helpers

    func formattedValue(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = localeForCurrency(storage.currencySymbol)

        if formatter.currencySymbol != storage.currencySymbol {
            if storage.currencySymbol == "CHF" {
                formatter.currencySymbol = "CHF"
                formatter.currencyGroupingSeparator = "'"
                formatter.positiveSuffix = " CHF"
                formatter.negativeSuffix = " CHF"
            } else {
                formatter.currencySymbol = storage.currencySymbol + " "
            }
        }

        return formatter.string(from: NSNumber(value: value)) ?? "\(storage.currencySymbol) \(value)"
    }

    func localeForCurrency(_ symbol: String) -> Locale {
        switch symbol {
        case "€": return Locale(identifier: "fr_FR")
        case "£": return Locale(identifier: "en_GB")
        case "$": return Locale(identifier: "en_US")
        case "¥": return Locale(identifier: "ja_JP")
        case "₹": return Locale(identifier: "hi_IN")
        case "CHF": return Locale(identifier: "de_CH")
        default: return Locale.current
        }
    }
}
