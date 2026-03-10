//
//  GameTutorialOverlay.swift
//  TapInApp
//
//  Reusable start-screen / tutorial overlay for mini-games.
//  First-time players see rules expanded; returning players
//  see a compact card with a "How to Play" toggle.
//

import SwiftUI

struct GameTutorialOverlay: View {
    let gameName: String
    let gameIcon: String
    let accentColor: Color
    let rules: [(icon: String, text: String)]
    let onStart: () -> Void
    var onExit: (() -> Void)? = nil
    var subtitle: String? = nil
    var showRulesInitially: Bool = true

    @Environment(\.colorScheme) var colorScheme
    @State private var showRules: Bool = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { } // absorb taps

            VStack(spacing: 0) {
                // Exit button (top-trailing)
                if let onExit {
                    HStack {
                        Spacer()
                        Button(action: onExit) {
                            Image(systemName: "house.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(colorScheme == .dark ? .white : Color.textSecondary)
                                .frame(width: 30, height: 30)
                                .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.bottom, 4)
                }

                // Icon
                Image(systemName: gameIcon)
                    .font(.system(size: 40))
                    .foregroundColor(accentColor)
                    .padding(.bottom, 10)

                // Game name
                Text(gameName)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? .white : Color.textPrimary)

                // Optional subtitle (e.g. date)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.textSecondary)
                        .padding(.top, 2)
                }

                // How to Play section
                VStack(spacing: 0) {
                    // Toggle button (only when rules aren't shown by default)
                    if !showRulesInitially {
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showRules.toggle()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "questionmark.circle")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("How to Play")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                Spacer()
                                Image(systemName: showRules ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(accentColor)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 4)
                        }
                    } else {
                        Text("How to Play")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.textSecondary)
                            .padding(.top, 4)
                            .padding(.bottom, 6)
                    }

                    // Rules list
                    if showRulesInitially || showRules {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(rules.enumerated()), id: \.offset) { _, rule in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: rule.icon)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(accentColor)
                                        .frame(width: 22, alignment: .center)

                                    Text(rule.text)
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.85) : Color.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                        .padding(.bottom, 4)
                        .transition(.opacity)
                    }
                }
                .clipped()
                .padding(.top, 14)

                // Start button
                Button(action: onStart) {
                    Text("Start")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(accentColor)
                        .cornerRadius(14)
                }
                .padding(.top, 16)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 26)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
                    .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 6)
            )
            .padding(.horizontal, 36)
        }
        .transition(.opacity)
        .onAppear {
            showRules = showRulesInitially
        }
    }
}
