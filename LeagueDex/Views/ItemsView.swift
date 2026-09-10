//
//  ItemsView.swift
//  LeagueDex
//
//  Created by Etudiant on 10/09/2026.
//


import SwiftUI
import SwiftData

struct ItemsView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var viewModel = ItemViewModel()
    
    // Trie les objets du plus cher au moins cher
    @Query(sort: \DBItem.totalCost, order: .reverse) private var allItems: [DBItem]
    @State private var searchText = ""
    
    var filteredItems: [DBItem] {
        if searchText.isEmpty { return allItems }
        return allItems.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            List(filteredItems) { item in
                NavigationLink(destination: ItemDetailView(item: item)) {
                    HStack(spacing: 15) {
                        CachedAsyncImage(url: item.iconURL) { image in
                            image.resizable()
                        } placeholder: { ProgressView() }
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        VStack(alignment: .leading) {
                            Text(item.name).font(.headline)
                            Text(item.plaintext).font(.caption).foregroundColor(.secondary).lineLimit(1)
                        }
                        Spacer()
                        
                        // Prix en or
                        HStack(spacing: 4) {
                            Text("\(item.totalCost)").font(.subheadline).bold().foregroundColor(.yellow)
                            Image(systemName: "circle.hexagongrid.fill").foregroundColor(.yellow).font(.caption)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Armurerie")
            .searchable(text: $searchText, prompt: "Rechercher un objet...")
            .task {
                if allItems.isEmpty { await viewModel.syncItems(context: context) }
            }
        }
    }
}

// Sous-vue pour le détail de l'objet
struct ItemDetailView: View {
    let item: DBItem
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                CachedAsyncImage(url: item.iconURL) { image in
                    image.resizable().scaledToFit()
                } placeholder: { ProgressView() }
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(radius: 5)
                
                Text(item.name).font(.largeTitle).bold()
                Text(item.plaintext).font(.title3).foregroundColor(.secondary)
                
                // Zone de prix
                HStack(spacing: 20) {
                    PriceBox(title: "Coût de base", price: item.baseCost)
                    PriceBox(title: "Coût Total", price: item.totalCost)
                    PriceBox(title: "Revente", price: item.sellPrice)
                }
                .padding(.vertical)
                
                // Description et Stats
                VStack(alignment: .leading, spacing: 10) {
                    Text("Statistiques & Passifs").font(.headline)
                    Text(item.itemDescription.removingHTML()) // Utilise l'extension String créée précédemment
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationBarTitleDisplayMode(.inline)
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
