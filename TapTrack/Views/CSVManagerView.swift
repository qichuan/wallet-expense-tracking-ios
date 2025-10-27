//
//  CSVManagerView.swift
//  TapTrack
//
//  Created by Zhang Qichuan on 27/10/25.
//

import SwiftUI
import UniformTypeIdentifiers
import SwiftData


struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    
    var content: String
    
    init(content: String) {
        self.content = content
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        content = string
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = content.data(using: .utf8)!
        return .init(regularFileWithContents: data)
    }
}

struct CSVManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingExportAlert = false
    @State private var showingImportPicker = false
    @State private var exportMessage = ""
    @State private var importMessage = ""
    @State private var showingImportAlert = false
    @State private var showingExportOptions = false
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var showingFilePicker = false
    
    private var transactionManager: TransactionManager {
        TransactionManager(modelContext: modelContext)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Import/Export Section
                VStack(spacing: 20) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 48))
                        .foregroundColor(.teal)
                    
                    Text("Import/Export CSV")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Import transactions from CSV or export your data")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                    
                    VStack(spacing: 12) {
                        Button(action: { showingExportOptions = true }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Export to CSV")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.teal)
                            .cornerRadius(12)
                        }
                        
                        Button(action: { showingImportPicker = true }) {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("Import from CSV")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(16)
                
                // Format Information
                VStack(alignment: .leading, spacing: 12) {
                    Text("CSV Format")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Expected columns: Merchant, Amount, Account, Date, Note")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("Date format: yyyy-MM-dd HH:mm:ss")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
            .background(Color(red: 0.05, green: 0.1, blue: 0.2))
            .navigationTitle("CSV Manager")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [UTType.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
        .sheet(isPresented: $showingFilePicker) {
            DocumentPickerView(
                csvContent: transactionManager.exportToCSV(),
                filename: "transactions_\(formatDate(startDate))_to_\(formatDate(endDate)).csv",
                onComplete: { result in
                    handleExport(result: result)
                }
            )
        }
        .alert("Export Complete", isPresented: $showingExportAlert) {
            Button("OK") { }
        } message: {
            Text(exportMessage)
        }
        .alert("Import Complete", isPresented: $showingImportAlert) {
            Button("OK") { }
        } message: {
            Text(importMessage)
        }
        .sheet(isPresented: $showingExportOptions) {
            ExportOptionsView(
                startDate: $startDate,
                endDate: $endDate,
                onExport: {
                    print("Export button tapped, generating CSV content")
                    print("Date range: \(startDate) to \(endDate)")
                    let csvContent = transactionManager.exportToCSV()
                    print("Generated CSV content length: \(csvContent.count)")
                    print("CSV content preview: \(String(csvContent.prefix(200)))")
                    
                    if csvContent.isEmpty {
                        exportMessage = "No transactions found in the selected date range"
                        showingExportAlert = true
                    } else {
                        showingFilePicker = true
                    }
                }
            )
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func handleExport(result: Result<URL, Error>) {
        print("handleExport called with result: \(result)")
        switch result {
        case .success(let url):
            print("File exported successfully to: \(url)")
            exportMessage = "CSV exported successfully to \(url.lastPathComponent)"
            print("CSV exported successfully")
            showingExportAlert = true
        case .failure(let error):
            if error.localizedDescription.contains("User cancelled") {
                print("User cancelled export")
                return // Don't show alert for cancellation
            }
            print("Error exporting file: \(error)")
            exportMessage = "Error exporting file: \(error.localizedDescription)"
            showingExportAlert = true
        }
    }
    
    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            do {
                let csvContent = try String(contentsOf: url)
                transactionManager.importFromCSV(csvContent)
                importMessage = "CSV imported successfully!"
            } catch {
                importMessage = "Error reading CSV file: \(error.localizedDescription)"
            }
            
        case .failure(let error):
            importMessage = "Error selecting file: \(error.localizedDescription)"
        }
        
        showingImportAlert = true
    }
}

struct ExportOptionsView: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    let onExport: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var transactions: [Transaction] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Date Range Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Date Range")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    VStack(spacing: 12) {
                        HStack {
                            Text("Start Date")
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                            DatePicker("", selection: $startDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                        
                        HStack {
                            Text("End Date")
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                            DatePicker("", selection: $endDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(12)
                }
                
                // Export Button
                Button(action: { onExport() }) {
                    Text("Export CSV")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.teal)
                        .cornerRadius(12)
                }
                .disabled(startDate > endDate)
                
                // Transactions Preview Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Transactions to Export")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("\(transactions.count) transactions")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    if isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading transactions...")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else if transactions.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "tray")
                                .font(.system(size: 32))
                                .foregroundColor(.white.opacity(0.5))
                            Text("No transactions found in selected date range")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(transactions.prefix(10)) { transaction in
                                    TransactionPreviewRow(transaction: transaction)
                                }
                                
                                if transactions.count > 10 {
                                    Text("... and \(transactions.count - 10) more transactions")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                        .padding(.top, 8)
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(Color(red: 0.05, green: 0.1, blue: 0.2))
            .navigationTitle("Export Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadTransactions()
        }
        .onChange(of: startDate) { _, _ in
            loadTransactions()
        }
        .onChange(of: endDate) { _, _ in
            loadTransactions()
        }
    }
    
    private func loadTransactions() {
        isLoading = true
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: startDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) ?? endDate
        
        let request = FetchDescriptor<Transaction>(
            predicate: #Predicate { transaction in
                transaction.date >= startOfDay && transaction.date < endOfDay
            }
        )
        
        do {
            transactions = try modelContext.fetch(request)
            isLoading = false
        } catch {
            print("Error loading transactions: \(error)")
            transactions = []
            isLoading = false
        }
    }
}

struct TransactionPreviewRow: View {
    let transaction: Transaction
    
    var body: some View {
        HStack(spacing: 12) {
            // Merchant Icon
            Circle()
                .fill(merchantColor)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: merchantIcon)
                        .font(.caption)
                        .foregroundColor(.white)
                )
            
            // Transaction Details
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.merchant)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    if let card = transaction.card {
                        Text(card.name)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Text(transaction.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            Spacer()
            
            // Amount
            Text("-$\(Double(truncating: transaction.amount as NSDecimalNumber), specifier: "%.2f")")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var merchantIcon: String {
        MerchantUtils.icon(for: transaction.category)
    }
    
    private var merchantColor: Color {
        MerchantUtils.color(for: transaction.category)
    }
}

struct DocumentPickerView: UIViewControllerRepresentable {
    let csvContent: String
    let filename: String
    let onComplete: (Result<URL, Error>) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        print("DocumentPickerView: Creating file with content length: \(csvContent.count)")
        print("DocumentPickerView: Content preview: \(String(csvContent.prefix(100)))")
        
        // Create a temporary file with the CSV content
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        do {
            try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)
            print("DocumentPickerView: Successfully wrote file to \(tempURL)")
            
            // Verify the file was written correctly
            let savedContent = try String(contentsOf: tempURL, encoding: .utf8)
            print("DocumentPickerView: Verified file content length: \(savedContent.count)")
            
        } catch {
            print("DocumentPickerView: Error writing file: \(error)")
            onComplete(.failure(error))
            return UIDocumentPickerViewController(forExporting: [])
        }
        
        let picker = UIDocumentPickerViewController(forExporting: [tempURL])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerView
        
        init(_ parent: DocumentPickerView) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            print("DocumentPickerView: User selected file at \(urls)")
            if let url = urls.first {
                parent.onComplete(.success(url))
            } else {
                parent.onComplete(.failure(NSError(domain: "DocumentPicker", code: -1, userInfo: [NSLocalizedDescriptionKey: "No file selected"])))
            }
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            print("DocumentPickerView: User cancelled")
            parent.onComplete(.failure(NSError(domain: "DocumentPicker", code: -2, userInfo: [NSLocalizedDescriptionKey: "User cancelled"])))
        }
    }
}

#Preview {
    CSVManagerView()
        .modelContainer(ModelContainer.createMockContainer())
}
