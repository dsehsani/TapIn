//
//  ClueListView.swift
//  TapInApp
//
//  MARK: - View Layer
//  Tabbed list of across and down clues.
//

import SwiftUI

/// Tabbed view showing across and down clues
struct ClueListView: View {
    let puzzle: CrosswordPuzzle?
    let selectedClue: CrosswordClue?
    let onSelectClue: (CrosswordClue) -> Void
    let colorScheme: ColorScheme

    @State private var selectedTab: CrosswordDirection = .across

    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            HStack(spacing: 0) {
                TabButton(
                    title: "Across",
                    isSelected: selectedTab == .across,
                    colorScheme: colorScheme,
                    onTap: { selectedTab = .across }
                )

                TabButton(
                    title: "Down",
                    isSelected: selectedTab == .down,
                    colorScheme: colorScheme,
                    onTap: { selectedTab = .down }
                )
            }
            .padding(.horizontal, 8)

            // Clue list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        let clues = selectedTab == .across
                            ? (puzzle?.acrossClues ?? [])
                            : (puzzle?.downClues ?? [])

                        ForEach(clues) { clue in
                            ClueRowView(
                                clue: clue,
                                isSelected: selectedClue?.id == clue.id,
                                colorScheme: colorScheme,
                                onTap: { onSelectClue(clue) }
                            )
                            .id(clue.id)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .onChange(of: selectedClue) { oldValue, newValue in
                    // Auto-scroll to selected clue
                    if let clue = newValue {
                        if clue.direction != selectedTab {
                            selectedTab = clue.direction
                        }
                        withAnimation {
                            proxy.scrollTo(clue.id, anchor: .center)
                        }
                    }
                }
            }
        }
        .background(Color.crosswordClueListBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Tab button for clue direction selection
struct TabButton: View {
    let title: String
    let isSelected: Bool
    let colorScheme: ColorScheme
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? Color.ucdGold : Color.crosswordText(colorScheme))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    VStack {
                        Spacer()
                        if isSelected {
                            Rectangle()
                                .fill(Color.ucdGold)
                                .frame(height: 2)
                        }
                    }
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
#Preview {
    ClueListView(
        puzzle: SamplePuzzles.puzzles.first,
        selectedClue: nil,
        onSelectClue: { _ in },
        colorScheme: .light
    )
    .frame(height: 200)
    .padding()
}
