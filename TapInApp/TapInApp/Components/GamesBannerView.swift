//
//  GamesBannerView.swift
//  TapInApp
//
//  Created by Darius Ehsani on 1/29/26.
//

import SwiftUI

struct GamesBannerView: View {
    var onPlayTap: () -> Void

    var body: some View {
        ZStack {
            // Gradient Background
            LinearGradient(
                colors: [
                    Color.ucdBlue,
                    Color(hex: "#1e3a5f"),
                    Color.ucdBlue
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Background Decoration
            HStack {
                Spacer()
                Image(systemName: "puzzlepiece.extension.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.white.opacity(0.1))
                    .offset(x: 20, y: -20)
            }

            // Content
            HStack {
                HStack(spacing: 16) {
                    // Puzzle Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.ucdGold)
                            .frame(width: 56, height: 56)
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)

                        Image(systemName: "puzzlepiece.extension.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color.ucdBlue)
                    }

                    // Text Content
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Aggie Puzzles")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)

                        Text("Test your campus knowledge")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#93c5fd"))
                    }
                }

                Spacer()

                // Play Button
                Button(action: onPlayTap) {
                    Text("PLAY NOW")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(Color.ucdBlue)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(20)
        }
        .frame(height: 96)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.ucdBlue.opacity(0.3), radius: 12, x: 0, y: 6)
        .padding(.horizontal, 16)
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    VStack {
        GamesBannerView(onPlayTap: {})
        Spacer()
    }
    .padding(.top, 20)
    .background(Color.backgroundLight)
}
