//
//  SudokuDifficultyPickerView.swift
//  TapInApp
//
//  MARK: - View Layer (MVVM)
//  Difficulty selection sheet.
//

import SwiftUI

/// Sheet view for selecting Sudoku difficulty level.
struct SudokuDifficultyPickerView: View {
    let currentDifficulty: SudokuDifficulty
    let onSelect: (SudokuDifficulty) -> Void

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationView {
            List {
                ForEach(SudokuDifficulty.allCases, id: \.self) { difficulty in
                    Button(action: { onSelect(difficulty) }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(difficulty.displayName)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)

                                Text(difficulty.description)
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if difficulty == currentDifficulty {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(Color.ucdGold)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Select Difficulty")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
