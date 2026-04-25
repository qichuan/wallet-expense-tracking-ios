//
//  CategoryManagementView.swift
//  CardPulse
//

import SwiftUI

struct CategoryManagementView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                CategoryListView(mode: .management)
            }
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

