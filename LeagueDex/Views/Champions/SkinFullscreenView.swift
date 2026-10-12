import SwiftUI

/// Fullscreen view of a Data Dragon splash image, opened from a skin thumbnail.
/// The large image keeps using LeagueDex's existing disk and memory image cache.
struct SkinFullscreenView: View {
    let skin: DBSkin
    let championName: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scale: CGFloat = 1
    @State private var settledScale: CGFloat = 1

    private var imageTitle: String {
        skin.name == "default" ? championName : skin.name
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { geometry in
                CachedAsyncImage(url: skin.url) { image in
                    image
                        .resizable()
                        .scaledToFit()
                } placeholder: {
                    VStack(spacing: LeagueTheme.Space.md) {
                        ProgressView()
                            .tint(LeagueTheme.gold)
                        Text("Chargement de l'image…")
                            .font(.subheadline)
                            .foregroundStyle(LeagueTheme.muted)
                    }
                }
                .imageDimension(1600)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .scaleEffect(scale)
                .gesture(
                    MagnificationGesture()
                        .onChanged { amount in
                            scale = min(4, max(1, settledScale * amount))
                        }
                        .onEnded { _ in
                            settledScale = scale
                        }
                )
                .simultaneousGesture(
                    TapGesture(count: 2).onEnded {
                        withAnimation(reduceMotion ? nil : LeagueMotion.quick) {
                            scale = scale > 1 ? 1 : 2
                            settledScale = scale
                        }
                    }
                )
                .accessibilityLabel("Image en grand : \(imageTitle)")
                .accessibilityHint("Pincez pour zoomer ou touchez deux fois pour changer de zoom")
            }

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Label("Fermer", systemImage: "xmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(LeagueTheme.text)
                            .padding(.horizontal, LeagueTheme.Space.md)
                            .frame(minHeight: 44)
                            .background(LeagueTheme.surface.opacity(0.95), in: Capsule())
                    }
                    .accessibilityLabel("Fermer l'image en plein écran")
                }
                .padding(LeagueTheme.Space.md)

                Spacer(minLength: 0)

                VStack(spacing: LeagueTheme.Space.xs) {
                    Text(imageTitle)
                        .font(.headline)
                        .foregroundStyle(LeagueTheme.text)
                        .multilineTextAlignment(.center)
                    Text("Pincez pour zoomer · Double-touchez pour agrandir")
                        .font(.caption)
                        .foregroundStyle(LeagueTheme.muted)
                }
                .padding(LeagueTheme.Space.md)
                .frame(maxWidth: .infinity)
                .background(.black.opacity(0.78))
            }
        }
        .preferredColorScheme(.dark)
    }
}
