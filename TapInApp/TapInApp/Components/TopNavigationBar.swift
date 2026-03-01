//
//  TopNavigationBar.swift
//  TapInApp
//
//  Created by Darius Ehsani on 1/29/26.
//

import SwiftUI

struct TopNavigationBar: View {
    var onSettingsTap: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(alignment: .center) {
            Text(Self.currentDateString)
                .font(.system(size: 34, weight: .black))
                .foregroundColor(Color.adaptiveText(colorScheme))

            Spacer()

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
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: Date())
    }

    // MARK: - Profile Avatar

    private var profileAvatar: some View {
        Group {
            if let data = UserDefaults.standard.data(forKey: "profileImageData"),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 34, height: 34)
                    .clipShape(Circle())
            } else {
                // Initials fallback
                let initial = String(
                    (UserDefaults.standard.string(forKey: "userName") ?? "U").prefix(1)
                ).uppercased()

                Text(initial)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 34, height: 34)
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
