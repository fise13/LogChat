//
//  MarkdownContentView.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

struct MarkdownContentView: View {
    let text: String
    var language: String? = nil
    var onCopy: ((String) -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Typography.paragraphSpacing) {
            let parts = parseMarkdown(text)
            ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                if part.isCode {
                    CodeBlockView(
                        code: part.text,
                        language: part.language,
                        onCopy: onCopy
                    )
                    .padding(.top, index > 0 ? 4 : 0)
                } else {
                    FormattedTextView(text: part.text)
                        .padding(.top, index > 0 ? 2 : 0)
                }
            }
        }
    }
    
    private func parseMarkdown(_ text: String) -> [(text: String, isCode: Bool, language: String?)] {
        var result: [(text: String, isCode: Bool, language: String?)] = []
        var currentIndex = text.startIndex
        
        while currentIndex < text.endIndex {
            if let codeStart = text.range(of: "```", range: currentIndex..<text.endIndex) {
                if codeStart.lowerBound > currentIndex {
                    let textPart = String(text[currentIndex..<codeStart.lowerBound])
                    if !textPart.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        result.append((textPart, false, nil))
                    }
                }
                
                if let codeEnd = text.range(of: "```", range: codeStart.upperBound..<text.endIndex) {
                    let codeBlock = String(text[codeStart.upperBound..<codeEnd.lowerBound])
                    let lines = codeBlock.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
                    
                    var detectedLang: String? = nil
                    var codeText = codeBlock
                    
                    if let firstLine = lines.first {
                        let firstLineStr = String(firstLine).trimmingCharacters(in: .whitespaces)
                        if firstLineStr.count < 20 && !firstLineStr.contains(" ") {
                            detectedLang = firstLineStr.lowercased()
                            codeText = lines.count > 1 ? lines.dropFirst().joined(separator: "\n") : ""
                        } else {
                            detectedLang = CodeService.shared.detectLanguage(from: codeBlock)
                        }
                    } else {
                        detectedLang = CodeService.shared.detectLanguage(from: codeBlock)
                    }
                    
                    result.append((codeText, true, detectedLang))
                    currentIndex = codeEnd.upperBound
                } else {
                    let remaining = String(text[codeStart.lowerBound...])
                    result.append((remaining, false, nil))
                    break
                }
            } else {
                let remaining = String(text[currentIndex...])
                if !remaining.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    result.append((remaining, false, nil))
                }
                break
            }
        }
        
        return result.isEmpty ? [(text, false, nil)] : result
    }
}

struct FormattedTextView: View {
    let text: String
    @State private var animatedText: String = ""
    
    var body: some View {
        // Enhanced markdown parsing with bold, italic, and color support
        let attributedText = parseMarkdownText(text)
        
        Text(attributedText)
            .font(DesignSystem.Typography.Markdown.paragraph)
            .foregroundColor(DesignSystem.Message.aiText)
            .lineSpacing(DesignSystem.Typography.bodyLineSpacing)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func parseMarkdownText(_ text: String) -> AttributedString {
        var attributedString = AttributedString(text)
        
        // Parse bold (**text**)
        let boldPattern = #"\*\*(.+?)\*\*"#
        if let regex = try? NSRegularExpression(pattern: boldPattern, options: []) {
            let nsString = text as NSString
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for match in matches.reversed() {
                if match.numberOfRanges > 1 {
                    let range = Range(match.range(at: 1), in: text)!
                    let boldText = String(text[range])
                    if let attributedRange = Range(match.range, in: attributedString) {
                        attributedString.replaceSubrange(attributedRange, with: AttributedString(boldText))
                        if let newRange = Range(match.range(at: 1), in: attributedString) {
                            attributedString[newRange].font = DesignSystem.Typography.Markdown.strong
                        }
                    }
                }
            }
        }
        
        // Parse italic (*text*)
        let italicPattern = #"(?<!\*)\*([^*]+?)\*(?!\*)"#
        if let regex = try? NSRegularExpression(pattern: italicPattern, options: []) {
            let nsString = text as NSString
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for match in matches.reversed() {
                if match.numberOfRanges > 1 {
                    let range = Range(match.range(at: 1), in: text)!
                    let italicText = String(text[range])
                    if let attributedRange = Range(match.range, in: attributedString) {
                        attributedString.replaceSubrange(attributedRange, with: AttributedString(italicText))
                        if let newRange = Range(match.range(at: 1), in: attributedString) {
                            attributedString[newRange].font = DesignSystem.Typography.Markdown.emphasis
                        }
                    }
                }
            }
        }
        
        return attributedString
    }
}

struct CodeBlockView: View {
    let code: String
    let language: String?
    let onCopy: ((String) -> Void)?
    
    private var backgroundColor: Color {
        #if os(iOS)
        return Color(UIColor.systemGray5)
        #endif
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Language label and copy button
            if language != nil || onCopy != nil {
                HStack {
                    if let lang = language, !lang.isEmpty {
                        Text(lang.uppercased())
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(backgroundColor)
                            .cornerRadius(DesignSystem.CornerRadius.small)
                    }
                    
                    Spacer()
                    
                    if let onCopy = onCopy {
                        Button(action: {
                            onCopy(code)
                            #if os(iOS)
                            let generator = UIImpactFeedbackGenerator(style: UIImpactFeedbackGenerator.FeedbackStyle.light)
                            generator.impactOccurred()
                            #endif
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 12, weight: .medium))
                                Text("Copy")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(DesignSystem.Accent.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(DesignSystem.Accent.primary.opacity(0.1))
                            .cornerRadius(DesignSystem.CornerRadius.small)
                        }
                    }
                }
            }
            
            // Code content
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(DesignSystem.Typography.Markdown.codeBlock)
                    .foregroundColor(DesignSystem.Message.aiText)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DesignSystem.Message.codeBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                            .stroke(DesignSystem.Message.codeBorder, lineWidth: 1)
                    )
                    .cornerRadius(DesignSystem.CornerRadius.medium)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Code block\(language.map { " in \($0)" } ?? "")")
        }
    }
}

