//
//  PulsingHotspotModifier.swift
//  TapInApp
//
//  MARK: - Pulsing Hotspot View Modifier
//  Adds a pulsing UC Davis Gold ring to any view. The tooltip itself is
//  rendered at the ContentView level via anchor preferences so it floats
//  above all sibling views.
//

import SwiftUI

// MARK: - Highlight Style

enum OnboardingHighlightStyle {
    /// Rounded-rectangle ring around the element (default).
    case ring
    /// Pulsing gold line along the top edge — suited for full-width bars.
    case topGlow
    /// No visual highlight — tooltip only.
    case none
}

// MARK: - Anchor Preference Key

struct OnboardingTipOverlayInfo {
    let message: String
    let arrowEdge: Edge
    let anchor: Anchor<CGRect>
}

struct OnboardingTipOverlayKey: PreferenceKey {
    static var defaultValue: [OnboardingTip: OnboardingTipOverlayInfo] = [:]

    static func reduce(
        value: inout [OnboardingTip: OnboardingTipOverlayInfo],
        nextValue: () -> [OnboardingTip: OnboardingTipOverlayInfo]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// MARK: - Modifier

struct PulsingHotspotModifier: ViewModifier {
    let tip: OnboardingTip
    let message: String
    let arrowEdge: Edge
    let condition: Bool
    let cornerRadius: CGFloat
    let ringInset: CGFloat
    let highlightStyle: OnboardingHighlightStyle

    @State private var isPulsing = false

    private var manager: OnboardingManager { .shared }
    private var isVisible: Bool { manager.shouldShowTip(tip) }

    func body(content: Content) -> some View {
        content
            // Highlight overlay (local — stays on the element)
            .overlay {
                if isVisible {
                    switch highlightStyle {
                    case .ring:
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.ucdGold, lineWidth: 2.5)
                            .padding(ringInset)
                            .scaleEffect(isPulsing ? 1.04 : 1.0)
                            .opacity(isPulsing ? 0.4 : 1.0)
                            .animation(
                                .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                                value: isPulsing
                            )
                            .allowsHitTesting(false)
                            .onAppear { isPulsing = true }

                    case .topGlow:
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.ucdGold)
                                .frame(height: 2.5)
                                .shadow(color: Color.ucdGold.opacity(0.8), radius: isPulsing ? 12 : 4)
                                .opacity(isPulsing ? 1.0 : 0.4)
                                .animation(
                                    .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                                    value: isPulsing
                                )
                                .onAppear { isPulsing = true }
                            Spacer()
                        }
                        .allowsHitTesting(false)

                    case .none:
                        EmptyView()
                    }
                }
            }
            // Report frame to ContentView so it can render the tooltip overlay
            .anchorPreference(key: OnboardingTipOverlayKey.self, value: .bounds) { anchor in
                isVisible
                    ? [tip: OnboardingTipOverlayInfo(message: message, arrowEdge: arrowEdge, anchor: anchor)]
                    : [:]
            }
            .onAppear {
                if condition {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        manager.requestTip(tip)
                    }
                } else {
                    manager.skipTipIfNeeded(tip)
                }
            }
            // Auto-advance: when the previous tip is dismissed, try to claim the next one
            .onChange(of: manager.activeTip) { _, newTip in
                if newTip == nil {
                    if condition {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            manager.requestTip(tip)
                        }
                    } else {
                        manager.skipTipIfNeeded(tip)
                    }
                }
            }
    }
}

// MARK: - Convenience Extension

extension View {
    /// Attach a pulsing onboarding hotspot to this view.
    /// - Parameters:
    ///   - tip: Which onboarding tip this represents.
    ///   - message: Tooltip copy.
    ///   - arrowEdge: `.top` = arrow points up (tooltip below), `.bottom` = arrow points down (tooltip above).
    ///   - condition: Extra gate — if `false`, the tip is auto-skipped (default `true`).
    ///   - cornerRadius: Corner radius for the pulsing ring (default `16`).
    ///   - ringInset: Inset the pulsing ring from the view bounds (default `0`).
    ///   - highlightStyle: Visual style — `.ring` (default) or `.topGlow` for full-width bars.
    func pulsingHotspot(
        tip: OnboardingTip,
        message: String,
        arrowEdge: Edge,
        condition: Bool = true,
        cornerRadius: CGFloat = 16,
        ringInset: CGFloat = 0,
        highlightStyle: OnboardingHighlightStyle = .ring
    ) -> some View {
        modifier(PulsingHotspotModifier(
            tip: tip,
            message: message,
            arrowEdge: arrowEdge,
            condition: condition,
            cornerRadius: cornerRadius,
            ringInset: ringInset,
            highlightStyle: highlightStyle
        ))
    }
}
