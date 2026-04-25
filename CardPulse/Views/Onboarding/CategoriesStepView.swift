//
//  CategoriesStepView.swift
//  CardPulse
//

import SwiftUI
import SwiftData

struct CategoriesStepView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Add some categories")
                    .font(AppTypography.screenTitle)
                    .foregroundColor(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Go ahead and add some categories to get started or use the suggested ones. You can always add or edit them later.")
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 20)

            CategoryListView(mode: .onboarding(onDelete: delete))
        }
    }

    private func delete(_ cat: SpendingCategory) {
        guard !cat.isBuiltIn else { return }
        let name = cat.name
        modelContext.delete(cat)
        try? modelContext.save()
        AnalyticsTracker.log(AnalyticsTracker.Event.categoryDeleted, [
            "name": name,
            "source": "onboarding"
        ])
    }
}

#Preview {
    CategoriesStepView()
        .background(AppColors.backgroundPrimary)
        .modelContainer(ModelContainer.createMockContainer())
}
