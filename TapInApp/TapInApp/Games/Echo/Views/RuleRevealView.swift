//
//  RuleRevealView.swift
//  TapInApp
//
//  MARK: - View Layer (MVVM)
//  Reveals transformation rules one by one during the revealingRules phase.
//  Each rule card slides in from the trailing edge with a staggered delay.
//

import SwiftUI

// MARK: - Rule Reveal View
struct RuleRevealView: View {
    let rules: [EchoRule]
    let revealedCount: Int
    var colorScheme: ColorScheme = .light

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Instruction text
            Text("Apply these rules")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(colorScheme == .dark ? .white : Color.textPrimary)

            // Rule cards
            VStack(spacing: 16) {
                ForEach(Array(rules.enumerated()), id: \.offset) { index, rule in
                    if index < revealedCount {
                        RuleCard(
                            ruleNumber: index + 1,
                            rule: rule,
                            colorScheme: colorScheme
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                }
            }
            .padding(.horizontal, 24)

            if revealedCount < rules.count {
                // Loading indicator for next rule
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(Color.ucdGold)
                    Text("Next rule...")
                        .font(.system(size: 14))
                        .foregroundColor(.textSecondary)
                }
                .padding(.top, 8)
            }

            Spacer()
        }
    }
}

// MARK: - Rule Card
struct RuleCard: View {
    let ruleNumber: Int
    let rule: EchoRule
    var colorScheme: ColorScheme = .light

    var body: some View {
        HStack(spacing: 16) {
            // Rule number badge
            ZStack {
                Circle()
                    .fill(Color.ucdGold)
                    .frame(width: 36, height: 36)
                Text("\(ruleNumber)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.ucdBlue)
            }

            // Rule icon
            Image(systemName: rule.iconName)
                .font(.system(size: 22))
                .foregroundColor(Color.ucdGold)
                .frame(width: 30)

            // Rule text
            VStack(alignment: .leading, spacing: 4) {
                Text(rule.displayName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? .white : Color.textPrimary)
                Text(rule.ruleDescription)
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)
            }

            Spacer()
        }
        .padding(16)
        .background(colorScheme == .dark ? Color(hex: "#0f172a") : .white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#f1f5f9"), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

#Preview {
    VStack {
        RuleRevealView(
            rules: [.reversed, .colorSwapped],
            revealedCount: 2
        )
    }
    .background(Color.adaptiveBackground(.light))
}
