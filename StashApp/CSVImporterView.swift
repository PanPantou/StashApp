import SwiftUI

struct CSVImporterView: View {
    @ObservedObject var storage: SnapshotStorage
    @State private var isImporterPresented = false
    @State private var importMessage = ""
    @State private var isAlertPresented = false

    var body: some View {
        Button("Import from CSV") {
            isImporterPresented = true
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            do {
                guard let selectedFile: URL = try result.get().first else { return }
                let csvData = try String(contentsOf: selectedFile)
                let snapshots = try parseCSV(data: csvData)
                storage.add(snapshots: snapshots)
                importMessage = "Successfully imported \(snapshots.count) snapshots."
            } catch {
                importMessage = "Error importing file: \(error.localizedDescription)"
            }
            isAlertPresented = true
        }
        .alert(isPresented: $isAlertPresented) {
            Alert(title: Text("Import"), message: Text(importMessage), dismissButton: .default(Text("OK")))
        }
    }

    private func parseCSV(data: String) throws -> [Snapshot] {
        var snapshotsByDate = [Date: [Snapshot.AccountBalance]]()
        let rows = data.components(separatedBy: "\n").dropFirst() // Drop header row

        for row in rows {
            let columns = row.components(separatedBy: ",")
            if columns.count == 4 {
                guard let date = DateFormatter.csvDateFormatter.date(from: columns[0]),
                      let amount = Double(columns[2]),
                      let category = Snapshot.AccountCategory(rawValue: columns[3]) else {
                    continue
                }
                let account = Snapshot.AccountBalance(institution: columns[1], amount: amount, category: category)
                snapshotsByDate[date, default: []].append(account)
            }
        }

        return snapshotsByDate.map { Snapshot(date: $0.key, accounts: $0.value) }
    }
}

extension DateFormatter {
    static let csvDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
