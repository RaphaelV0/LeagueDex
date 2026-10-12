import SwiftUI

/// Shared, short interactions. Animations disappear when the system requests
/// reduced motion; no per-row transitions are applied to large scrolling lists.
enum LeagueMotion {
    static let quick = Animation.easeOut(duration: 0.18)
    static let standard = Animation.easeOut(duration: 0.24)
    static let reveal = Animation.easeOut(duration: 0.28)
}

/// Subtle one-time entrance reserved for a handful of screen-level sections.
private struct LeagueRevealModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(reduceMotion || appeared ? 1 : 0)
            .offset(y: reduceMotion || appeared ? 0 : 8)
            .onAppear {
                guard !appeared else { return }
                if reduceMotion {
                    appeared = true
                } else {
                    withAnimation(LeagueMotion.reveal) { appeared = true }
                }
            }
    }
}

extension View {
    func leagueReveal() -> some View { modifier(LeagueRevealModifier()) }
}

/// Press feedback for compact actions without replacing native navigation.
struct LeagueCompactButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : LeagueMotion.quick, value: configuration.isPressed)
    }
}

/// Lightweight opacity pulse rather than GPU-heavy gradient shimmer.
struct LeagueSkeletonBlock: View {
    var radius: CGFloat = LeagueTheme.Corner.medium
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glowing = false

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(LeagueTheme.elevated)
            .opacity(reduceMotion ? 0.8 : (glowing ? 0.50 : 0.85))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    glowing = true
                }
            }
            .onChange(of: reduceMotion) { isReduced in
                if isReduced {
                    glowing = false
                } else {
                    withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                        glowing = true
                    }
                }
            }
            .onDisappear { glowing = false }
            .accessibilityHidden(true)
    }
}

struct LeagueChampionGridSkeleton: View {
    private let columns = [GridItem(.adaptive(minimum: 148, maximum: 240), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: LeagueTheme.Space.md) {
            Text("Chargement des champions…")
                .font(.subheadline)
                .foregroundStyle(LeagueTheme.muted)
            LazyVGrid(columns: columns, spacing: LeagueTheme.Space.md) {
                ForEach(0..<6, id: \.self) { _ in
                    LeagueSkeletonBlock(radius: LeagueTheme.Corner.large)
                        .frame(height: 184)
                }
            }
        }
        .padding(LeagueTheme.Space.md)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Chargement des champions")
    }
}

struct LeagueItemListSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: LeagueTheme.Space.md) {
            Text("Chargement de l'armurerie…")
                .font(.subheadline)
                .foregroundStyle(LeagueTheme.muted)
            ForEach(0..<6, id: \.self) { _ in
                HStack(spacing: LeagueTheme.Space.md) {
                    LeagueSkeletonBlock().frame(width: 48, height: 48)
                    VStack(alignment: .leading, spacing: LeagueTheme.Space.sm) {
                        LeagueSkeletonBlock().frame(height: 15)
                        LeagueSkeletonBlock().frame(width: 148, height: 10)
                    }
                    Spacer(minLength: 12)
                    LeagueSkeletonBlock().frame(width: 48, height: 16)
                }
                .padding(LeagueTheme.Space.sm)
                .leagueSurface(radius: LeagueTheme.Corner.medium)
            }
        }
        .padding(LeagueTheme.Space.md)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Chargement de l'armurerie")
    }
}
