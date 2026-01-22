//
//  ConnectionStateView.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import SwiftUI

struct ConnectionStateView: View {
    let state: ChatViewModel.ConnectionState
    
    var body: some View {
        HStack(spacing: 8) {
            icon
            Text(state.displayText)
                .font(.caption)
                .foregroundColor(textColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var icon: some View {
        Group {
            switch state {
            case .connected:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .connecting:
                ProgressView()
                    .scaleEffect(0.8)
            case .streaming:
                Image(systemName: "circle.fill")
                    .foregroundColor(.blue)
                    .symbolEffect(.pulse)
            case .retrying:
                Image(systemName: "arrow.clockwise.circle.fill")
                    .foregroundColor(.orange)
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            case .offline:
                Image(systemName: "wifi.slash")
                    .foregroundColor(.gray)
            }
        }
    }
    
    private var textColor: Color {
        switch state {
        case .connected, .streaming:
            return .secondary
        case .connecting, .retrying:
            return .primary
        case .failed:
            return .red
        case .offline:
            return .gray
        }
    }
}
