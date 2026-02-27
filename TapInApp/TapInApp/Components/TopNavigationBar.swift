//
//  TopNavigationBar.swift
//  TapInApp
//
//  Created by Darius Ehsani on 1/29/26.
//

import SwiftUI

struct TopNavigationBar: View {
    @Binding var searchText: String
    var onSettingsTap: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        if #available(iOS 26, *) {
            ios26Header
        } else {
            legacyHeader
        }
    }

    // MARK: - iOS 26+ Header (Clean title + date + avatar)

    @available(iOS 26, *)
    private var ios26Header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.currentDateString)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                Text("TapIn")
                    .font(.system(size: 34, weight: .black))
                    .foregroundColor(Color.adaptiveText(colorScheme))
            }

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
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }

    // MARK: - Profile Avatar

    @available(iOS 26, *)
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

    // MARK: - Legacy Header (search bar + gear)

    private var legacyHeader: some View {
        HStack(spacing: 12) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.textSecondary)
                    .font(.system(size: 16))

                TextField("Search UC Davis News", text: $searchText)
                    .font(.system(size: 14))

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.textSecondary)
                            .font(.system(size: 14))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                colorScheme == .dark
                    ? Color(hex: "#1a2033")
                    : Color(hex: "#fff5f0")
            )
            .clipShape(Capsule())
            .pulsingHotspot(
                tip: .searchBar,
                message: "Find any story — search by topic or keyword.",
                arrowEdge: .top,
                cornerRadius: 100
            )

            // Settings Button
            Button(action: onSettingsTap) {
                Image(systemName: "gearshape")
                    .font(.system(size: 20))
                    .foregroundColor(colorScheme == .dark ? .textSecondary : Color(hex: "#475569"))
            }
            .padding(8)
            .contentShape(Circle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            (colorScheme == .dark ? Color.backgroundDark : Color.white)
                .opacity(0.8)
        )
        .background(.ultraThinMaterial)
    }
}

#Preview {
    VStack {
        TopNavigationBar(
            searchText: .constant(""),
            onSettingsTap: {}
        )
        Spacer()
    }
    .background(Color.backgroundLight)
}
