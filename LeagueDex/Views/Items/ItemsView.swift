//
//  ItemsView.swift
//  LeagueDex
//
//  Created by Etudiant on 17/09/2026.
//


import SwiftUI

struct ItemsView: View {
    @StateObject private var viewModel = ItemViewModel()
    @State private var searchText = ""
    
    var filteredItems: [DBItem] {
        if searchText.isEmpty { return viewModel.items }
        return viewModel.items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if let message = viewModel.errorMessage, viewModel.items.isEmpty {
                    ContentUnavailableView(message, systemImage: "wifi.exclamationmark", description: Text("Vérifiez votre connexion puis réessayez."))
                } else if viewModel.isLoading && viewModel.items.isEmpty {
                    VStack(spacing: 20) {
                        ProgressView().scaleEffect(1.5)
                        Text("Chargement de l'armurerie...").foregroundColor(.secondary)
                    }
                } else {
                    List(filteredItems) { item in
                        NavigationLink(destination: ItemDetailView(item: item)) {
                            HStack(spacing: 15) {
                                CachedAsyncImage(url: item.iconURL) { image in
                                    image.resizable()
                                } placeholder: { ProgressView() }
                                .frame(width: 40, height: 40).clipShape(RoundedRectangle(cornerRadius: 8))
                                
                                VStack(alignment: .leading) {
                                    Text(item.name).font(.headline)
                                    Text(item.plaintext).font(.caption).foregroundColor(.secondary).lineLimit(1)
                                }
                                Spacer()
                                
                                HStack(spacing: 4) {
                                    Text("\(item.totalCost)").font(.subheadline).bold().foregroundColor(.yellow)
                                    Image(systemName: "circle.hexagongrid.fill").foregroundColor(.yellow).font(.caption)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Armurerie")
            .searchable(text: $searchText, prompt: "Rechercher un objet...")
        }
    }
}

struct ItemDetailView: View {
    let item: DBItem
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                CachedAsyncImage(url: item.iconURL) { image in
                    image.resizable().scaledToFit()
                } placeholder: { ProgressView() }
                .frame(width: 120, height: 120).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(radius: 5)
                
                Text(item.name).font(.largeTitle).bold()
                Text(item.plaintext).font(.title3).foregroundColor(.secondary)
                
                HStack(spacing: 20) {
                    PriceBox(title: "Coût de base", price: item.baseCost)
                    PriceBox(title: "Coût Total", price: item.totalCost)
                    PriceBox(title: "Revente", price: item.sellPrice)
                }
                .padding(.vertical)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Statistiques & Passifs").font(.headline)
                    Text(item.itemDescription.removingHTML())
                        .font(.body).padding().frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6)).cornerRadius(12)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}