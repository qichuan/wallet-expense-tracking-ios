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
    @State private var importPlan: ImportPlan = ImportPlan()

    // Export preview states
    @State private var showingExportOptions = false
    @State private var startDate = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
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
    @State private var showingTroubleshooting = false
    @State private var showingCategoryManager = false

    #if DEBUG
    @AppStorage("debugAlwaysShowOnboarding") private var debugAlwaysShowOnboarding = false
    #endif
    
    private var appVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        return short
    }

    var body: some View {
        ZStack {
            NavigationStack {
                ZStack {
                    AppColors.backgroundPrimary.ignoresSafeArea()
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            BrandHeader(title: "Settings")

                            // CURRENCY
                            SettingsSection(title: "Currency") {
                                SettingsPickerRow(
                                    title: "Main currency",
                                    selection: $defaultCurrencyCode,
                                    options: enabledCurrencyList.map { $0.code }
                                )
                                SettingsValueRow(
                                    title: "Enabled currencies",
                                    value: "\(enabledCurrencyList.count)",
                                    action: {
                                        AnalyticsTracker.view("currency_manager")
                                        showingCurrencyManager = true
                                    }
                                )
                            }

                            // CATEGORIES
                            SettingsSection(title: "Categories") {
                                SettingsValueRow(
                                    title: "Manage categories",
                                    value: "",
                                    action: {
                                        AnalyticsTracker.view("category_manager")
                                        showingCategoryManager = true
                                    }
                                )
                            }

                            // AUTOMATION
                            SettingsSection(title: "Automation") {
                                SettingsValueRow(
                                    title: "How to auto-track",
                                    value: "Setup",
                                    action: {
                                        showingHowToAutoTracking = true
                                    }
                                )
                                SettingsValueRow(
                                    title: "Troubleshoot auto-tracking",
                                    value: "Help",
                                    action: {
                                        AnalyticsTracker.view("troubleshooting")
                                        showingTroubleshooting = true
                                    }
                                )
                            }

                            // DATA
                            SettingsSection(title: "Data") {
                                SettingsValueRow(
                                    title: "Import CSV",
                                    value: "",
                                    action: {
                                        AnalyticsTracker.log(AnalyticsTracker.Event.importStarted)
                                        showingImportPicker = true
                                    }
                                )
                                SettingsValueRow(
                                    title: "Export CSV",
                                    value: "",
                                    action: {
                                        AnalyticsTracker.log(AnalyticsTracker.Event.exportStarted)
                                        showingExportOptions = true
                                    }
                                )
                            }

                            // ABOUT
                            SettingsSection(title: "About") {
                                SettingsValueRow(
                                    title: "Contact the Developer",
                                    value: "Email",
                                    action: {
                                        AnalyticsTracker.log(AnalyticsTracker.Event.contactDeveloper)
                                        openEmail()
                                    }
                                )
                                SettingsStaticRow(title: "Version", value: appVersion)
                            }

                            #if DEBUG
                            SettingsSection(title: "Debug") {
                                SettingsToggleRow(
                                    title: "Always show onboarding",
                                    isOn: $debugAlwaysShowOnboarding
                                )
                            }
                            #endif
                        }
                        .padding(.bottom, 40)
                    }
                }
                .navigationBarHidden(true)
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
                plan: importPlan,
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
                        AnalyticsTracker.log(AnalyticsTracker.Event.exportCompleted, [
                            "size_bytes": csvToExport.utf8.count
                        ])
                        exportCompleteMessage = "CSV file exported successfully!"
                        showingExportCompleteAlert = true
                    case .failure(let error):
                        if (error as NSError).code != -2 { // -2 is user cancellation, don't show error
                            AnalyticsTracker.log(AnalyticsTracker.Event.exportCompleted, [
                                "size_bytes": csvToExport.utf8.count
                            ])
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
        // Category manager
        .sheet(isPresented: $showingCategoryManager) {
            CategoryManagementView()
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
            AnalyticsTracker.log(AnalyticsTracker.Event.currencyDefaultSet, ["code": newDefault])
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
        .alert("Troubleshooting", isPresented: $showingTroubleshooting) {
            Button("OK") {}
        } message: {
            Text("If transactions aren't being recorded automatically, or a dialog keeps prompting you after you tap to pay, try deleting the automation in the Shortcuts app and setting it up again from scratch.")
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
        try? await Task.sleep(nanoseconds: 500_000_000)

        // 1. Add custom currencies first so they're known when transactions reference them
        if !importPlan.customCurrenciesToAdd.isEmpty {
            importProgressText = "Adding custom currencies…"
            var existing = CurrencyUtils.parseCustomCurrencies(fromRaw: customCurrenciesRaw)
            let existingCodes = Set(existing.map { $0.code })
            for c in importPlan.customCurrenciesToAdd where !existingCodes.contains(c.code) {
                existing.append(CurrencyInfo(code: c.code, name: c.name, symbol: c.symbol))
            }
            customCurrenciesRaw = existing.map { "\($0.code)|\($0.name)|\($0.symbol)" }.joined(separator: ",")
        }

        // 2. Enable new currencies and fetch exchange rates
        if !importPlan.currenciesToEnable.isEmpty {
            importProgressText = "Enabling currencies…"
            var codes = enabledCurrenciesRaw.components(separatedBy: ",").filter { !$0.isEmpty }
            for code in importPlan.currenciesToEnable where !codes.contains(code) {
                codes.append(code)
            }
            enabledCurrenciesRaw = codes.joined(separator: ",")

            importProgressText = "Fetching exchange rates…"
            if let fetched = await CurrencyUtils.fetchRates(for: importPlan.currenciesToEnable, to: defaultCurrencyCode) {
                var updated = CurrencyUtils.cachedRates
                for (code, rate) in fetched { updated[code] = rate }
                CurrencyUtils.saveRates(updated, baseCurrency: defaultCurrencyCode)
                if let data = try? JSONEncoder().encode(updated) {
                    exchangeRatesData = data
                }
            }
        }

        // 3. Apply the plan: insert cards, categories, transactions
        do {
            importProgressText = "Importing data…"
            let result = try ImportExportUtils.applyImportPlan(importPlan, modelContext: modelContext)
            importProgressText = "Import completed!"

            var summary: [String] = []
            summary.append("\(result.transactionsAdded) transactions")
            if result.cardsAdded > 0 { summary.append("\(result.cardsAdded) cards") }
            if result.categoriesAdded > 0 { summary.append("\(result.categoriesAdded) categories") }
            if result.rewardRulesAdded > 0 { summary.append("\(result.rewardRulesAdded) reward rules") }
            if !importPlan.currenciesToEnable.isEmpty {
                summary.append("\(importPlan.currenciesToEnable.count) currencies enabled")
            }
            var message = "Imported " + summary.joined(separator: ", ") + "."
            if result.transactionsSkippedAsDuplicates > 0 {
                message += " Skipped \(result.transactionsSkippedAsDuplicates) duplicate \(result.transactionsSkippedAsDuplicates == 1 ? "transaction" : "transactions")."
            }
            importMessage = message

            AnalyticsTracker.log(AnalyticsTracker.Event.importCompleted, [
                "transactions": result.transactionsAdded,
                "cards": result.cardsAdded,
                "categories": result.categoriesAdded,
                "reward_rules": result.rewardRulesAdded,
                "currencies_enabled": importPlan.currenciesToEnable.count,
                "duplicates_skipped": result.transactionsSkippedAsDuplicates
            ])

            try? await Task.sleep(nanoseconds: 500_000_000)
            isImporting = false
            showingImportAlert = true
        } catch {
            importMessage = "Error saving: \(error.localizedDescription)"
            AnalyticsTracker.log(AnalyticsTracker.Event.importFailed, [
                "error": error.localizedDescription
            ])
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
        
        // Generate CSV (full backup: cards, categories, currencies, transactions)
        csvToExport = ImportExportUtils.exportBackupCSV(
            modelContext: modelContext,
            from: startDate,
            to: endDate,
            defaultCurrency: defaultCurrencyCode,
            enabledCurrencyCodes: enabledCurrenciesRaw.components(separatedBy: ",").filter { !$0.isEmpty },
            customCurrenciesRaw: customCurrenciesRaw
        )
        exportFilename = "cardpulse_backup_\(ImportExportUtils.formatDate(startDate))_to_\(ImportExportUtils.formatDate(endDate)).csv"

        // Verify CSV was generated
        guard !csvToExport.isEmpty else {
            withAnimation {
                isExporting = false
            }
            importMessage = "Nothing to export."
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
                importPlan = ImportExportUtils.buildImportPlan(from: csvContent, modelContext: modelContext)
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

// MARK: - Settings rows

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: title)
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                content()
            }
            .background(AppColors.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 20)
        }
    }
}

struct SettingsValueRow: View {
    let title: String
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(AppTypography.rowTitle)
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer()
                if !value.isEmpty {
                    Text(value)
                        .font(AppTypography.rowValue)
                        .foregroundColor(AppColors.textSecondary)
                }
                Image(systemName: "chevron.right")
                    .font(AppTypography.chevron)
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct SettingsStaticRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(AppTypography.rowTitle)
                .foregroundColor(AppColors.textPrimary)
            Spacer()
            Text(value)
                .font(AppTypography.rowValue)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

struct SettingsToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(AppTypography.rowTitle)
                .foregroundColor(AppColors.textPrimary)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(AppColors.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct SettingsPickerRow: View {
    let title: String
    @Binding var selection: String
    let options: [String]

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(AppTypography.rowTitle)
                .foregroundColor(AppColors.textPrimary)
            Spacer()
            Picker("", selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.menu)
            .tint(AppColors.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct ProgressOverlay: View {
    let title: String
    let message: String
    let progress: Double?

    var body: some View {
        ZStack {
            AppColors.scrim
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text(title)
                    .font(AppTypography.headline)
                    .foregroundColor(AppColors.textPrimary)

                if let progress = progress {
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: AppColors.accent))
                        .frame(width: 200)

                    Text("\(Int(progress * 100))%")
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                } else {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(AppColors.accent)
                }

                Text(message)
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(24)
            .background(AppColors.backgroundCard)
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
                            .foregroundColor(AppColors.accent)
                    }
                    .buttonStyle(.plain)
                }) {
                    if parsedCustomCurrencies.isEmpty {
                        Text("Tap + to add a custom currency")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textTertiary)
                            .listRowBackground(AppColors.backgroundCard)
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
            .background(AppColors.backgroundPrimary)
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
                        .font(AppTypography.caption2)
                        .foregroundColor(AppColors.textTertiary)
                } else if let fetched = lastFetched {
                    Text("Updated \(fetched, style: .relative) ago")
                        .font(AppTypography.caption2)
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            Spacer()
            if isFetchingRates {
                ProgressView().scaleEffect(0.8)
            } else {
                Button("Refresh") {
                    Task { await fetchRates() }
                }
                .font(AppTypography.caption)
                .foregroundColor(AppColors.accent)
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Rate row (editable)

    @ViewBuilder
    private func rateRow(_ info: CurrencyInfo) -> some View {
        HStack(spacing: 8) {
            Text("1 \(info.code) =")
                .font(AppTypography.subheadline)
                .foregroundColor(AppColors.textPrimary)

            TextField("0.0000", text: rateBinding(for: info.code))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .foregroundColor(AppColors.accent)
                .frame(maxWidth: 80)

            Text(defaultCurrencyCode)
                .font(AppTypography.subheadline)
                .foregroundColor(AppColors.textSecondary)
        }
        .listRowBackground(AppColors.backgroundCard)
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
                    AnalyticsTracker.edit("exchange_rate", ["code": code])
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
                        .font(AppTypography.headline)
                        .foregroundColor(AppColors.textPrimary)
                    Text("\(info.name)  \(info.symbol)")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                if isEnabled {
                    Image(systemName: "checkmark")
                        .foregroundColor(AppColors.accent)
                }
            }
        }
        .listRowBackground(AppColors.backgroundCard)
    }

    // MARK: - Actions

    private func toggle(_ code: String) {
        var codes = enabledCurrenciesRaw.components(separatedBy: ",").filter { !$0.isEmpty }
        if codes.contains(code) {
            guard codes.count > 1 else { return }
            codes.removeAll { $0 == code }
            if defaultCurrencyCode == code { defaultCurrencyCode = codes.first ?? "SGD" }
            AnalyticsTracker.log(AnalyticsTracker.Event.currencyDisabled, ["code": code])
        } else {
            codes.append(code)
            AnalyticsTracker.log(AnalyticsTracker.Event.currencyEnabled, ["code": code])
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
            AnalyticsTracker.log(AnalyticsTracker.Event.exchangeRateRefreshed, [
                "count": fetched.count,
                "base": defaultCurrencyCode
            ])
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
                            .foregroundColor(AppColors.destructive)
                            .font(AppTypography.caption)
                    }
                    .listRowBackground(AppColors.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.backgroundPrimary)
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
        AnalyticsTracker.log(AnalyticsTracker.Event.currencyCustomAdded, ["code": upperCode])
        onAdded(upperCode)
        dismiss()
    }
}

#Preview {
    SettingsView()
}
