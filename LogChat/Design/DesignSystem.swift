//
//  DesignSystem.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import SwiftUI
import Combine
#if os(iOS)
import UIKit
#endif

// MARK: - Theme Support
enum AppTheme: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case auto = "auto"
    
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .auto: return "Auto"
        }
    }
}

// MARK: - Customization Settings
class DesignSettings: ObservableObject {
    @Published var theme: AppTheme {
        willSet {
            UserDefaults.standard.set(newValue.rawValue, forKey: "appTheme")
        }
    }
    
    @Published var fontSize: Double {
        willSet {
            UserDefaults.standard.set(newValue, forKey: "fontSize")
        }
    }
    
    @Published var sidebarWidth: Double {
        willSet {
            UserDefaults.standard.set(newValue, forKey: "sidebarWidth")
        }
    }
    
    @Published var panelSpacing: Double {
        willSet {
            UserDefaults.standard.set(newValue, forKey: "panelSpacing")
        }
    }
    
    static let shared = DesignSettings()
    
    private init() {
        // Загружаем значения из UserDefaults
        let themeString = UserDefaults.standard.string(forKey: "appTheme") ?? "auto"
        let loadedTheme = AppTheme(rawValue: themeString) ?? .auto
        let loadedFontSize = UserDefaults.standard.double(forKey: "fontSize")
        let loadedSidebarWidth = UserDefaults.standard.double(forKey: "sidebarWidth")
        let loadedPanelSpacing = UserDefaults.standard.double(forKey: "panelSpacing")
        
        // Инициализируем без вызова willSet
        self.theme = loadedTheme
        self.fontSize = loadedFontSize == 0 ? 1.0 : loadedFontSize
        self.sidebarWidth = loadedSidebarWidth == 0 ? 250.0 : loadedSidebarWidth
        self.panelSpacing = loadedPanelSpacing == 0 ? 16.0 : loadedPanelSpacing
    }
}

struct DesignSystem {
    // MARK: - Colors (Unique NeoChat Design - Not copying Apple)
    
    struct Background {
        #if os(iOS)
        static let primary = Color(UIColor.systemBackground)
        static let secondary = Color(UIColor.secondarySystemBackground)
        static let tertiary = Color(UIColor.tertiarySystemBackground)
        static let grouped = Color(UIColor.systemGroupedBackground)
        #endif
    }
    
    struct Message {
        // User message bubble - NeoChat unique gradient
        static let userBubble = Color(hex: "0066FF") // NeoChat blue
        static let userBubbleGradient = LinearGradient(
            colors: [
                Color(hex: "0066FF"),
                Color(hex: "0052CC")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        static let userText = Color.white
        
        // AI message bubble - sophisticated gray with subtle tint
        #if os(iOS)
        static let aiBubble = Color(UIColor.systemGray6)
        static let aiBubbleDark = Color(UIColor.systemGray5)
        static let codeBackground = Color(UIColor.systemGray6)
        static let codeBackgroundDark = Color(UIColor.systemGray5)
        static let codeBorder = Color(UIColor.separator).opacity(0.3)
        #endif
        static let aiText = Color.primary
        
        // Status colors for Research Mode
        struct Status {
            static let analyzing = Color(hex: "0066FF") // Blue
            static let clarifying = Color(hex: "FF9500") // Orange
            static let researching = Color(hex: "AF52DE") // Purple
            static let synthesizing = Color(hex: "34C759") // Green
            static let complete = Color(hex: "8E8E93") // Gray
        }
    }
    
    struct Input {
        #if os(iOS)
        static let background = Color(UIColor.systemGray6)
        static let backgroundFocused = Color(UIColor.systemGray5)
        static let border = Color(UIColor.separator).opacity(0.5)
        static let borderFocused = Color(red: 0.0, green: 0.48, blue: 1.0).opacity(0.3)
        #endif
    }
    
    struct Accent {
        // NeoChat primary accent - vibrant blue
        static let primary = Color(hex: "0066FF")
        static let primaryLight = Color(hex: "007AFF")
        static let primaryDark = Color(hex: "0052CC")
        
        #if os(iOS)
        static let secondary = Color(UIColor.systemBlue)
        static let success = Color(UIColor.systemGreen)
        static let warning = Color(UIColor.systemOrange)
        static let danger = Color(UIColor.systemRed)
        static let info = Color(hex: "5AC8FA") // Light blue
        #endif
    }
    
    
    // MARK: - Shadows
    
    struct Shadow {
        static let small = ShadowStyle(
            color: Color.black.opacity(0.1),
            radius: 4,
            x: 0,
            y: 2
        )
        static let medium = ShadowStyle(
            color: Color.black.opacity(0.15),
            radius: 8,
            x: 0,
            y: 4
        )
        static let large = ShadowStyle(
            color: Color.black.opacity(0.2),
            radius: 16,
            x: 0,
            y: 8
        )
    }
    
    struct ShadowStyle {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
    
    // MARK: - Spacing
    
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Typography
    
    struct Typography {
        static let largeTitle = Font.system(.largeTitle, design: .default, weight: .bold)
        static let title = Font.system(.title, design: .default, weight: .semibold)
        static let title2 = Font.system(.title2, design: .default, weight: .semibold)
        static let title3 = Font.system(.title3, design: .default, weight: .semibold)
        static let headline = Font.system(.headline, design: .default, weight: .semibold)
        static let body = Font.system(.body, design: .default)
        static let bodyBold = Font.system(.body, design: .default, weight: .semibold)
        static let bodyMonospaced = Font.system(.body, design: .monospaced)
        static let callout = Font.system(.callout, design: .default)
        static let subheadline = Font.system(.subheadline, design: .default)
        static let footnote = Font.system(.footnote, design: .default)
        static let caption = Font.system(.caption, design: .default)
        static let caption2 = Font.system(.caption2, design: .default)
        
        // Markdown-specific typography
        struct Markdown {
            static let heading1 = Font.system(.title2, design: .default, weight: .bold)
            static let heading2 = Font.system(.title3, design: .default, weight: .bold)
            static let heading3 = Font.system(.headline, design: .default, weight: .semibold)
            static let paragraph = Font.system(.body, design: .default)
            static let listItem = Font.system(.body, design: .default)
            static let code = Font.system(.body, design: .monospaced)
            static let codeBlock = Font.system(.body, design: .monospaced)
            static let emphasis = Font.system(.body, design: .default)
            static let strong = Font.system(.body, design: .default, weight: .semibold)
        }
        
        // Line spacing
        static let bodyLineSpacing: CGFloat = 6
        static let paragraphSpacing: CGFloat = 12
    }
    
    // MARK: - Corner Radius
    
    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let messageBubble: CGFloat = 20
        static let inputField: CGFloat = 22
        static let card: CGFloat = 16
    }
    
    // MARK: - Message Bubble Constants
    
    struct MessageBubble {
        static let cornerRadius: CGFloat = CornerRadius.messageBubble
        static let maxWidth: CGFloat = 300
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 12
        static let shadow = Shadow.small
        static let spacing: CGFloat = 12
    }
    
    // MARK: - Animation
    
    struct Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.5)
        static let spring = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.8)
        
        // Enhanced animations for NeoChat
        static let messageAppear = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.85)
        static let fadeIn = SwiftUI.Animation.easeOut(duration: 0.25)
        static let scaleIn = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.75)
        static let slideIn = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.8)
        
        // Text typing animation
        static let textTyping = SwiftUI.Animation.linear(duration: 0.05)
        
        // Panel transitions
        static let panelSlide = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.85)
    }
}

// MARK: - Color Extension for Hex Support
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Extensions

extension View {
    func shadow(_ style: DesignSystem.ShadowStyle) -> some View {
        self.shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
    
    func cardStyle() -> some View {
        self
            .background(DesignSystem.Background.secondary)
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .shadow(DesignSystem.Shadow.small)
    }
}

// MARK: - Corner Radius Extension

#if os(iOS)
import UIKit
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
#endif
