//
//  ChampionCard.swift
//  LeagueDex
//
//  Created by Etudiant on 17/09/2026.
//


import SwiftUI

struct ChampionCard: View {
    let champion: DBChampion
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.clear
                .frame(height: 170)
                .overlay(
                    CachedAsyncImage(url: champion.splashArtURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.gray.opacity(0.2)
                    }
                )
                .clipped()
            
            LinearGradient(colors: [.clear, .black.opacity(0.9)], startPoint: .center, endPoint: .bottom)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(champion.name).font(.title3).bold().foregroundColor(.white).lineLimit(1)
                Text(champion.title.capitalized).font(.caption).foregroundColor(.white.opacity(0.8)).lineLimit(1)
            }
            .padding(12)
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
        .overlay(alignment: .topTrailing) {
            if champion.isFavorite {
                Image(systemName: "heart.fill")
                    .font(.caption).foregroundColor(.red).padding(8)
                    .background(.ultraThinMaterial, in: Circle()).padding(8)
            }
        }
    }
}