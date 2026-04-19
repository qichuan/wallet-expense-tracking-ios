//
//  SettingsView.swift
//  CardPulse
//
//  Created by Zhang Qichuan on 27/10/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("autoSyncWallet") private var autoSyncWallet = true
    @AppStorage("defaultCurrency") private var defaultCurrencyCode = "SGD"
    @AppStorage("enabledCurrencies") private var enabledCurrenciesRaw = "SGD,MYR,HKD,USD,EUR"
    @AppStorage("customCurrenciesRaw") private var customCurrenciesRaw = ""
    @AppStorage("exchangeRates") private var exchangeRatesData: Data = Data()
    @State private var showingCurrencyManager = false
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
                        
                        // CURRENCY Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("CURRENCY")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal)

                            VStack(spacing: 0) {
                                // Default currency picker
                                HStack(spacing: 12) {
                                    Circle()
                                        .stroke(Color.teal, lineWidth: 1)
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Image(systemName: "dollarsign.circle")
                                                .font(.headline)
                                                .foregroundColor(.white)
                                        )

                                    Text("Default Currency")
                                        .font(.headline)
                                        .foregroundColor(.white)

                                    Spacer()

                                    Picker("", selection: $defaultCurrencyCode) {
                                        ForEach(enabledCurrencyList, id: \.code) { info in
                                            Text(info.code).tag(info.code)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .accentColor(.teal)
                                }
                                .padding()

                                Divider()
                                    .background(Color.white.opacity(0.1))

                                SettingsRow(
                                    icon: "list.bullet",
                                    title: "Manage Currencies",
                                    action: { showingCurrencyManager = true }
                                )
                            }
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }

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
                            Text("SUPPORT")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal)
                            
                            VStack(spacing: 0) {
                                SettingsRow(
                                    icon: "questionmark.circle",
                                    title: "How to set up an automation in Shortcuts app to track wallet transactions?",
                                    action: { showingHowToAutoTracking = true }
                                )
                                
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                
                                SettingsRow(
                                    icon: "envelope",
                                    title: "Contact the Developer",
                                    action: { openEmail() }
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
        // Currency manager
        .sheet(isPresented: $showingCurrencyManager) {
            CurrencyManagerView(
                enabledCurrenciesRaw: $enabledCurrenciesRaw,
                customCurrenciesRaw: $customCurrenciesRaw,
                defaultCurrencyCode: $defaultCurrencyCode
            )
        }
        .onChange(of: defaultCurrencyCode) { _, newDefault in
            // Rates are relative to the default currency — clear stale cache so views
            // immediately fall back to raw amounts, then re-fetch against the new default.
            exchangeRatesData = (try? JSONEncoder().encode([String: Double]())) ?? Data()
            CurrencyUtils.saveRates([:], baseCurrency: newDefault)
            Task {
                let codes = CurrencyUtils.enabledCurrencies(
                    fromRaw: enabledCurrenciesRaw, customRaw: customCurrenciesRaw
                ).map { $0.code }
                if let fetched = await CurrencyUtils.fetchRates(for: codes, to: newDefault) {
                    CurrencyUtils.saveRates(fetched, baseCurrency: newDefault)
                    if let data = try? JSONEncoder().encode(fetched) {
                        exchangeRatesData = data
                    }
                }
            }
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

// MARK: - Currency Helpers
private extension SettingsView {
    var enabledCurrencyList: [CurrencyInfo] {
        CurrencyUtils.enabledCurrencies(fromRaw: enabledCurrenciesRaw, customRaw: customCurrenciesRaw)
    }
}

// MARK: - Import/Export Handling
private extension SettingsView {
    func openEmail() {
        let email = "qichuan@zhangqichuan.com"
        let subject = "Feedback for CardPulse"
        let subjectEncoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let mailtoURLString = "mailto:\(email)?subject=\(subjectEncoded)"
        
        if let url = URL(string: mailtoURLString) {
            UIApplication.shared.open(url)
        }
    }
    
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

// MARK: - Currency Manager Sheet

struct CurrencyManagerView: View {
    @Binding var enabledCurrenciesRaw: String
    @Binding var customCurrenciesRaw: String
    @Binding var defaultCurrencyCode: String
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddCurrency = false

    // Exchange rate state — rates are [fromCode: rateToDefault]
    @AppStorage("exchangeRates") private var exchangeRatesData: Data = Data()
    @State private var rates: [String: Double] = [:]
    @State private var isFetchingRates = false
    @State private var lastFetched: Date? = CurrencyUtils.exchangeRatesFetchedAt
    // Transient edit buffer: code → text while user is typing
    @State private var rateEditBuffer: [String: String] = [:]

    private var enabledCodes: Set<String> {
        Set(enabledCurrenciesRaw.components(separatedBy: ",").filter { !$0.isEmpty })
    }

    private var parsedCustomCurrencies: [CurrencyInfo] {
        CurrencyUtils.parseCustomCurrencies(fromRaw: customCurrenciesRaw)
    }

    /// Enabled non-default currencies that need exchange rates shown.
    private var foreignEnabledCurrencies: [CurrencyInfo] {
        CurrencyUtils.enabledCurrencies(fromRaw: enabledCurrenciesRaw, customRaw: customCurrenciesRaw)
            .filter { $0.code != defaultCurrencyCode }
    }

    var body: some View {
        NavigationView {
            List {
                // MARK: Exchange Rates section
                if !foreignEnabledCurrencies.isEmpty {
                    Section(header: ratesSectionHeader) {
                        ForEach(foreignEnabledCurrencies) { info in
                            rateRow(info)
                        }
                    }
                }

                // MARK: Built-in currencies
                Section("Built-in") {
                    ForEach(CurrencyUtils.allCurrencies) { info in
                        currencyRow(info)
                    }
                }

                // MARK: Custom currencies
                Section(header: HStack {
                    Text("Custom")
                    Spacer()
                    Button {
                        showingAddCurrency = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.teal)
                    }
                    .buttonStyle(.plain)
                }) {
                    if parsedCustomCurrencies.isEmpty {
                        Text("Tap + to add a custom currency")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.4))
                            .listRowBackground(Color(red: 0.05, green: 0.1, blue: 0.2))
                    } else {
                        ForEach(parsedCustomCurrencies) { info in
                            currencyRow(info)
                        }
                        .onDelete(perform: deleteCustom)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(red: 0.05, green: 0.1, blue: 0.2))
            .navigationTitle("Manage Currencies")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingAddCurrency) {
                AddCurrencyView(
                    enabledCurrenciesRaw: $enabledCurrenciesRaw,
                    customCurrenciesRaw: $customCurrenciesRaw,
                    onAdded: { code in Task { await fetchRateForCurrency(code) } }
                )
            }
            .onAppear {
                rates = CurrencyUtils.cachedRates
                lastFetched = CurrencyUtils.exchangeRatesFetchedAt
                if CurrencyUtils.ratesNeedRefresh {
                    Task { await fetchRates() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Rate section header

    @ViewBuilder
    private var ratesSectionHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Exchange Rates")
                if isFetchingRates {
                    Text("Fetching latest rates...")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                } else if let fetched = lastFetched {
                    Text("Updated \(fetched, style: .relative) ago")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            Spacer()
            if isFetchingRates {
                ProgressView().scaleEffect(0.8)
            } else {
                Button("Refresh") {
                    Task { await fetchRates() }
                }
                .font(.caption)
                .foregroundColor(.teal)
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Rate row (editable)

    @ViewBuilder
    private func rateRow(_ info: CurrencyInfo) -> some View {
        HStack(spacing: 8) {
            Text("1 \(info.code) =")
                .font(.subheadline)
                .foregroundColor(.white)

            TextField("0.0000", text: rateBinding(for: info.code))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .foregroundColor(.teal)
                .frame(maxWidth: 80)

            Text(defaultCurrencyCode)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
        .listRowBackground(Color(red: 0.05, green: 0.1, blue: 0.2))
    }

    private func rateBinding(for code: String) -> Binding<String> {
        Binding(
            get: {
                if let text = rateEditBuffer[code] { return text }
                if let rate = rates[code] { return String(format: "%.4f", rate) }
                return ""
            },
            set: { newText in
                rateEditBuffer[code] = newText
                // Persist as soon as a valid positive number is entered
                if let rate = Double(newText), rate > 0 {
                    rates[code] = rate
                    CurrencyUtils.cachedRates = rates
                    // Sync @AppStorage so other views update reactively
                    if let data = try? JSONEncoder().encode(rates) {
                        exchangeRatesData = data
                    }
                }
            }
        )
    }

    // MARK: - Currency toggle row

    @ViewBuilder
    private func currencyRow(_ info: CurrencyInfo) -> some View {
        let isEnabled = enabledCodes.contains(info.code)
        Button { toggle(info.code) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(info.code)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("\(info.name)  \(info.symbol)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                if isEnabled {
                    Image(systemName: "checkmark")
                        .foregroundColor(.teal)
                }
            }
        }
        .listRowBackground(Color(red: 0.05, green: 0.1, blue: 0.2))
    }

    // MARK: - Actions

    private func toggle(_ code: String) {
        var codes = enabledCurrenciesRaw.components(separatedBy: ",").filter { !$0.isEmpty }
        if codes.contains(code) {
            guard codes.count > 1 else { return }
            codes.removeAll { $0 == code }
            if defaultCurrencyCode == code { defaultCurrencyCode = codes.first ?? "SGD" }
        } else {
            codes.append(code)
            // Fetch rate immediately if this currency has no cached rate yet
            if rates[code] == nil && code != defaultCurrencyCode {
                Task { await fetchRateForCurrency(code) }
            }
        }
        enabledCurrenciesRaw = codes.joined(separator: ",")
    }

    private func deleteCustom(at offsets: IndexSet) {
        let builtInCodes = Set(CurrencyUtils.allCurrencies.map { $0.code })
        var customEntries = customCurrenciesRaw.components(separatedBy: ",").filter { entry in
            let code = entry.components(separatedBy: "|").first ?? ""
            return !builtInCodes.contains(code) && !code.isEmpty
        }
        let codesToRemove = offsets.map { parsedCustomCurrencies[$0].code }
        customEntries.removeAll { entry in
            let code = entry.components(separatedBy: "|").first ?? ""
            return codesToRemove.contains(code)
        }
        customCurrenciesRaw = customEntries.joined(separator: ",")
        var codes = enabledCurrenciesRaw.components(separatedBy: ",").filter { !$0.isEmpty }
        codes.removeAll { codesToRemove.contains($0) }
        if codes.isEmpty { codes = [defaultCurrencyCode] }
        enabledCurrenciesRaw = codes.joined(separator: ",")
        if codesToRemove.contains(defaultCurrencyCode) {
            defaultCurrencyCode = codes.first ?? "SGD"
        }
    }

    /// Fetches rates for all currently enabled currencies and saves them.
    @MainActor
    private func fetchRates() async {
        isFetchingRates = true
        let codes = CurrencyUtils.enabledCurrencies(fromRaw: enabledCurrenciesRaw, customRaw: customCurrenciesRaw)
            .map { $0.code }
        if let fetched = await CurrencyUtils.fetchRates(for: codes, to: defaultCurrencyCode) {
            var updated = rates
            for (code, rate) in fetched { updated[code] = rate }
            saveRates(updated)
            lastFetched = Date()
        }
        isFetchingRates = false
    }

    /// Fetches the rate for a single newly-added currency and merges it into the cache.
    @MainActor
    private func fetchRateForCurrency(_ code: String) async {
        guard code != defaultCurrencyCode else { return }
        isFetchingRates = true
        if let fetched = await CurrencyUtils.fetchRates(for: [code], to: defaultCurrencyCode) {
            var updated = rates
            for (c, rate) in fetched { updated[c] = rate }
            saveRates(updated)
        }
        isFetchingRates = false
    }

    private func saveRates(_ updated: [String: Double]) {
        rates = updated
        CurrencyUtils.saveRates(updated, baseCurrency: defaultCurrencyCode)
        if let data = try? JSONEncoder().encode(updated) {
            exchangeRatesData = data
        }
    }
}

// MARK: - Add Currency Sheet

struct AddCurrencyView: View {
    @Binding var enabledCurrenciesRaw: String
    @Binding var customCurrenciesRaw: String
    var onAdded: (String) -> Void = { _ in }
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var name = ""
    @State private var symbol = ""
    @State private var duplicateError = false

    private var existingCodes: Set<String> {
        let builtIn = Set(CurrencyUtils.allCurrencies.map { $0.code })
        let custom = Set(customCurrenciesRaw.components(separatedBy: ",")
            .compactMap { $0.components(separatedBy: "|").first }
            .filter { !$0.isEmpty })
        return builtIn.union(custom)
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Currency Details") {
                    TextField("Code (e.g. TWD)", text: $code)
                        .textInputAutocapitalization(.characters)
                        .onChange(of: code) { _, _ in duplicateError = false }
                    TextField("Name (e.g. Taiwan Dollar)", text: $name)
                    TextField("Symbol (e.g. NT$)", text: $symbol)
                }
                if duplicateError {
                    Section {
                        Text("\(code.uppercased()) already exists.")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(red: 0.05, green: 0.1, blue: 0.2))
            .navigationTitle("Add Currency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") { addCurrency() }
                        .disabled(code.trimmingCharacters(in: .whitespaces).isEmpty ||
                                  name.trimmingCharacters(in: .whitespaces).isEmpty ||
                                  symbol.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func addCurrency() {
        let upperCode = code.uppercased().trimmingCharacters(in: .whitespaces)
        guard !existingCodes.contains(upperCode) else {
            duplicateError = true
            return
        }
        let entry = "\(upperCode)|\(name.trimmingCharacters(in: .whitespaces))|\(symbol.trimmingCharacters(in: .whitespaces))"
        customCurrenciesRaw = customCurrenciesRaw.isEmpty ? entry : "\(customCurrenciesRaw),\(entry)"
        // Auto-enable the new currency
        var codes = enabledCurrenciesRaw.components(separatedBy: ",").filter { !$0.isEmpty }
        if !codes.contains(upperCode) { codes.append(upperCode) }
        enabledCurrenciesRaw = codes.joined(separator: ",")
        onAdded(upperCode)
        dismiss()
    }
}

#Preview {
    SettingsView()
}
