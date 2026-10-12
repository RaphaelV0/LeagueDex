import SwiftUI

/// Shared colors, spacing and animation values for LeagueDex.
/// Dark mode is the primary supported appearance.
enum LeagueTheme {
    static let background = Color(red: 8.0 / 255.0, green: 14.0 / 255.0, blue: 24.0 / 255.0)
    static let surface = Color(red: 17.0 / 255.0, green: 28.0 / 255.0, blue: 43.0 / 255.0)
    static let elevated = Color(red: 29.0 / 255.0, green: 48.0 / 255.0, blue: 66.0 / 255.0)
    static let border = Color(red: 56.0 / 255.0, green: 77.0 / 255.0, blue: 99.0 / 255.0)
    static let gold = Color(red: 198.0 / 255.0, green: 166.0 / 255.0, blue: 107.0 / 255.0)
    static let cyan = Color(red: 72.0 / 255.0, green: 199.0 / 255.0, blue: 217.0 / 255.0)
    static let text = Color(red: 244.0 / 255.0, green: 240.0 / 255.0, blue: 231.0 / 255.0)
    static let muted = Color(red: 155.0 / 255.0, green: 174.0 / 255.0, blue: 195.0 / 255.0)
    static let danger = Color(red: 214.0 / 255.0, green: 108.0 / 255.0, blue: 117.0 / 255.0)

    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Corner {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 18
        static let panel: CGFloat = 24
    }

    static let pressDuration = 0.18

    static let championGradient = LinearGradient(
        colors: [.clear, background.opacity(0.45), background.opacity(0.98)],
        startPoint: .top,
        endPoint: .bottom
    )
}

private struct LeagueSurfaceModifier: ViewModifier {
    let radius: CGFloat
    func body(content: Content) -> some View {
        content
            .background(LeagueTheme.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(LeagueTheme.border.opacity(0.7), lineWidth: 1)
            }
    }
}

extension View {
    func leagueSurface(radius: CGFloat = LeagueTheme.Corner.large) -> some View {
        modifier(LeagueSurfaceModifier(radius: radius))
    }
}

struct LeagueSectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: LeagueTheme.Space.xs) {
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(LeagueTheme.text)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(LeagueTheme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LeagueFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? LeagueTheme.background : LeagueTheme.text)
                .padding(.horizontal, LeagueTheme.Space.md)
                .frame(minHeight: 44)
                .background(
                    isSelected ? LeagueTheme.gold : LeagueTheme.elevated,
                    in: Capsule()
                )
                .overlay {
                    Capsule().strokeBorder(
                        isSelected ? LeagueTheme.gold : LeagueTheme.border,
                        lineWidth: 1
                    )
                }
        }
        .buttonStyle(LeagueCompactButtonStyle())
        .animation(reduceMotion ? nil : LeagueMotion.quick, value: isSelected)
        .accessibilityValue(isSelected ? "Sélectionné" : "Non sélectionné")
    }
}

struct LeagueActionButtonStyle: ButtonStyle {
    var prominent = true

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(prominent ? LeagueTheme.background : LeagueTheme.gold)
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, LeagueTheme.Space.md)
            .background(
                prominent ? LeagueTheme.gold : LeagueTheme.elevated,
                in: RoundedRectangle(cornerRadius: LeagueTheme.Corner.medium)
            )
            .overlay {
                RoundedRectangle(cornerRadius: LeagueTheme.Corner.medium)
                    .strokeBorder(LeagueTheme.gold.opacity(prominent ? 0.0 : 0.7), lineWidth: 1)
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.5)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(
                reduceMotion ? nil : .easeOut(duration: LeagueTheme.pressDuration),
                value: configuration.isPressed
            )
    }
}

struct LeagueLoadingState: View {
    let message: String

    var body: some View {
        VStack(spacing: LeagueTheme.Space.md) {
            ProgressView().tint(LeagueTheme.gold).scaleEffect(1.3)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(LeagueTheme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(LeagueTheme.Space.xl)
        .accessibilityElement(children: .combine)
    }
}

struct LeagueEmptyState: View {
    let title: String
    let detail: String
    var icon = "magnifyingglass"

    var body: some View {
        VStack(spacing: LeagueTheme.Space.md) {
            Image(systemName: icon)
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(LeagueTheme.gold)
                .accessibilityHidden(true)
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(LeagueTheme.text)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(LeagueTheme.muted)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(LeagueTheme.Space.lg)
        .accessibilityElement(children: .combine)
    }
}

struct LeagueErrorState: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: LeagueTheme.Space.md) {
            LeagueEmptyState(
                title: "Chargement impossible",
                detail: message,
                icon: "wifi.exclamationmark"
            )
            Button("Réessayer", action: retry)
                .buttonStyle(LeagueActionButtonStyle())
                .padding(.horizontal, LeagueTheme.Space.lg)
        }
        .frame(maxWidth: .infinity)
    }
}
