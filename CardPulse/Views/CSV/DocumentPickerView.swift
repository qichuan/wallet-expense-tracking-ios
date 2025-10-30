//
//  DocumentPickerView.swift
//  CardPulse

import SwiftUI
import UniformTypeIdentifiers

struct DocumentPickerView: UIViewControllerRepresentable {
    let csvContent: String
    let filename: String
    let onComplete: (Result<URL, Error>) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)
        } catch {
            onComplete(.failure(error))
            return UIDocumentPickerViewController(forExporting: [])
        }
        let picker = UIDocumentPickerViewController(forExporting: [tempURL])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerView
        init(_ parent: DocumentPickerView) { self.parent = parent }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first { parent.onComplete(.success(url)) }
            else { parent.onComplete(.failure(NSError(domain: "DocumentPicker", code: -1, userInfo: [NSLocalizedDescriptionKey: "No file selected"]))) }
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.onComplete(.failure(NSError(domain: "DocumentPicker", code: -2, userInfo: [NSLocalizedDescriptionKey: "User cancelled"])))
        }
    }
}


