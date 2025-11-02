//
//  SettingsView.swift
//  CardPulse
//
//  Created by Zhang Qichuan on 27/10/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("autoSyncWallet") private var autoSyncWallet = true
    @State private var showingImportPicker = false
    @State private var importMessage: String = ""
    @State private var showingImportAlert = false

    // Import preview states
    @State private var showingImportPreview = false
    @State private var importCSVContent = ""
    @State private var previewRows: [ImportPreviewRow] = []
    @State private var missingCardNames: [String] = []

    // Export preview states
    @State private var showingExportOptions = false
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var showingFilePicker = false
    @State private var csvToExport = ""
    @State private var exportFilename = "transactions_export.csv"
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // DATA MANAGEMENT Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("DATA MANAGEMENT")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal)
                        
                        VStack(spacing: 0) {
                            SettingsRow(
                                icon: "square.and.arrow.up",
                                title: "Import from CSV",
                                action: { showingImportPicker = true }
                            )
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                            
                            SettingsRow(
                                icon: "square.and.arrow.down",
                                title: "Export to CSV",
                                action: { showingExportOptions = true }
                            )
                        }
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    
                    // SUPPORT & ABOUT Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("SUPPORT & ABOUT")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal)
                        
                        VStack(spacing: 0) {
                            SettingsRow(
                                icon: "questionmark.circle",
                                title: "Help & FAQ",
                                action: {}
                            )
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                            
                            SettingsRow(
                                icon: "info.circle",
                                title: "About CardPulse",
                                action: {}
                            )
                        }
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 100)
            }
            .background(Color(red: 0.05, green: 0.1, blue: 0.2))
        }
        // Direct import (with preview)
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.commaSeparatedText, .plainText, .data],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
        // Import preview
        .sheet(isPresented: $showingImportPreview) {
            ImportPreviewView(
                rows: previewRows,
                missingCards: missingCardNames,
                onConfirm: {
                    TransactionManager(modelContext: modelContext).importFromCSV(importCSVContent)
                    importMessage = "CSV imported successfully."
                    showingImportAlert = true
                },
                onCancel: { }
            )
        }
        // Export options/preview
        .sheet(isPresented: $showingExportOptions) {
            ExportOptionsView(
                startDate: $startDate,
                endDate: $endDate,
                onExport: {
                    let mgr = TransactionManager(modelContext: modelContext)
                    csvToExport = mgr.exportToCSV(from: startDate, to: endDate)
                    exportFilename = "transactions_\(formatDate(startDate))_to_\(formatDate(endDate)).csv"
                    showingFilePicker = true
                }
            )
        }
        // Native document picker for saving CSV
        .sheet(isPresented: $showingFilePicker) {
            DocumentPickerView(
                csvContent: csvToExport,
                filename: exportFilename,
                onComplete: { _ in }
            )
        }
        .alert("Import Complete", isPresented: $showingImportAlert) {
            Button("OK") {}
        } message: {
            Text(importMessage)
        }
    }
}

// MARK: - Import Handling
private extension SettingsView {
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                guard url.startAccessingSecurityScopedResource() else {
                    importMessage = "Unable to access the selected file."
                    showingImportAlert = true
                    return
                }
                defer { url.stopAccessingSecurityScopedResource() }
                let csvContent = try String(contentsOf: url)
                // Build preview (header-aware parsing)
                let rawLines = csvContent.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                guard !rawLines.isEmpty else {
                    importMessage = "Empty file"
                    showingImportAlert = true
                    return
                }
                let headerFields = parseCSVLineLocal(rawLines[0]).map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                func idx(_ names: [String]) -> Int? {
                    for name in names { if let i = headerFields.firstIndex(of: name) { return i } }
                    return nil
                }
                let iMerchant = idx(["merchant", "merchant name"]) ?? 0
                let iAmount   = idx(["amount"]) ?? 1
                let iCategory = idx(["category"]) // optional
                let iCard     = idx(["card"]) // simplified
                let iDate     = idx(["date"]) ?? 3
                let iNote     = idx(["note"]) // optional

                var rows: [ImportPreviewRow] = []
                var cardNames: Set<String> = []
                for line in rawLines.dropFirst() {
                    let fields = parseCSVLineLocal(line)
                    if fields.count <= max(iMerchant, iAmount, iDate) { continue }
                    let merchant = fields.indices.contains(iMerchant) ? fields[iMerchant] : ""
                    let amount = fields.indices.contains(iAmount) ? fields[iAmount] : ""
                    let category = (iCategory != nil && fields.indices.contains(iCategory!)) ? fields[iCategory!] : ""
                    let card = (iCard != nil && fields.indices.contains(iCard!)) ? fields[iCard!] : ""
                    let date = fields.indices.contains(iDate) ? fields[iDate] : ""
                    let note = (iNote != nil && fields.indices.contains(iNote!)) ? fields[iNote!] : ""
                    rows.append(ImportPreviewRow(merchant: merchant, amount: amount, category: category, card: card, date: date, note: note))
                    if !card.isEmpty { cardNames.insert(card) }
                }

                let existingCards = try? modelContext.fetch(FetchDescriptor<Card>())
                let existingNames = Set((existingCards ?? []).map { $0.name })
                let missing = Array(cardNames.subtracting(existingNames)).sorted()

                previewRows = rows
                missingCardNames = missing
                importCSVContent = csvContent
                showingImportPreview = true
            } catch {
                importMessage = "Failed to import: \(error.localizedDescription)"
                showingImportAlert = true
            }
        case .failure(let error):
            importMessage = "Failed to select file: \(error.localizedDescription)"
            showingImportAlert = true
        }
    }

    func parseCSVLineLocal(_ line: String) -> [String] {
        var components: [String] = []
        var current = ""
        var inQuotes = false
        var i = line.startIndex
        while i < line.endIndex {
            let ch = line[i]
            if ch == "\"" {
                let next = line.index(after: i)
                if inQuotes && next < line.endIndex && line[next] == "\"" {
                    current.append("\"")
                    i = line.index(after: next)
                } else {
                    inQuotes.toggle()
                    i = next
                }
            } else if ch == "," && !inQuotes {
                components.append(current)
                current = ""
                i = line.index(after: i)
            } else {
                current.append(ch)
                i = line.index(after: i)
            }
        }
        components.append(current)
        return components
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .stroke(Color.teal, lineWidth: 1)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: icon)
                            .font(.headline)
                            .foregroundColor(.white)
                    )
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SettingsView()
}
