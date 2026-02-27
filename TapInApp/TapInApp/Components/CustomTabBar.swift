//
//  CustomTabBar.swift
//  TapInApp
//
//  Created by Darius Ehsani on 1/29/26.
//

import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: TabItem

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Divider
            Rectangle()
                .fill(colorScheme == .dark ? Color(hex: "#1a1060").opacity(0.4) : Color.accentOrange.opacity(0.15))
                .frame(height: 1)

            // Tab Items
            HStack(spacing: 0) {
                ForEach(TabItem.legacyTabs, id: \.self) { tab in
                    TabBarItem(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        colorScheme: colorScheme
                    ) {
                        selectedTab = tab
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .background(
            (colorScheme == .dark ? Color.navyDeep : Color.white)
                .opacity(0.95)
        )
    }
}

struct TabBarItem: View {
    let tab: TabItem
    let isSelected: Bool
    let colorScheme: ColorScheme
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                if tab == .games {
                    // Prominent Games Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.ucdGold)
                            .frame(width: 44, height: 44)
                            .shadow(color: Color.ucdGold.opacity(isSelected ? 0.5 : 0.3), radius: isSelected ? 6 : 4, x: 0, y: 2)

                        Image(systemName: tab.iconFilled)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .opacity(isSelected ? 1.0 : 0.6)
                    .offset(y: -4)
                } else {
                    // Regular Tab Icon
                    Image(systemName: isSelected ? tab.iconFilled : tab.icon)
                        .font(.system(size: 22))
                        .foregroundColor(
                            isSelected
                                ? (colorScheme == .dark ? Color.ucdGold : Color.ucdBlue)
                                : .textSecondary
                        )
                }

                // Label
                Text(tab.rawValue)
                    .font(.system(size: 10, weight: isSelected || tab == .games ? .bold : .semibold))
                    .foregroundColor(
                        tab == .games
                            ? (colorScheme == .dark ? Color.ucdGold : Color.ucdBlue)
                            : (isSelected
                                ? (colorScheme == .dark ? Color.ucdGold : Color.ucdBlue)
                                : .textSecondary)
                    )
            }
            .frame(maxWidth: .infinity)
            .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    VStack {
        Spacer()
        CustomTabBar(selectedTab: .constant(.news))
    }
    .background(Color.backgroundLight)
}
