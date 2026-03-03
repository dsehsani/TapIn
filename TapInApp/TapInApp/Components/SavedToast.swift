//
//  SavedToast.swift
//  TapInApp
//
//  Spotify-style top toast that confirms save/unsave actions.
//

import SwiftUI

struct SavedToast: View {
    let message: String
    let icon: String
    let isSaved: Bool

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSaved ? Color.ucdGold : .secondary)

            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(colorScheme == .dark ? Color(hex: "#1e293b") : .white)
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
        )
        .overlay(
            Capsule()
                .stroke(colorScheme == .dark ? Color(hex: "#334155") : Color(hex: "#e2e8f0"), lineWidth: 0.5)
        )
    }
}
