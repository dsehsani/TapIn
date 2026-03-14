//
//  UnverifiedLocationBanner.swift
//  TapInApp
//
//  Yellow warning banner for web-searched locations that are unverified.
//

import SwiftUI

struct UnverifiedLocationBanner: View {
    let location: String
    let source: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // Header row
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 13))
                Text("Unverified Location")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.yellow)
            }

            // The location itself
            HStack(spacing: 6) {
                Image(systemName: "mappin.slash")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                Text(location)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))
            }

            // Source + disclaimer
            Text("Found on \(source). This is where the club typically meets — not confirmed for this event.")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.yellow.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.yellow.opacity(0.35), lineWidth: 1)
                )
        )
    }
}
