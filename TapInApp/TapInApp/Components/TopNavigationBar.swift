//
//  TopNavigationBar.swift
//  TapInApp
//
//  Created by Darius Ehsani on 1/29/26.
//

import SwiftUI

struct TopNavigationBar: View {
    var onSettingsTap: () -> Void
    var onBellTap: () -> Void = {}
    var hasUnseenNotifications: Bool = false

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(alignment: .center) {
            Text(Self.currentDateString)
                .font(.system(size: 34, weight: .black))
                .foregroundColor(Color.adaptiveText(colorScheme))

            Spacer()

            // Notification bell
            Button(action: onBellTap) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color.adaptiveText(colorScheme))
                        .frame(width: 42, height: 42)

                    if hasUnseenNotifications {
                        Circle()
                            .fill(.red)
                            .frame(width: 10, height: 10)
                            .offset(x: -6, y: 6)
                    }
                }
            }
            .buttonStyle(.plain)

            // Profile avatar button
            Button(action: onSettingsTap) {
                profileAvatar
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    // MARK: - Date Formatter

    private static var currentDateString: String {
        let day = Calendar.current.component(.day, from: Date())
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        let month = formatter.string(from: Date())
        return "\(month) \(day)\(ordinalSuffix(for: day))"
    }

    private static func ordinalSuffix(for day: Int) -> String {
        switch day {
        case 11, 12, 13: return "th"
        default:
            switch day % 10 {
            case 1: return "st"
            case 2: return "nd"
            case 3: return "rd"
            default: return "th"
            }
        }
    }

    // MARK: - Profile Avatar

    private var profileAvatar: some View {
        Group {
            if let data = UserDefaults.standard.data(forKey: "profileImageData"),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 42, height: 42)
                    .clipShape(Circle())
            } else {
                // Initials fallback
                let initial = String(
                    (UserDefaults.standard.string(forKey: "userName") ?? "U").prefix(1)
                ).uppercased()

                Text(initial)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .background(
                        LinearGradient(
                            colors: colorScheme == .dark
                                ? [Color(hex: "#1e2545"), Color(hex: "#302050")]
                                : [Color.accentCoral, Color.accentOrange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
            }
        }
    }
}

#Preview {
    VStack {
        TopNavigationBar(
            onSettingsTap: {}
        )
        Spacer()
    }
    .background(Color.backgroundLight)
}
