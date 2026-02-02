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
                .fill(colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#e2e8f0"))
                .frame(height: 1)

            // Tab Items
            HStack(spacing: 0) {
                ForEach(TabItem.allCases, id: \.self) { tab in
                    TabBarItem(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        colorScheme: colorScheme
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .background(
            (colorScheme == .dark ? Color.backgroundDark : Color.white)
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
                            .shadow(color: Color.ucdGold.opacity(0.3), radius: 4, x: 0, y: 2)

                        Image(systemName: tab.iconFilled)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Color.ucdBlue)
                    }
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
