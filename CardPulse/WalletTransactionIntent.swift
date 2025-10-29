//
//  WalletTransactionIntent.swift
//  CardPulse
//
//  Created by Zhang Qichuan on 27/10/25.
//

import Foundation
import AppIntents
import SwiftData

@available(iOS 16.0, *)
struct WalletTransactionIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Wallet Transaction"
    static var description = IntentDescription("Automatically log a transaction from Wallet")
    
    @Parameter(title: "Merchant Name")
    var merchantName: String
    
    @Parameter(title: "Amount")
    var amount: Double
    
    @Parameter(title: "Card Name")
    var cardName: String
    
    @Parameter(title: "Transaction Date")
    var transactionDate: Date
    
    @Parameter(title: "Category")
    var category: String?
    
    static var parameterSummary: some ParameterSummary {
        Summary("Log transaction from \(\.$merchantName) for \(\.$amount) using \(\.$cardName)")
    }
    
    func perform() async throws -> some IntentResult {
        // This would typically interact with your SwiftData model
        // For now, we'll just return a success result
        // In a real implementation, you'd save the transaction to your database
        
        return .result()
    }
}

@available(iOS 16.0, *)
struct LogWalletTransactionIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Wallet Transaction"
    static var description = IntentDescription("Log a transaction from Wallet tap")
    
    @Parameter(title: "Merchant", description: "Name of the merchant")
    var merchant: String
    
    @Parameter(title: "Amount", description: "Transaction amount")
    var amount: Double
    
    @Parameter(title: "Card", description: "Card name or last 4 digits")
    var card: String
    
    @Parameter(title: "Date", description: "Transaction date")
    var date: Date
    
    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$merchant) transaction for $\(\.$amount) on \(\.$card)")
    }
    
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // In a real implementation, this would:
        // 1. Find the matching card in your database
        // 2. Create a new transaction record
        // 3. Update the card's current spent amount
        // 4. Return a confirmation message
        
        let message = "Transaction logged: \(merchant) - $\(String(format: "%.2f", amount))"
        
        return .result(value: message)
    }
}
