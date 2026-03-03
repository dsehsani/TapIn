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

    private var manager: OnboardingManager { .shared }
    private var isVisible: Bool { manager.shouldShowTip(tip) }

    func body(content: Content) -> some View {
        content
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
            .onChange(of: manager.activeTip) { _, newTip in
                if newTip == nil, condition {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        manager.requestTip(tip)
                    }
                }
            }
    }
}

// MARK: - Convenience Extension

extension View {
    /// Attach an onboarding tooltip to this view.
    /// - Parameters:
    ///   - tip: Which onboarding tip this represents.
    ///   - message: Tooltip copy.
    ///   - arrowEdge: `.top` = arrow points up (tooltip below), `.bottom` = arrow points down (tooltip above).
    ///   - condition: Extra gate — if `false`, the tip is auto-skipped (default `true`).
    func pulsingHotspot(
        tip: OnboardingTip,
        message: String,
        arrowEdge: Edge,
        condition: Bool = true,
        cornerRadius: CGFloat = 16
    ) -> some View {
        modifier(PulsingHotspotModifier(
            tip: tip,
            message: message,
            arrowEdge: arrowEdge,
            condition: condition
        ))
    }
}
