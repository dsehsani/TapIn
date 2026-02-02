//
//  ShapeItemView.swift
//  TapInApp
//
//  MARK: - View Layer (MVVM)
//  Renders a single EchoItem as a colored SF Symbol shape.
//  Used in sequence display, player input, and feedback screens.
//

import SwiftUI

// MARK: - Shape Item View
struct ShapeItemView: View {
    let item: EchoItem
    var size: CGFloat = 50
    var showBorder: Bool = false
    var borderColor: Color = .clear

    var body: some View {
        ZStack {
            // Background container
            RoundedRectangle(cornerRadius: 12)
                .fill(item.color.swiftUIColor.opacity(0.15))
                .frame(width: size + 16, height: size + 16)

            // Shape icon
            Image(systemName: item.shape.symbolName)
                .font(.system(size: size * 0.7))
                .foregroundColor(item.color.swiftUIColor)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(showBorder ? borderColor : Color.clear, lineWidth: 3)
                .frame(width: size + 16, height: size + 16)
        )
    }
}

#Preview {
    HStack(spacing: 12) {
        ShapeItemView(item: EchoItem(shape: .triangle, color: .red))
        ShapeItemView(item: EchoItem(shape: .circle, color: .blue))
        ShapeItemView(item: EchoItem(shape: .square, color: .yellow), showBorder: true, borderColor: .green)
        ShapeItemView(item: EchoItem(shape: .pentagon, color: .green))
    }
    .padding()
}
