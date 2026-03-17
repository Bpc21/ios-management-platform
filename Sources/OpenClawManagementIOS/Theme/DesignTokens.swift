import SwiftUI

/// Executive Dashboard Design Tokens
/// Strictly adheres to high-contrast, professional, data-dense aesthetics.
/// No neon, glows, or spatial features.
public enum OC {
    public enum Colors {
        // Backgrounds
        public static let background = Color("OCBackground", bundle: .main) // Defines true black or pure white in Assets
        public static let surface = Color("OCSurface", bundle: .main)
        public static let surfaceElevated = Color("OCSurfaceElevated", bundle: .main)
        
        // Text
        public static let textPrimary = Color.primary
        public static let textSecondary = Color.secondary
        public static let textTertiary = Color(white: 0.5)
        
        // Accents (Strictly professional, no neon)
        public static let accent = Color.accentColor // e.g., Slate Blue or Deep Forest set in Assets
        public static let success = Color.green.opacity(0.8)
        public static let warning = Color.orange.opacity(0.8)
        public static let destructive = Color.red.opacity(0.8)
        
        // Borders and States
        public static let border = Color.gray.opacity(0.2)
        public static let surfaceDisabled = Color.gray.opacity(0.1)
    }
    
    public enum Typography {
        // We use system fonts with careful weights
        public static let hero = Font.system(size: 34, weight: .black, design: .default)
        public static let h1 = Font.system(size: 28, weight: .bold, design: .default)
        public static let h2 = Font.system(size: 22, weight: .semibold, design: .default)
        public static let h3 = Font.system(size: 18, weight: .medium, design: .default)
        
        public static let body = Font.system(size: 16, weight: .regular, design: .default)
        public static let bodyMedium = Font.system(size: 16, weight: .medium, design: .default)
        public static let callout = Font.system(size: 14, weight: .regular, design: .default)
        public static let caption = Font.system(size: 12, weight: .medium, design: .default)
        
        // Strict SF Mono for UUIDs, Logs, and Data
        public static let mono = Font.system(size: 14, weight: .medium, design: .monospaced)
        public static let monoSmall = Font.system(size: 12, weight: .regular, design: .monospaced)
    }
    
    public enum Spacing {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 24
        public static let xl: CGFloat = 32
        public static let xxl: CGFloat = 48
    }
    
    public enum Radius {
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let pill: CGFloat = 999
    }
}

// MARK: - View Modifiers

public struct OCCardModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    public func body(content: Content) -> some View {
        content
            .padding(OC.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: OC.Radius.md, style: .continuous)
                    .fill(OC.Colors.surface)
            )
            // Subtle border acting as elevation in dark mode, pure shadow in light mode
            .overlay(
                RoundedRectangle(cornerRadius: OC.Radius.md, style: .continuous)
                    .stroke(OC.Colors.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(colorScheme == .light ? 0.05 : 0.0), radius: 8, x: 0, y: 4)
    }
}

public extension View {
    func ocCard() -> some View {
        modifier(OCCardModifier())
    }
}
