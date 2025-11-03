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
    @State private var importProgressText = ""
    @State private var showingHowToAutoTracking = false
    
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
                                    title: "How to setup automatic wallet transaction tracking?",
                                    action: { showingHowToAutoTracking = true }
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
                    message: "Importing...",
                    progress: nil
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
        // How-to carousel
        .sheet(isPresented: $showingHowToAutoTracking) {
            HowToAutoTrackingView()
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
        importProgressText = "Starting import..."
        
        // Close the preview sheet
        showingImportPreview = false
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Build a cache of cards by name via Utils (prefetch existing and pre-create missing)
        let nameToCard: [String: Card] = ImportExportUtils.precreateAndMapCards(missingCardNames: missingCardNames, modelContext: modelContext)
        
        do {
            let processedCount = try ImportExportUtils.importCSV(content: importCSVContent, nameToCard: nameToCard, modelContext: modelContext)
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
        csvToExport = ImportExportUtils.exportCSV(modelContext: modelContext, from: startDate, to: endDate)
        exportFilename = "transactions_\(ImportExportUtils.formatDate(startDate))_to_\(ImportExportUtils.formatDate(endDate)).csv"
        
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
                let preview = ImportExportUtils.buildImportPreview(from: csvContent, modelContext: modelContext)
                previewRows = preview.rows
                missingCardNames = preview.missingCards
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
