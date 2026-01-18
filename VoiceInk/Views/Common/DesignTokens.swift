import SwiftUI

/// Centralized design tokens matching the EmberType website styling
/// Website: embertype.com - Sharp, angular, futuristic aesthetic
enum DesignTokens {
    // MARK: - Corner Radii
    /// Cards, containers (barely softened - matches website's 2px)
    static let cornerRadiusCard: CGFloat = 2
    /// Small interactive elements (text fields, small buttons)
    static let cornerRadiusTiny: CGFloat = 2
    /// Code blocks, inline elements
    static let cornerRadiusSmall: CGFloat = 4

    // MARK: - Colors (matching website CSS variables)
    /// Primary background (#0a0a0a)
    static let bgPrimary = Color(red: 0.039, green: 0.039, blue: 0.039)
    /// Secondary background (#111111)
    static let bgSecondary = Color(red: 0.067, green: 0.067, blue: 0.067)
    /// Card background (#161616)
    static let bgCard = Color(red: 0.086, green: 0.086, blue: 0.086)
    /// Border color (#222222)
    static let border = Color(red: 0.133, green: 0.133, blue: 0.133)
    /// Hover border color (#333333)
    static let borderHover = Color(red: 0.2, green: 0.2, blue: 0.2)
    /// Accent color - ember gold (#efa12b) - matches website exactly
    static let accent = Color(red: 0.937, green: 0.631, blue: 0.169)

    // MARK: - Border Width
    /// Standard border width (1px)
    static let borderWidth: CGFloat = 1

    // MARK: - Typography (matching website)
    /// Font names - Inter (variable font) for body, JetBrains Mono for code
    enum FontName {
        static let inter = "Inter Variable"
        static let jetBrainsMono = "JetBrainsMono"
    }

    /// Inter font - body text (matches website)
    /// Uses Inter variable font with weight applied via SwiftUI
    static func inter(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        // Variable font: use base name and apply weight via SwiftUI
        return Font.custom(FontName.inter, size: size).weight(weight)
    }

    /// JetBrains Mono font - code/labels (matches website)
    static func jetBrainsMono(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let weightSuffix: String
        switch weight {
        case .bold, .heavy, .black: weightSuffix = "-Bold"
        case .semibold: weightSuffix = "-SemiBold"
        case .medium: weightSuffix = "-Medium"
        default: weightSuffix = "-Regular"
        }
        return .custom("\(FontName.jetBrainsMono)\(weightSuffix)", size: size)
    }

    // MARK: - Semantic Font Styles (convenience)

    /// Large hero titles (44pt Inter Bold)
    static let fontHeroTitle = inter(size: 44, weight: .bold)
    /// Section titles (28pt Inter Bold)
    static let fontSectionTitle = inter(size: 28, weight: .bold)
    /// Card titles (20pt Inter SemiBold)
    static let fontCardTitle = inter(size: 20, weight: .semibold)
    /// Headlines (18pt Inter SemiBold)
    static let fontHeadline = inter(size: 18, weight: .semibold)
    /// Body text (14pt Inter Regular)
    static let fontBody = inter(size: 14, weight: .regular)
    /// Small text (12pt Inter Regular)
    static let fontSmall = inter(size: 12, weight: .regular)
    /// Caption text (11pt Inter Regular)
    static let fontCaption = inter(size: 11, weight: .regular)
    /// Large numbers/metrics (36pt Inter Bold)
    static let fontMetricLarge = inter(size: 36, weight: .bold)
    /// Medium numbers/metrics (24pt Inter Bold)
    static let fontMetricMedium = inter(size: 24, weight: .bold)
    /// Code/monospace text (13pt JetBrains Mono)
    static let fontCode = jetBrainsMono(size: 13, weight: .regular)
    /// Code labels (12pt JetBrains Mono Medium)
    static let fontCodeLabel = jetBrainsMono(size: 12, weight: .medium)
}

// MARK: - Grid Background View

/// A subtle grid background pattern matching the EmberType website
/// Use as an overlay or background on main content views
struct GridBackgroundView: View {
    var opacity: Double = 0.08
    var tileSize: CGFloat = 300

    var body: some View {
        GeometryReader { geometry in
            Image("GridBackground")
                .resizable(resizingMode: .tile)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .opacity(opacity)
        }
        .ignoresSafeArea()
    }
}

/// View modifier to apply grid background to any view
struct GridBackgroundModifier: ViewModifier {
    var opacity: Double = 0.08

    func body(content: Content) -> some View {
        ZStack {
            DesignTokens.bgPrimary.ignoresSafeArea()
            GridBackgroundView(opacity: opacity)
            content
        }
    }
}

extension View {
    /// Applies the EmberType grid background pattern
    /// - Parameter opacity: Grid opacity (default 0.08 for subtle effect)
    func gridBackground(opacity: Double = 0.08) -> some View {
        modifier(GridBackgroundModifier(opacity: opacity))
    }
}
