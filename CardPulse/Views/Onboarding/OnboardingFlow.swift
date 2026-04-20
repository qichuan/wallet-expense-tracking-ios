//
//  OnboardingFlow.swift
//  CardPulse
//

import SwiftUI
import SwiftData

enum OnboardingStep: Hashable {
    case currency
    case categories
    case notifications
    case automation
}

/// Root of the onboarding experience. Hosts the `NavigationStack` and walks
/// the user from Welcome through the four step screens, setting
/// `hasCompletedOnboarding` when done.
struct OnboardingFlow: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var path: [OnboardingStep] = []

    /// Total number of steps (welcome is step 0 — not counted in the progress bar).
    private let totalSteps = 4

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeStepView(onContinue: { path.append(.currency) })
                .navigationDestination(for: OnboardingStep.self) { step in
                    switch step {
                    case .currency:
                        CurrencyStepView(
                            totalSteps: totalSteps,
                            onBack: { popLast() },
                            onContinue: { path.append(.categories) }
                        )
                    case .categories:
                        CategoriesStepView(
                            totalSteps: totalSteps,
                            onBack: { popLast() },
                            onContinue: { path.append(.notifications) },
                            onSkip: { path.append(.notifications) }
                        )
                    case .notifications:
                        NotificationsStepView(
                            totalSteps: totalSteps,
                            onBack: { popLast() },
                            onContinue: { path.append(.automation) }
                        )
                    case .automation:
                        AutomationStepView(
                            totalSteps: totalSteps,
                            onBack: { popLast() },
                            onFinish: { complete() }
                        )
                    }
                }
        }
        .preferredColorScheme(.dark)
    }

    private func popLast() {
        if !path.isEmpty { path.removeLast() }
    }

    private func complete() {
        hasCompletedOnboarding = true
    }
}
