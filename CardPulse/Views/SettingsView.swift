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
    @State private var isExporting = false
    @State private var showingExportCompleteAlert = false
    @State private var exportCompleteMessage = ""
    
    // Import progress states
    @State private var isImporting = false
    @State private var importProgress: Double = 0.0
    @State private var importProgressText = ""
    
    var body: some View {
        ZStack {
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
            
            // Export progress overlay
            if isExporting {
                ProgressOverlay(
                    title: "Exporting CSV",
                    message: "Preparing export...",
                    progress: nil
                )
                .transition(.opacity)
                .zIndex(9999)
                .allowsHitTesting(true)
            }
            
            // Import progress overlay
            if isImporting {
                ProgressOverlay(
                    title: "Importing CSV",
                    message: importProgressText,
                    progress: importProgress
                )
                .transition(.opacity)
                .zIndex(9999)
                .allowsHitTesting(true)
            }
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
                    Task {
                        await performImport()
                    }
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
                    Task {
                        await performExport()
                    }
                }
            )
        }
        // Native document picker for saving CSV
        .sheet(isPresented: $showingFilePicker) {
            DocumentPickerView(
                csvContent: csvToExport,
                filename: exportFilename,
                onComplete: { result in
                    switch result {
                    case .success:
                        exportCompleteMessage = "CSV file exported successfully!"
                        showingExportCompleteAlert = true
                    case .failure(let error):
                        if (error as NSError).code != -2 { // -2 is user cancellation, don't show error
                            exportCompleteMessage = "Export completed. File saved."
                            showingExportCompleteAlert = true
                        }
                    }
                }
            )
        }
        .alert("Import Complete", isPresented: $showingImportAlert) {
            Button("OK") {}
        } message: {
            Text(importMessage)
        }
        .alert("Export Complete", isPresented: $showingExportCompleteAlert) {
            Button("OK") {}
        } message: {
            Text(exportCompleteMessage)
        }
    }
}

// MARK: - Import/Export Handling
private extension SettingsView {
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    @MainActor
    func performImport() async {
        isImporting = true
        importProgress = 0.0
        importProgressText = "Starting import..."
        
        // Close the preview sheet
        showingImportPreview = false
        
        let lines = importCSVContent.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let totalLines = max(lines.count - 1, 1) // Exclude header
        var processedCount = 0
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        for (index, line) in lines.enumerated() {
            if index == 0 || line.isEmpty { continue } // Skip header
            
            // Process line
            let components = parseCSVLineLocal(line)
            guard components.count >= 5 else { continue }
            
            let merchant = components[0]
            let amountString = components[1]
            let category = components[2].isEmpty ? nil : components[2]
            let cardName = components[3]
            let dateString = components[4]
            let note = components.count > 5 ? components[5] : nil
            
            guard let amount = Decimal(string: amountString),
                  let date = dateFormatter.date(from: dateString) else { continue }
            
            var matchedCard: Card? = nil
            if !cardName.isEmpty {
                let cardRequest = FetchDescriptor<Card>(
                    predicate: #Predicate { card in
                        card.name == cardName
                    }
                )
                if let found = try? modelContext.fetch(cardRequest).first {
                    matchedCard = found
                } else {
                    let newCard = Card(
                        name: cardName,
                        minimumSpendingAmount: 0,
                        hasMinimumSpending: false,
                        rewardType: .none
                    )
                    modelContext.insert(newCard)
                    matchedCard = newCard
                }
            }
            
            let transaction = Transaction(
                merchant: merchant,
                amount: amount,
                date: date,
                category: category,
                note: note,
                card: matchedCard
            )
            modelContext.insert(transaction)
            
            processedCount += 1
            importProgress = Double(processedCount) / Double(totalLines)
            importProgressText = "Importing transaction \(processedCount) of \(totalLines)..."
            
            // Allow UI updates every 10 transactions or at the end
            if processedCount % 10 == 0 || processedCount == totalLines {
                try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
            }
        }
        
        do {
            try modelContext.save()
            importProgress = 1.0
            importProgressText = "Import completed!"
            importMessage = "Successfully imported \(processedCount) transactions."
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            isImporting = false
            showingImportAlert = true
        } catch {
            importMessage = "Error saving: \(error.localizedDescription)"
            isImporting = false
            showingImportAlert = true
        }
    }
    
    @MainActor
    func performExport() async {
        // Close the export options sheet first
        showingExportOptions = false
        
        // Wait for sheet to fully dismiss
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Now show progress overlay after sheet is dismissed
        withAnimation {
            isExporting = true
        }
        
        // Small delay to ensure overlay is visible
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Generate CSV
        let mgr = TransactionManager(modelContext: modelContext)
        csvToExport = mgr.exportToCSV(from: startDate, to: endDate)
        exportFilename = "transactions_\(formatDate(startDate))_to_\(formatDate(endDate)).csv"
        
        // Verify CSV was generated
        guard !csvToExport.isEmpty else {
            withAnimation {
                isExporting = false
            }
            importMessage = "No transactions found to export."
            showingImportAlert = true
            return
        }
        
        // Small delay to show progress before showing file picker
        try? await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
        
        withAnimation {
            isExporting = false
        }
        
        // Wait a bit more before showing file picker to ensure overlay dismisses
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        showingFilePicker = true
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

struct ProgressOverlay: View {
    let title: String
    let message: String
    let progress: Double?
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                if let progress = progress {
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .teal))
                        .frame(width: 200)
                    
                    Text("\(Int(progress * 100))%")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                } else {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.teal)
                }
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(24)
            .background(Color(red: 0.05, green: 0.1, blue: 0.2))
            .cornerRadius(16)
            .shadow(radius: 10)
        }
    }
}

#Preview {
    SettingsView()
}
