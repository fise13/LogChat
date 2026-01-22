//
//  ChatView.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @Environment(\.modelContext) private var modelContext
    @State private var showImagePicker = false
    @State private var showImageSourceSelection = false
    #if os(iOS)
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    #endif
    @State private var showChatInfo = false
    @FocusState private var isInputFocused: Bool
    
    let chat: Chat?
    var initialMode: AIMode? = nil
    var initialPrompt: String? = nil
    
    var body: some View {
        ZStack {
            // Background - всегда покрывает safe area
            DesignSystem.Background.primary
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with New Chat button and Mode selector
                HeaderView(
                    currentMode: viewModel.currentMode,
                    selectedMode: $viewModel.currentMode,
                    onNewChat: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.createNewChat()
                            isInputFocused = false
                        }
                    }
                )
                .onChange(of: viewModel.currentMode) { oldValue, newValue in
                    viewModel.changeMode(newValue)
                }
                
                Divider()
                
                // Connection status indicator
                if viewModel.connectionState.isActive || viewModel.connectionState != .connected {
                    HStack {
                        ConnectionStateView(state: viewModel.connectionState)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(DesignSystem.Background.secondary)
                }
                
                // Messages ScrollView
                ChatMessagesListView(viewModel: viewModel)
                
                // Memory Suggestions Banner
                #if os(iOS)
                if viewModel.showMemorySuggestions && !viewModel.memorySuggestions.isEmpty {
                    MemorySuggestionView(
                        suggestions: $viewModel.memorySuggestions,
                        isPresented: $viewModel.showMemorySuggestions,
                        onAccept: { suggestion in
                            MemoryService.shared.saveMemory(
                                context: modelContext,
                                type: suggestion.type,
                                key: suggestion.key,
                                content: suggestion.content,
                                importance: suggestion.importance
                            )
                            
                            // Haptic feedback
                            #if os(iOS)
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                            #endif
                        },
                        onDismiss: {
                            // Just dismiss
                        }
                    )
                    .padding(.bottom, 8)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
                #endif
            }
            .safeAreaInset(edge: .bottom) {
                // Input Bar
                #if os(iOS)
                InputBarView(
                    inputText: $viewModel.inputText,
                    selectedImage: $viewModel.selectedImage,
                    isLoading: $viewModel.isLoading,
                    isInputFocused: $isInputFocused,
                    onSend: {
                        isInputFocused = false
                        viewModel.sendMessage()
                    },
                    onImageSelect: {
                        isInputFocused = false
                        showImageSourceSelection = true
                    }
                )
                #else
                InputBarView(
                    inputText: $viewModel.inputText,
                    isLoading: $viewModel.isLoading,
                    isInputFocused: $isInputFocused,
                    onSend: {
                        isInputFocused = false
                        viewModel.sendMessage()
                    },
                    onImageSelect: {
                        // macOS doesn't support image selection in chat
                    }
                )
                #endif
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .principal) {
                if let chat = chat {
                    Text(chat.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                } else {
                    NeoChatLogoView(size: .small, showText: true)
                }
            }
            
            if chat != nil {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showChatInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundColor(DesignSystem.Accent.primary)
                    }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button {
                        showChatInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundColor(DesignSystem.Accent.primary)
                    }
                }
                #endif
            }
        }
        .onAppear {
            print("📱 ChatView appeared, chat: \(chat?.title ?? "nil")")
            let historyService = HistoryService(modelContext: modelContext)
            print("📱 ChatView: ModelContext hash: \(ObjectIdentifier(modelContext).hashValue)")
            viewModel.setup(historyService: historyService, chat: chat, modelContext: modelContext)
            
            // Устанавливаем начальный режим если есть
            if let mode = initialMode {
                viewModel.currentMode = mode
            }
            
            // Устанавливаем начальный промпт если есть
            if let prompt = initialPrompt, !prompt.isEmpty {
                // Небольшая задержка для корректной инициализации
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    viewModel.inputText = prompt
                    isInputFocused = true
                }
            }
        }
        .onChange(of: viewModel.messages.count) { oldValue, newValue in
            // Оптимизировано: сохраняем только при значительных изменениях
            if newValue > oldValue && newValue > 0 && newValue % 3 == 0 {
                // Сохраняем каждые 3 сообщения вместо каждого
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 секунды
                    do {
                        try modelContext.save()
                        
                        // Отправляем уведомление для обновления HistoryView
                        NotificationCenter.default.post(name: NSNotification.Name("ChatSaved"), object: nil)
                    } catch {
                        print("❌ ChatView: Error saving context: \(error)")
                    }
                }
            }
        }
        .onChange(of: viewModel.isStreaming) { _, isStreaming in
            if isStreaming {
                isInputFocused = false
            }
        }
        #if os(iOS)
        .confirmationDialog("Select Source", isPresented: $showImageSourceSelection, titleVisibility: .visible) {
            Button("Photo Library") {
                imageSourceType = .photoLibrary
                showImagePicker = true
            }
            
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Camera") {
                    imageSourceType = .camera
                    showImagePicker = true
                }
            }
            
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(
                sourceType: imageSourceType,
                selectedImage: $viewModel.selectedImage
            )
        }
        #endif
        .sheet(isPresented: $showChatInfo) {
            if let currentChat = viewModel.currentChat {
                ChatInfoSheet(chat: currentChat)
            }
        }
    }
}

#if os(iOS)
struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
#endif
