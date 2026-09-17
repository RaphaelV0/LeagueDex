//
//  SpellIcon.swift
//  LeagueDex
//
//  Created by Etudiant on 17/09/2026.
//


import SwiftUI

struct SpellIcon: View {
    let url: URL?
    var body: some View {
        CachedAsyncImage(url: url) { image in
            image.resizable().scaledToFit()
        } placeholder: {
            Color.gray.opacity(0.3)
        }
        .frame(width: 50, height: 50)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 3, y: 2)
    }
}

struct RealStatCard: View {
    let title: String; let icon: String; let color: Color; let value: Double
    var body: some View {
        HStack {
            Image(systemName: icon).foregroundColor(color).frame(width: 24)
            VStack(alignment: .leading) {
                Text(title).font(.caption).foregroundColor(.secondary)
                Text(String(format: "%.1f", value)).font(.headline)
            }
            Spacer()
        }
        .padding(12)
        .background(Color(.systemBackground).opacity(0.6))
        .cornerRadius(12)
    }
}

struct PriceBox: View {
    let title: String; let price: Int
    var body: some View {
        VStack {
            Text(title).font(.caption).foregroundColor(.secondary)
            HStack(spacing: 4) {
                Text("\(price)").font(.headline)
                Image(systemName: "circle.hexagongrid.fill").foregroundColor(.yellow)
            }
        }
        .padding(10).background(Color(.systemGray6)).cornerRadius(10)
    }
}