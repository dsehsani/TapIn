//
//  EventDetailView.swift
//  TapInApp
//
//  Created by Darius Ehsani on 2/10/26.
//

import SwiftUI

struct EventDetailView: View {
    let event: CampusEvent
    @ObservedObject var savedViewModel: SavedViewModel
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {

                    // MARK: - Badge & Event Type
                    HStack(spacing: 8) {
                        Text(event.isOfficial ? "OFFICIAL" : "STUDENT EVENT")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(event.isOfficial ? Color.ucdBlue : Color.ucdGold)
                            .clipShape(Capsule())

                        if let eventType = event.eventType {
                            Text(eventType)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#f1f5f9")
                                )
                                .clipShape(Capsule())
                        }
                    }

                    // MARK: - Title
                    Text(event.title)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))

                    // MARK: - Organizer
                    if let organizer = event.organizerName {
                        HStack(spacing: 8) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color.ucdBlue)
                            Text("Hosted by \(organizer)")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#334155"))
                        }
                    }

                    Divider()

                    // MARK: - Date & Time
                    VStack(alignment: .leading, spacing: 12) {
                        DetailRow(
                            icon: "calendar",
                            title: "Date",
                            value: event.date.formatted(date: .long, time: .omitted),
                            colorScheme: colorScheme
                        )

                        DetailRow(
                            icon: "clock.fill",
                            title: "Time",
                            value: formatTimeRange(),
                            colorScheme: colorScheme
                        )

                        DetailRow(
                            icon: "mappin.circle.fill",
                            title: "Location",
                            value: event.location,
                            colorScheme: colorScheme
                        )
                    }

                    Divider()

                    // MARK: - Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))

                        Text(event.description)
                            .font(.system(size: 15))
                            .foregroundColor(.textMuted)
                            .lineSpacing(4)
                    }

                    // MARK: - Tags
                    if !event.tags.isEmpty {
                        Divider()

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Tags")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))

                            FlowLayout(spacing: 8) {
                                ForEach(event.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#334155"))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#f1f5f9")
                                        )
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    // MARK: - Attend Button
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            savedViewModel.toggleEventSaved(event)
                        }
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: savedViewModel.isEventSaved(event) ? "checkmark.circle.fill" : "plus.circle")
                                .font(.system(size: 18, weight: .semibold))
                            Text(savedViewModel.isEventSaved(event) ? "Attending" : "Attend")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                        }
                        .foregroundColor(savedViewModel.isEventSaved(event) ? .white : (colorScheme == .dark ? .white : Color(hex: "#0f172a")))
                        .padding(.vertical, 14)
                        .background(savedViewModel.isEventSaved(event) ? Color(hex: "#10b981") : (colorScheme == .dark ? Color(hex: "#1e293b") : Color(hex: "#f1f5f9")))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(savedViewModel.isEventSaved(event) ? Color.clear : Color(hex: "#e2e8f0"), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)

                    // MARK: - RSVP Button
                    if let urlString = event.eventURL, let url = URL(string: urlString) {
                        Link(destination: url) {
                            HStack {
                                Spacer()
                                Text("View on Aggie Life")
                                    .font(.system(size: 16, weight: .semibold))
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 14, weight: .semibold))
                                Spacer()
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 14)
                            .background(Color.ucdBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(20)
                .padding(.bottom, 20)
            }
            .background(Color.adaptiveBackground(colorScheme))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatTimeRange() -> String {
        let startTime = event.date.formatted(date: .omitted, time: .shortened)
        if let endDate = event.endDate {
            let endTime = endDate.formatted(date: .omitted, time: .shortened)
            return "\(startTime) – \(endTime)"
        }
        return startTime
    }
}

// MARK: - Detail Row Component

private struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    let colorScheme: ColorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color.ucdBlue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textSecondary)
                Text(value)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white : Color(hex: "#0f172a"))
            }
        }
    }
}

// MARK: - Flow Layout for Tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (positions, CGSize(width: maxWidth, height: y + rowHeight))
    }
}

#Preview {
    EventDetailView(event: CampusEvent.sampleData[0], savedViewModel: SavedViewModel())
}
