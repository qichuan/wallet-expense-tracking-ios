//
//  ImportPreviewView.swift
//  CardPulse
//

import SwiftUI

struct ImportPreviewRow: Identifiable {
    let id = UUID()
    let merchant: String
    let amount: String
    let category: String
    let card: String
    let date: String
    let note: String
}

struct ImportPreviewView: View {
    let rows: [ImportPreviewRow]
    let missingCards: [String]
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                if !missingCards.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cards to be created")
                            .font(.headline)
                            .foregroundColor(.white)
                        ForEach(missingCards, id: \.self) { name in
                            Text(name)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                
                Text("Transactions to import: \(rows.count)")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                List {
                    ForEach(rows) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(row.merchant)
                                    .font(.headline)
                                Spacer()
                                Text("$\(row.amount)")
                            }
                            .foregroundColor(.white)
                            Text("\(row.category) • \(row.card)")
                                .foregroundColor(.white.opacity(0.8))
                                .font(.caption)
                            Text(row.date)
                                .foregroundColor(.white.opacity(0.7))
                                .font(.caption)
                            if !row.note.isEmpty {
                                Text(row.note)
                                    .foregroundColor(.white.opacity(0.9))
                                    .font(.caption)
                            }
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                
                HStack {
                    Button("Cancel") { onCancel(); dismiss() }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    Button("Import") { onConfirm(); dismiss() }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.teal)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding()
            .background(Color(red: 0.05, green: 0.1, blue: 0.2))
            .navigationTitle("Import Preview")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}


