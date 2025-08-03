import SwiftUI
import Charts

struct SnapshotCategoryPoint: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let category: String
    let amount: Double
}

struct SnapshotListView: View {
    @StateObject private var storage = SnapshotStorage()
    @State private var showingSettings = false
    @State private var selectedSnapshot: Snapshot?
    @State private var showingErrorAlert = false
    @State private var errorAlertMessage = ""

    // State variables for delete confirmation
    @State private var showingDeleteConfirmation = false
    @State private var snapshotsToDelete: IndexSet?

    // State for chart interactivity
    @State private var showOverallTotal = true
    @State private var selectedDate: Date?
    @State private var selectedCategoryValues: [String: Double] = [:]

    var snapshotDataPoints: [SnapshotCategoryPoint] {
        var activeCategories = Set<Snapshot.AccountCategory>()
        var points = [SnapshotCategoryPoint]()
        
        let sortedSnapshots = storage.snapshots.sorted(by: { $0.date < $1.date })

        for snapshot in sortedSnapshots {
            let categoriesInThisSnapshot = Set(snapshot.accounts.map { $0.category })
            activeCategories.formUnion(categoriesInThisSnapshot)

            for category in activeCategories {
                let totalForCategory = snapshot.accounts
                    .filter { $0.category == category }
                    .reduce(0) { $0 + $1.amount }
                points.append(SnapshotCategoryPoint(date: snapshot.date, category: category.rawValue, amount: totalForCategory))
            }
            
            if showOverallTotal {
                points.append(SnapshotCategoryPoint(date: snapshot.date, category: "Overall Total", amount: snapshot.total))
            }
        }
        
        return points
    }
    
    // Custom color for each category
    func colorForCategory(_ category: String) -> Color {
        switch category {
        case "Savings": return .green
        case "Stocks & Shares": return .orange
        case "Crypto": return .purple
        case "Current Account": return .red
        case "Overall Total": return .blue
        default: return .gray
        }
    }

    var body: some View {
        NavigationView {
            VStack {
                VStack {
                    Chart(snapshotDataPoints) { item in
                        LineMark(
                            x: .value("Date", item.date),
                            y: .value("Amount", item.amount),
                            series: .value("Category", item.category)
                        )
                        .foregroundStyle(colorForCategory(item.category))
                        .symbol(by: .value("Category", item.category))
                        
                        if let selectedDate, Calendar.current.isDate(selectedDate, inSameDayAs: item.date) {
                            RuleMark(x: .value("Selected Date", selectedDate))
                                .foregroundStyle(Color.gray.opacity(0.5))
                                .zIndex(-1)
                                .annotation(position: .top, alignment: .center) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(selectedDate, style: .date)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        ForEach(selectedCategoryValues.sorted(by: { $0.key < $1.key }), id: \.key) { category, value in
                                            HStack {
                                                Circle()
                                                    .fill(colorForCategory(category))
                                                    .frame(width: 8, height: 8)
                                                Text("\(category): \(formattedValue(value))")
                                                    .font(.caption)
                                            }
                                        }
                                    }
                                    .padding(8)
                                    .background(Color(.systemBackground).opacity(0.8))
                                    .cornerRadius(8)
                                    .shadow(radius: 2)
                                }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(preset: .automatic, values: .stride(by: .month)) { value in
                            AxisValueLabel(format: .dateTime.month(.abbreviated))
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
                    .chartOverlay { proxy in
                        GeometryReader { geometry in
                            Rectangle().fill(.clear).contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            let location = value.location
                                            if let date: Date = proxy.value(atX: location.x) {
                                                updateSelection(for: date)
                                            }
                                        }
                                        .onEnded { _ in
                                            selectedDate = nil
                                        }
                                )
                        }
                    }
                    .frame(height: 200)
                    .padding(.horizontal)
                    
                    Toggle(isOn: $showOverallTotal.animation()) {
                        Text("Show Overall Total")
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
                
                let sortedSnapshots = storage.snapshots.sorted(by: { $0.date < $1.date })

                List {
                    // Note for swipe actions
                    Text("Swipe left to delete a snapshot, or swipe right to edit it.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .listRowSeparator(.hidden)

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
                        .swipeActions(edge: .leading) {
                            Button {
                                selectedSnapshot = snapshot
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                    .onDelete { offsets in
                        snapshotsToDelete = offsets
                        showingDeleteConfirmation = true
                    }
                }
                .alert("Delete Snapshot?", isPresented: $showingDeleteConfirmation) {
                    Button("Delete", role: .destructive) {
                        if let offsets = snapshotsToDelete {
                            let sortedSnapshots = storage.snapshots.sorted(by: { $0.date < $1.date })
                            let snapshotsToDeleteFromView = offsets.map { sortedSnapshots[$0] }
                            
                            var indicesToDeleteInStorage = IndexSet()
                            for snapshot in snapshotsToDeleteFromView {
                                if let index = storage.snapshots.firstIndex(where: { $0.id == snapshot.id }) {
                                    indicesToDeleteInStorage.insert(index)
                                 }
                            }
                            
                            if !indicesToDeleteInStorage.isEmpty {
                                storage.delete(at: indicesToDeleteInStorage)
                            }
                        }
                        snapshotsToDelete = nil
                    }
                    Button("Cancel", role: .cancel) {
                        snapshotsToDelete = nil
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

    private func updateSelection(for date: Date) {
        // Find the closest snapshot date to the dragged date
        let closestSnapshot = storage.snapshots.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
        
        guard let snapshot = closestSnapshot else { return }
        
        self.selectedDate = snapshot.date
        
        var values: [String: Double] = [:]
        
        let activeCategories = Set(snapshotDataPoints.map { $0.category })
        
        for category in activeCategories where category != "Overall Total" {
            let totalForCategory = snapshot.accounts
                .filter { $0.category.rawValue == category }
                .reduce(0) { $0 + $1.amount }
            values[category] = totalForCategory
        }

        if showOverallTotal {
            values["Overall Total"] = snapshot.total
        }
        
        self.selectedCategoryValues = values
    }

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
