//
//  CampusView.swift
//  TapInApp
//
//  Created by Darius Ehsani on 1/29/26.
//

import SwiftUI

struct CampusView: View {
    @ObservedObject var viewModel: CampusViewModel

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            Color.adaptiveBackground(colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Header
                HStack {
                    Text("Campus Events")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : Color.ucdBlue)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                // Filter Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(EventFilterType.allCases, id: \.self) { filter in
                            Button(action: {
                                viewModel.filterEvents(by: filter)
                            }) {
                                Text(filter.rawValue)
                                    .font(.system(size: 14, weight: viewModel.filterType == filter ? .semibold : .medium))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        viewModel.filterType == filter
                                            ? Color.ucdBlue
                                            : (colorScheme == .dark ? Color(hex: "#1e293b") : .white)
                                    )
                                    .foregroundColor(
                                        viewModel.filterType == filter
                                            ? .white
                                            : (colorScheme == .dark ? .white : Color(hex: "#334155"))
                                    )
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(
                                                viewModel.filterType == filter
                                                    ? Color.clear
                                                    : Color(hex: "#e2e8f0"),
                                                lineWidth: 1
                                            )
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                // Events List
                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Loading events...")
                    Spacer()
                } else if viewModel.events.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 48))
                            .foregroundColor(.textSecondary)
                        Text("No events found")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.textSecondary)
                    }
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.events) { event in
                                EventCard(event: event, colorScheme: colorScheme)
                                    .padding(.horizontal, 16)
                            }
                        }
                        .padding(.bottom, 8)
                    }
                    .refreshable {
                        await viewModel.refreshEvents()
                    }
                }
            }
        }
    }
}

struct EventCard: View {
    let event: CampusEvent
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(event.isOfficial ? "OFFICIAL" : "STUDENT EVENT")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundColor(event.isOfficial ? Color.ucdBlue : Color.ucdGold)
                Spacer()
                Text(event.date, style: .date)
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
            }

            Text(event.title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))

            Text(event.description)
                .font(.system(size: 14))
                .foregroundColor(.textMuted)
                .lineLimit(2)

            HStack(spacing: 6) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color.ucdBlue)
                Text(event.location)
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(16)
        .background(colorScheme == .dark ? Color(hex: "#0f172a") : .white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#f1f5f9"),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    CampusView(viewModel: CampusViewModel())
}

