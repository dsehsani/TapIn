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
        HStack(spacing: 12) {
            // App Logo
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.ucdBlue)
                    .frame(width: 36, height: 36)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)

                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
            }

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
                    ? Color(hex: "#1e293b")
                    : Color(hex: "#f1f5f9")
            )
            .clipShape(Capsule())

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
