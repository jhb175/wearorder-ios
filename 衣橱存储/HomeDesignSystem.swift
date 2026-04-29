import SwiftUI

enum HomeMetrics {
    static let pagePadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 24
    static let primaryRadius: CGFloat = 30
    static let secondaryRadius: CGFloat = 26
    static let innerRadius: CGFloat = 22
    static let pillRadius: CGFloat = 18
    static let primaryCardPadding: CGFloat = 22
    static let secondaryCardPadding: CGFloat = 20
}

enum HomeCardWeight {
    case secondary
    case tertiary
}

struct AppAdaptiveBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(topGlowColor)
                .frame(width: 340, height: 340)
                .blur(radius: colorScheme == .dark ? 42 : 0)
                .offset(x: -110, y: -250)

            Circle()
                .fill(blueGlowColor)
                .frame(width: 280, height: 280)
                .blur(radius: colorScheme == .dark ? 58 : 0)
                .offset(x: 150, y: 110)

            Ellipse()
                .fill(warmGlowColor)
                .frame(width: 320, height: 220)
                .blur(radius: colorScheme == .dark ? 50 : 0)
                .offset(x: 0, y: 260)
        }
    }

    private var backgroundColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.055, green: 0.065, blue: 0.082),
                Color(red: 0.085, green: 0.100, blue: 0.128),
                Color(red: 0.105, green: 0.098, blue: 0.082)
            ]
        }

        return [
            Color(red: 0.97, green: 0.98, blue: 0.99),
            Color(red: 0.93, green: 0.95, blue: 0.98),
            Color(red: 0.96, green: 0.95, blue: 0.93)
        ]
    }

    private var topGlowColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.060) : Color.white.opacity(0.28)
    }

    private var blueGlowColor: Color {
        colorScheme == .dark
            ? Color(red: 0.30, green: 0.48, blue: 0.76).opacity(0.18)
            : Color(red: 0.72, green: 0.82, blue: 0.94).opacity(0.18)
    }

    private var warmGlowColor: Color {
        colorScheme == .dark
            ? Color(red: 0.74, green: 0.57, blue: 0.32).opacity(0.10)
            : Color(red: 0.98, green: 0.95, blue: 0.88).opacity(0.14)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat, tint: Color = Color.white.opacity(0.32)) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, tint: tint))
    }

    func homeCardSurface(weight: HomeCardWeight, cornerRadius: CGFloat) -> some View {
        modifier(HomeCardSurfaceModifier(weight: weight, cornerRadius: cornerRadius))
    }

    @ViewBuilder
    func homeTabBarGlass() -> some View {
        #if os(iOS)
        self
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        #else
        self
        #endif
    }

    @ViewBuilder
    func homeInlineNavigationTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}

struct GlassCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let cornerRadius: CGFloat
    let tint: Color

    func body(content: Content) -> some View {
        let isDark = colorScheme == .dark

        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isDark ? darkFillColors : lightFillColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(alignment: .topLeading) {
                        LinearGradient(
                            colors: isDark ? darkHighlightColors : lightHighlightColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(isDark ? 0.16 : 0.40), lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(isDark ? 0.24 : 0.045), radius: isDark ? 16 : 12, y: isDark ? 10 : 7)
    }

    private var lightFillColors: [Color] {
        [
            Color.white.opacity(0.34),
            tint,
            Color.white.opacity(0.12)
        ]
    }

    private var darkFillColors: [Color] {
        [
            Color.white.opacity(0.11),
            Color.white.opacity(0.070),
            Color.black.opacity(0.20)
        ]
    }

    private var lightHighlightColors: [Color] {
        [
            Color.white.opacity(0.24),
            Color.white.opacity(0.07),
            .clear
        ]
    }

    private var darkHighlightColors: [Color] {
        [
            Color.white.opacity(0.13),
            Color.white.opacity(0.035),
            .clear
        ]
    }
}

struct HomeCardSurfaceModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let weight: HomeCardWeight
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let isDark = colorScheme == .dark

        let shadowOpacity: Double = switch weight {
        case .secondary:
            isDark ? 0.26 : 0.09
        case .tertiary:
            isDark ? 0.18 : 0.05
        }

        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isDark ? darkSurfaceColors : lightSurfaceColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(alignment: .topLeading) {
                        LinearGradient(
                            colors: isDark ? darkSurfaceHighlightColors : lightSurfaceHighlightColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(isDark ? 0.13 : 0.28), lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(shadowOpacity * 0.62), radius: 10, y: 6)
    }

    private var lightSurfaceColors: [Color] {
        let tint: Color = switch weight {
        case .secondary:
            Color.white.opacity(0.18)
        case .tertiary:
            Color.white.opacity(0.10)
        }

        return [
            Color.white.opacity(weight == .secondary ? 0.28 : 0.20),
            tint,
            Color.white.opacity(weight == .secondary ? 0.12 : 0.08)
        ]
    }

    private var darkSurfaceColors: [Color] {
        [
            Color.white.opacity(weight == .secondary ? 0.095 : 0.070),
            Color.white.opacity(weight == .secondary ? 0.060 : 0.040),
            Color.black.opacity(weight == .secondary ? 0.18 : 0.14)
        ]
    }

    private var lightSurfaceHighlightColors: [Color] {
        [
            Color.white.opacity(weight == .secondary ? 0.18 : 0.12),
            Color.white.opacity(0.04),
            .clear
        ]
    }

    private var darkSurfaceHighlightColors: [Color] {
        [
            Color.white.opacity(weight == .secondary ? 0.10 : 0.075),
            Color.white.opacity(0.025),
            .clear
        ]
    }
}

struct HomePressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.26, dampingFraction: 0.84), value: configuration.isPressed)
    }
}

struct HomeIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(12)
            .glassCard(cornerRadius: 22, tint: Color.white.opacity(0.20))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.82), value: configuration.isPressed)
    }
}
