//
//  TagChipView.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import SwiftUI

struct TagChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(isSelected ? .white : color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? color : color.opacity(0.1))
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

