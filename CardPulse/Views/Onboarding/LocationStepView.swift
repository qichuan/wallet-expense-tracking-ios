//
//  LocationStepView.swift
//  CardPulse
//

import SwiftUI
import CoreLocation

struct LocationStepView: View {
    @StateObject private var locationManager = LocationManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Remember the place")
                    .font(AppTypography.screenTitle)
                    .foregroundColor(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Save where each transaction was made so you can see it on a map later. Your location is only read when you add a transaction.")
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 20)

            VStack(alignment: .leading, spacing: 18) {
                previewCard

                Button(action: locationManager.requestPermission) {
                    Text(buttonLabel)
                        .font(AppTypography.navButton)
                        .foregroundColor(AppColors.backgroundPrimary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(AppColors.surfaceHigh)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!locationManager.isUndetermined)

                if locationManager.authorizationStatus == .denied {
                    Text("You declined location access. You can enable it anytime in iOS Settings.")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
        }
    }

    private var buttonLabel: String {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: return "Location enabled"
        case .denied, .restricted:                    return "Location unavailable"
        default:                                      return "Enable location"
        }
    }

    @ViewBuilder
    private var previewCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "mappin.and.ellipse")
                .font(AppTypography.iconMedium)
                .foregroundColor(AppColors.accent)
                .frame(width: 40, height: 40)
                .background(AppColors.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("Tiong Bahru Bakery")
                    .font(AppTypography.bannerTitle)
                    .foregroundColor(AppColors.textPrimary)
                Text("56 Eng Hoon St, Singapore")
                    .font(AppTypography.bannerBody)
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.backgroundCard)
        )
    }
}

#Preview {
    LocationStepView()
        .background(AppColors.backgroundPrimary)
}
