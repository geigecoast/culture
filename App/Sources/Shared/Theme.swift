import SwiftUI
import UIKit

/// "Dark academia" theme: near-black, warm charcoal, ivory, antique gold.
/// Light mode (when the user picks "Système") becomes ink on parchment.
enum Theme {
    static let background = dynamic(dark: 0x0E0C0A, light: 0xF4EEE3)
    static let surface = dynamic(dark: 0x1A1714, light: 0xFBF7EF)
    static let surfaceRaised = dynamic(dark: 0x24201B, light: 0xEFE7D8)
    static let ink = dynamic(dark: 0xECE4D3, light: 0x1D1914)
    static let muted = dynamic(dark: 0x9C9282, light: 0x6E6455)
    static let gold = dynamic(dark: 0xC2A26A, light: 0x8C6A2E)
    static let hairline = dynamic(dark: 0x3A3127, light: 0xD9CDB6)
    static let oxblood = dynamic(dark: 0x8E2F3A, light: 0x7A2430)

    static let cornerRadius: CGFloat = 6

    /// Didot for the logotype and large display text (scales with Dynamic Type).
    static func display(_ size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
        .custom("Didot", size: size, relativeTo: style)
    }

    /// Small gold capitals used for section labels ("À RETENIR", "SOURCES").
    static let label = Font.caption.weight(.semibold)

    private static func dynamic(dark: UInt32, light: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .light ? UIColor(hex: light) : UIColor(hex: dark) })
    }

    /// Serif navigation titles everywhere.
    static func configureUIKitAppearance() {
        func serif(_ style: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont {
            let base = UIFont.preferredFont(forTextStyle: style)
            let descriptor = base.fontDescriptor.withDesign(.serif)?
                .addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: weight]]) ?? base.fontDescriptor
            return UIFont(descriptor: descriptor, size: base.pointSize)
        }
        let nav = UINavigationBar.appearance()
        nav.largeTitleTextAttributes = [.font: serif(.largeTitle, weight: .semibold)]
        nav.titleTextAttributes = [.font: serif(.headline, weight: .semibold)]
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

/// Gold small-caps section label.
struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Theme.label)
            .textCase(.uppercase)
            .tracking(1.6)
            .foregroundStyle(Theme.gold)
    }
}

/// Thin ornamental divider: hairline · fleuron · hairline.
struct Ornament: View {
    var body: some View {
        HStack(spacing: 10) {
            Rectangle().fill(Theme.hairline).frame(height: 0.5)
            Image(systemName: "seal").font(.system(size: 9, weight: .light)).foregroundStyle(Theme.gold)
            Rectangle().fill(Theme.hairline).frame(height: 0.5)
        }
        .accessibilityHidden(true)
    }
}

/// Card surface with a gold hairline border.
struct ThemedSurface: ViewModifier {
    var radius: CGFloat = Theme.cornerRadius
    func body(content: Content) -> some View {
        content
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 0.75))
    }
}

extension View {
    func themedSurface(radius: CGFloat = Theme.cornerRadius) -> some View { modifier(ThemedSurface(radius: radius)) }
}
