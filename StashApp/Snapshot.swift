import Foundation

struct Snapshot: Identifiable, Codable, Equatable {
    var id = UUID()
    var date: Date
    var accounts: [AccountBalance]
    
    var total: Double {
        accounts.reduce(0) { $0 + $1.amount }
    }

    struct AccountBalance: Identifiable, Codable, Equatable {
        var id = UUID()
        var institution: String
        var amount: Double
        var category: AccountCategory
    }

    enum AccountCategory: String, CaseIterable, Codable, Identifiable {
        case crypto = "Crypto"
        case savings = "Savings"
        case stocks = "Stocks & Shares"
        case current = "Current Account"

        var id: String { rawValue }
    }
}
