//
//  NotificationBellSheet.swift
//  TapInApp
//
//  Sheet presented from the notification bell in the News tab header.
//  Shows upcoming saved events and 1-2 "For You" suggestions.
//

import SwiftUI

struct NotificationBellSheet: View {
    @ObservedObject var savedViewModel: SavedViewModel
    @ObservedObject var notificationsViewModel: NotificationsViewModel
    @ObservedObject var campusViewModel: CampusViewModel

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    @State private var selectedEvent: CampusEvent?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {

                    // MARK: - Your Upcoming Events
                    upcomingEventsSection

                    // MARK: - For You
                    forYouSection
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color.adaptiveBackground(colorScheme))
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            notificationsViewModel.markAllAsSeen()
        }
        .sheet(item: $selectedEvent) { event in
            EventDetailView(event: event, savedViewModel: savedViewModel)
        }
    }

    // MARK: - Upcoming Events Section

    @ViewBuilder
    private var upcomingEventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 16, weight: .semibold))
                Text("Your Upcoming Events")
                    .font(.system(size: 18, weight: .bold))
            }
            .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))
            .padding(.horizontal, 16)

            let upcoming = savedViewModel.upcomingEvents
            if upcoming.isEmpty {
                emptyState(
                    icon: "calendar",
                    message: "No upcoming saved events.\nSave events to get reminders!"
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(upcoming) { event in
                        eventRow(event: event)
                            .onTapGesture { selectedEvent = event }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - For You Section

    @ViewBuilder
    private var forYouSection: some View {
        let suggestions = notificationsViewModel.suggestedEvents(
            allEvents: campusViewModel.allEvents,
            savedEvents: savedViewModel.savedEvents
        )

        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                    Text("For You")
                        .font(.system(size: 18, weight: .bold))
                }
                .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))
                .padding(.horizontal, 16)

                VStack(spacing: 8) {
                    ForEach(suggestions) { event in
                        eventRow(event: event, isForYou: true)
                            .onTapGesture { selectedEvent = event }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Event Row

    private func eventRow(event: CampusEvent, isForYou: Bool = false) -> some View {
        HStack(spacing: 12) {
            // Date urgency badge
            VStack(spacing: 2) {
                Text(event.friendlyDateLabel)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(event.dateUrgency.badgeColor == .clear
                                       ? (colorScheme == .dark ? Color(hex: "#374151") : Color(hex: "#94a3b8"))
                                       : event.dateUrgency.badgeColor)
                    )
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(event.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))
                        .lineLimit(2)

                    if isForYou {
                        Text("For You")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(
                                    colorScheme == .dark ? Color.accentOrange : Color.accentCoral
                                )
                            )
                    }
                }

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                    Text(event.date.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 13))

                    Text("·")

                    Image(systemName: "mappin")
                        .font(.system(size: 11))
                    Text(event.location)
                        .font(.system(size: 13))
                        .lineLimit(1)
                }
                .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(colorScheme == .dark ? Color(hex: "#1e293b") : .white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colorScheme == .dark ? Color(hex: "#334155") : Color(hex: "#e2e8f0"), lineWidth: 1)
        )
    }

    // MARK: - Empty State

    private func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}
