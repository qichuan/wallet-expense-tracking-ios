//
//  OnboardingScaffold.swift
//  CardPulse
//

import SwiftUI

/// Shared chrome for every onboarding step: top bar (back + progress + optional skip),
/// a title/description header, a scrollable content slot, and a pinned primary button
/// (optionally with a secondary "skip/later" button underneath).
struct OnboardingScaffold<Content: View>: View {
    let step: Int                   // 1-based
    let totalSteps: Int
    let title: String
    let description: String?
    let primaryTitle: String
    let primaryEnabled: Bool
    let onBack: (() -> Void)?
    let onSkip: (() -> Void)?
    let onPrimary: () -> Void
    let secondaryTitle: String?
    let onSecondary: (() -> Void)?
    @ViewBuilder let content: () -> Content

    init(
        step: Int,
        totalSteps: Int,
        title: String,
        description: String? = nil,
        primaryTitle: String,
        primaryEnabled: Bool = true,
        onBack: (() -> Void)? = nil,
        onSkip: (() -> Void)? = nil,
        onPrimary: @escaping () -> Void,
        secondaryTitle: String? = nil,
        onSecondary: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.step = step
        self.totalSteps = totalSteps
        self.title = title
        self.description = description
        self.primaryTitle = primaryTitle
        self.primaryEnabled = primaryEnabled
        self.onBack = onBack
        self.onSkip = onSkip
        self.onPrimary = onPrimary
        self.secondaryTitle = secondaryTitle
        self.onSecondary = onSecondary
        self.content = content
    }

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 10) {
                    Text(title)
                        .font(AppTypography.screenTitle)
                        .foregroundColor(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let description {
                        Text(description)
                            .font(AppTypography.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 20)

                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack(spacing: 10) {
                    OnboardingPrimaryButton(
                        title: primaryTitle,
                        enabled: primaryEnabled,
                        action: onPrimary
                    )

                    if let secondaryTitle, let onSecondary {
                        Button(action: onSecondary) {
                            Text(secondaryTitle)
                                .font(AppTypography.navButton)
                                .foregroundColor(AppColors.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    @ViewBuilder
    private var topBar: some View {
        HStack(spacing: 12) {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(AppTypography.navChevron)
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(AppColors.backgroundCard)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            OnboardingProgressBar(step: step, total: totalSteps)

            if let onSkip {
                Button(action: onSkip) {
                    Text("Skip")
                        .font(AppTypography.navButton)
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(AppColors.backgroundCard)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Progress bar

struct OnboardingProgressBar: View {
    let step: Int   // 1-based
    let total: Int

    private var fraction: CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(max(0, min(step, total))) / CGFloat(total)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppColors.backgroundCard)
                Capsule()
                    .fill(AppColors.textPrimary)
                    .frame(width: proxy.size.width * fraction)
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Primary pill button

struct OnboardingPrimaryButton: View {
    let title: String
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTypography.navButton)
                .foregroundColor(enabled ? AppColors.backgroundPrimary : AppColors.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(enabled ? AppColors.surfaceHigh : AppColors.backgroundCard)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
