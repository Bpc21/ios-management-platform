import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public enum OC {
    public enum Colors {
        private static func adaptive(
            light: (red: Double, green: Double, blue: Double, alpha: Double),
            dark: (red: Double, green: Double, blue: Double, alpha: Double)
        ) -> Color {
            #if canImport(UIKit)
            return Color(UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(
                        red: dark.red,
                        green: dark.green,
                        blue: dark.blue,
                        alpha: dark.alpha)
                    : UIColor(
                        red: light.red,
                        green: light.green,
                        blue: light.blue,
                        alpha: light.alpha)
            })
            #elseif canImport(AppKit)
            return Color(nsColor: NSColor(name: nil) { appearance in
                let useDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                let value = useDark ? dark : light
                return NSColor(
                    red: value.red,
                    green: value.green,
                    blue: value.blue,
                    alpha: value.alpha)
            })
            #else
            return Color(
                .sRGB,
                red: light.red,
                green: light.green,
                blue: light.blue,
                opacity: light.alpha)
            #endif
        }

        public static let background = Color.clear

        public static var surface: Color {
            adaptive(
                light: (1.0, 1.0, 1.0, 0.58),
                dark: (1.0, 1.0, 1.0, 0.07))
        }

        public static var surfaceElevated: Color {
            adaptive(
                light: (1.0, 1.0, 1.0, 0.76),
                dark: (1.0, 1.0, 1.0, 0.11))
        }

        public static var card: Color { surfaceElevated }

        public static var cardHover: Color {
            adaptive(
                light: (1.0, 1.0, 1.0, 0.86),
                dark: (1.0, 1.0, 1.0, 0.14))
        }

        public static var windowBackground: Color {
            adaptive(
                light: Self.rgba(0xEAEEF5),
                dark: Self.rgba(0x121821))
        }

        public static var windowBackgroundDeep: Color {
            adaptive(
                light: Self.rgba(0xD6DEE9),
                dark: Self.rgba(0x0D1118))
        }

        public static let accent = Color(hex: 0x4B82F3)
        public static let accentLight = Color(hex: 0x5A92FF, alpha: 0.90)
        public static let accentGlow = Color(hex: 0x4B82F3, alpha: 0.14)
        public static let accentSubtle = Color(hex: 0x4B82F3, alpha: 0.08)

        public static var textPrimary: Color {
            adaptive(
                light: Self.rgba(0x1C1C1F),
                dark: (1.0, 1.0, 1.0, 1.0))
        }

        public static var textSecondary: Color {
            adaptive(
                light: Self.rgba(0x1C1C1F, alpha: 0.60),
                dark: (1.0, 1.0, 1.0, 0.68))
        }

        public static var textTertiary: Color {
            adaptive(
                light: Self.rgba(0x1C1C1F, alpha: 0.38),
                dark: (1.0, 1.0, 1.0, 0.42))
        }

        public static var border: Color {
            adaptive(
                light: (0.0, 0.0, 0.0, 0.10),
                dark: (1.0, 1.0, 1.0, 0.14))
        }

        public static var borderSubtle: Color {
            adaptive(
                light: (0.0, 0.0, 0.0, 0.05),
                dark: (1.0, 1.0, 1.0, 0.08))
        }

        public static let borderAccent = Color(hex: 0x4B82F3, alpha: 0.30)

        public static let success = Color(hex: 0x58A86F)
        public static let warning = Color(hex: 0xD79A3D)
        public static let destructive = Color(hex: 0xC95B5B)
        public static let infoBlue = Color(hex: 0x5B88C9)

        public static var glassBackground: Color {
            adaptive(
                light: (0.0, 0.0, 0.0, 0.04),
                dark: (1.0, 1.0, 1.0, 0.05))
        }

        public static var glassBorder: Color {
            adaptive(
                light: (0.0, 0.0, 0.0, 0.10),
                dark: (1.0, 1.0, 1.0, 0.15))
        }

        public static var surfaceDisabled: Color {
            adaptive(
                light: (0.0, 0.0, 0.0, 0.035),
                dark: (1.0, 1.0, 1.0, 0.035))
        }

        private static func rgba(_ hex: UInt, alpha: Double = 1.0) -> (Double, Double, Double, Double) {
            (
                Double((hex >> 16) & 0xFF) / 255.0,
                Double((hex >> 8) & 0xFF) / 255.0,
                Double(hex & 0xFF) / 255.0,
                alpha
            )
        }
    }

    public enum Typography {
        public static let hero = Font.system(size: 34, weight: .black, design: .default)
        public static let h1 = Font.system(size: 28, weight: .bold, design: .default)
        public static let h2 = Font.system(size: 20, weight: .semibold, design: .default)
        public static let h3 = Font.system(size: 17, weight: .semibold, design: .default)

        public static let largeTitle = h1
        public static let title = h2
        public static let title2 = h3
        public static let title3 = Font.system(size: 15, weight: .medium, design: .default)

        public static let bodyDefault = Font.system(size: 16, weight: .regular, design: .default)
        public static let body = bodyDefault
        public static let bodyMedium = Font.system(size: 16, weight: .medium, design: .default)
        public static let callout = Font.system(size: 14, weight: .regular, design: .default)
        public static let bodySmall = callout
        public static let caption = Font.system(size: 12, weight: .medium, design: .default)
        public static let mono = Font.system(size: 14, weight: .medium, design: .monospaced)
        public static let monoDefault = Font.system(size: 14, weight: .medium, design: .monospaced)
        public static let monoSmall = Font.system(size: 12, weight: .regular, design: .monospaced)
    }

    public enum Spacing {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 24
        public static let xxl: CGFloat = 32
        public static let xxxl: CGFloat = 48
    }

    public enum Radius {
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 24
        public static let pill: CGFloat = 999
    }
}

public struct OCCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    public func body(content: Content) -> some View {
        content
            .padding(OC.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: OC.Radius.md, style: .continuous)
                    .fill(OC.Colors.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: OC.Radius.md, style: .continuous)
                    .stroke(OC.Colors.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(colorScheme == .light ? 0.08 : 0.0), radius: 10, x: 0, y: 4)
    }
}

public extension View {
    func ocCard() -> some View {
        modifier(OCCardModifier())
    }
}

public extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha)
    }
}
