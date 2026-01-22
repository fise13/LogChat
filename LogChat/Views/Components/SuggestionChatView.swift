//
//  SuggestionChatView.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import SwiftUI
import SwiftData

struct SuggestionChatView: View {
    let suggestion: Suggestion
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        Group {
            if let chat = suggestion.chat {
                // Продолжаем существующий чат
                ChatView(chat: chat)
                    .navigationTitle(suggestion.title)
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        #if os(iOS)
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Готово") {
                                dismiss()
                            }
                        }
                        #else
                        ToolbarItem(placement: .automatic) {
                            Button("Готово") {
                                dismiss()
                            }
                        }
                        #endif
                    }
            } else {
                // Создаём новый чат с подсказкой
                ChatView(
                    chat: nil,
                    initialMode: suggestion.mode,
                    initialPrompt: suggestion.prompt
                )
                .navigationTitle(suggestion.title)
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    #if os(iOS)
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Готово") {
                            dismiss()
                        }
                    }
                    #else
                    ToolbarItem(placement: .automatic) {
                        Button("Готово") {
                            dismiss()
                        }
                    }
                    #endif
                }
            }
        }
    }
}
