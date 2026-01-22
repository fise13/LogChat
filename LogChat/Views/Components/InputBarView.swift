//
//  InputBarView.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

struct InputBarView: View {
    @Binding var inputText: String
    @Binding var isLoading: Bool
    @FocusState.Binding var isInputFocused: Bool
    let onSend: () -> Void
    let onImageSelect: () -> Void
    
    #if os(iOS)
    @Binding var selectedImage: UIImage?
    
    private var hasImage: Bool {
        selectedImage != nil
    }
    
    init(
        inputText: Binding<String>,
        selectedImage: Binding<UIImage?>,
        isLoading: Binding<Bool>,
        isInputFocused: FocusState<Bool>.Binding,
        onSend: @escaping () -> Void,
        onImageSelect: @escaping () -> Void
    ) {
        self._inputText = inputText
        self._selectedImage = selectedImage
        self._isLoading = isLoading
        self._isInputFocused = isInputFocused
        self.onSend = onSend
        self.onImageSelect = onImageSelect
    }
    #else
    private var hasImage: Bool {
        false
    }
    
    init(
        inputText: Binding<String>,
        isLoading: Binding<Bool>,
        isInputFocused: FocusState<Bool>.Binding,
        onSend: @escaping () -> Void,
        onImageSelect: @escaping () -> Void
    ) {
        self._inputText = inputText
        self._isLoading = isLoading
        self._isInputFocused = isInputFocused
        self.onSend = onSend
        self.onImageSelect = onImageSelect
    }
    #endif
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            // Image Button
            #if os(iOS)
            Button(action: onImageSelect) {
                Image(systemName: selectedImage != nil ? "photo.fill" : "photo")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(selectedImage != nil ? DesignSystem.Message.userBubble : .secondary)
                    .frame(width: 40, height: 40)
                    .background(DesignSystem.Input.background)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add image")
            .accessibilityHint("Tap to add an image to your message")
            #endif
            
            // Image Preview
            #if os(iOS)
            if let selectedImage = selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        Button(action: {
                            self.selectedImage = nil
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .padding(4),
                        alignment: .topTrailing
                    )
            }
            #endif
            
            // Text Input
            TextField("Type a message...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .focused($isInputFocused)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(DesignSystem.Input.background)
                .cornerRadius(DesignSystem.CornerRadius.inputField)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.inputField)
                        .stroke(isInputFocused ? DesignSystem.Input.borderFocused : DesignSystem.Input.border, lineWidth: 1)
                )
                .lineLimit(1...10)
                .disabled(isLoading)
                .onSubmit {
                    if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onSend()
                    }
                }
                .accessibilityLabel("Message input")
                .accessibilityHint("Type your message here")
            
            // Send Button
            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(
                        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !hasImage
                            ? .secondary
                            : DesignSystem.Accent.primary
                    )
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !hasImage || isLoading)
            .buttonStyle(.plain)
            .accessibilityLabel("Send message")
            .accessibilityHint("Tap to send your message")
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(DesignSystem.Background.primary)
    }
}
