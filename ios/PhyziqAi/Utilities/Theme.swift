import SwiftUI

/// Central design tokens for PhyziqAi: clean, modern light UI with a single electric cyan accent.
enum Theme {
    static let bg = Color(red: 245 / 255, green: 248 / 255, blue: 252 / 255)
    static let surface = Color.white
    static let surfaceHi = Color(red: 235 / 255, green: 242 / 255, blue: 250 / 255)
    static let accent = Color(red: 0 / 255, green: 178 / 255, blue: 224 / 255)
    static let accentDeep = Color(red: 0 / 255, green: 124 / 255, blue: 161 / 255)
    static let textPrimary = Color(red: 15 / 255, green: 22 / 255, blue: 31 / 255)
    static let textSecondary = Color(red: 85 / 255, green: 100 / 255, blue: 118 / 255)
    static let textTertiary = Color(red: 140 / 255, green: 155 / 255, blue: 172 / 255)
    static let hairline = Color.black.opacity(0.08)
    static let success = Color(red: 34 / 255, green: 174 / 255, blue: 117 / 255)
    static let warning = Color(red: 217 / 255, green: 142 / 255, blue: 26 / 255)
    static let danger = Color(red: 224 / 255, green: 62 / 255, blue: 62 / 255)

    static let cardRadius: CGFloat = 20
    static let padding: CGFloat = 16
}

extension Font {
    static func displayFont(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .default)
    }

    static func titleFont(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }
}

/// Subtle blueprint grid backdrop used behind hero sections.
struct PhyziqAiGridBackground: View {
    var lineColor: Color = Theme.accent.opacity(0.10)
    var spacing: CGFloat = 28

    var body: some View {
        Canvas { context, size in
            var path = Path()
            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }
            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }
            context.stroke(path, with: .color(lineColor), lineWidth: 0.7)
        }
        .allowsHitTesting(false)
    }
}

/// Primary CTA button — full-width, accent fill, springy press feedback.
struct PrimaryButtonStyle: ButtonStyle {
    var isDestructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isDestructive ? Theme.danger : Theme.accent)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Secondary button — outlined on a light surface.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Theme.hairline, lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: Theme.cardRadius)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cardRadius)
                            .strokeBorder(Theme.hairline, lineWidth: 1)
                    )
                    .shadow(color: Theme.accent.opacity(0.04), radius: 16, x: 0, y: 6)
            )
    }
}

extension View {
    func blueprintCard() -> some View {
        modifier(CardBackground())
    }
}

/// Persistent fitness disclaimer shown on analysis and plan surfaces.
struct DisclaimerFooter: View {
    var body: some View {
        VStack(spacing: 4) {
            Text("Always consult a physician before beginning any exercise program. Physique scores are AI-generated estimates for motivation and tracking — not clinical or medical assessments.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary.opacity(0.8))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }
}

/// Small pill-shaped tag chip.
struct TagChip: View {
    let text: String
    var isSelected: Bool = false

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(isSelected ? Color.white : Theme.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Theme.accent : Theme.surfaceHi)
                    .overlay(
                        Capsule().strokeBorder(isSelected ? Color.clear : Theme.hairline, lineWidth: 1)
                    )
            )
    }
}

enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
