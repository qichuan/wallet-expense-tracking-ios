//
//  OnboardingFlow.swift
//  CardPulse
//

import SwiftUI
import SwiftData

struct OnboardingFlow: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.modelContext) private var modelContext
    @AppStorage("defaultCurrency") private var defaultCurrencyCode = ""
    @AppStorage("enabledCurrencies") private var enabledCurrenciesRaw = ""
    @AppStorage("hasChosenDefaultCurrency") private var hasChosenDefaultCurrency = false

    @State private var stepIndex = 0   // 0 = welcome, 1–4 = steps
    @State private var goingForward = true
    @State private var currencySelectedCode = ""
    @State private var automationPrimaryAction: () -> Void = {}

    private let totalSteps = 4

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            if stepIndex == 0 {
                WelcomeStepView(onContinue: advance)
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading),
                        removal:   .move(edge: .leading)
                    ))
            } else {
                stepsContainer
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal:   .move(edge: .trailing)
                    ))
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if currencySelectedCode.isEmpty {
                currencySelectedCode = CurrencyStepView.defaultLocaleCode()
            }
        }
    }

    // MARK: - Fixed chrome + animated content

    private var stepsContainer: some View {
        VStack(spacing: 0) {
            // Fixed top bar — never transitions
            HStack(spacing: 12) {
                Button(action: goBack) {
                    Image(systemName: "chevron.left")
                        .font(AppTypography.navChevron)
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(AppColors.backgroundCard)
                        .clipShape(Circle())
                }
                .buttonStyle(.automatic)

                OnboardingProgressBar(step: stepIndex, total: totalSteps)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            // Animated content — slides on step change
            Group {
                switch stepIndex {
                case 1:
                    CurrencyStepView(selectedCode: $currencySelectedCode)
                case 2:
                    CategoriesStepView()
                case 3:
                    NotificationsStepView()
                case 4:
                    AutomationStepView(
                        onRegisterPrimaryAction: { automationPrimaryAction = $0 },
                        onFinish: complete
                    )
                default:
                    EmptyView()
                }
            }
            .id(stepIndex)
            .transition(contentTransition)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Fixed CTA — never transitions
            ctaSection
                .padding(.horizontal, 20) 
        }
    }

    // MARK: - CTA

    private var ctaSection: some View {
        VStack(spacing: 10) {
            OnboardingPrimaryButton(
                title: currentPrimaryTitle,
                enabled: currentPrimaryEnabled,
                action: performPrimaryAction
            )
        }
    }

    private var currentPrimaryTitle: String {
        switch stepIndex {
        case 4: return "Open Shortcuts"
        default: return "Continue"
        }
    }

    private var currentPrimaryEnabled: Bool {
        stepIndex == 1 ? !currencySelectedCode.isEmpty : true
    }

    private func performPrimaryAction() {
        switch stepIndex {
        case 1: currencySave()
        case 4: automationPrimaryAction()
        default: advance()
        }
    }

    // MARK: - Navigation

    private func advance() {
        withAnimation(.easeInOut(duration: 0.3)) {
            goingForward = true
            stepIndex += 1
        }
    }

    private func goBack() {
        withAnimation(.easeInOut(duration: 0.3)) {
            goingForward = false
            stepIndex -= 1
        }
    }

    private func complete() {
        hasCompletedOnboarding = true
        AnalyticsTracker.log(AnalyticsTracker.Event.onboardingCompleted)
    }

    private var contentTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: goingForward ? .trailing : .leading),
            removal:   .move(edge: goingForward ? .leading  : .trailing)
        )
    }

    // MARK: - Currency save (hoisted from CurrencyStepView)

    private func currencySave() {
        guard !currencySelectedCode.isEmpty else { return }
        defaultCurrencyCode = currencySelectedCode
        var codes = CurrencyUtils.defaultEnabledCurrencies
        if !codes.contains(currencySelectedCode) { codes.insert(currencySelectedCode, at: 0) }
        enabledCurrenciesRaw = codes.joined(separator: ",")
        backfillTransactions(currency: currencySelectedCode)
        hasChosenDefaultCurrency = true
        advance()
    }

    private func backfillTransactions(currency: String) {
        guard let txns = try? modelContext.fetch(FetchDescriptor<Transaction>()) else { return }
        for txn in txns where txn.currency.isEmpty { txn.currency = currency }
        try? modelContext.save()
    }
}
