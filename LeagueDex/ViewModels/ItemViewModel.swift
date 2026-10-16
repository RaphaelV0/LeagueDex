//
//  ItemViewModel.swift
//  LeagueDex
//
//  Created by Etudiant on 17/09/2026.
//


import SwiftUI
import FirebaseFirestore
import Combine

@MainActor
class ItemViewModel: ObservableObject {
    @Published var items: [DBItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var isFromCache = true
    private var fallbackTask: Task<Void, Never>?
    private var fallbackAllowsNetwork = false
    private var hasLoadedFallback = false
    private var fallbackGeneration = UUID()
    private var listenerGeneration = UUID()
    
    private let db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?
    private var connectivitySubscription: AnyCancellable?
    
    init() {
        connectivitySubscription = ConnectivityStore.shared.$isOnline.removeDuplicates().sink { [weak self] online in
            guard let self else { return }
            if !online && self.items.isEmpty {
                self.loadRiotFallback(cachedOnly: true)
            }
        }
        fetchItemsFromFirebase()
    }
    
    deinit {
        listenerRegistration?.remove()
        fallbackTask?.cancel()
    }
    
    func fetchItemsFromFirebase() {
        listenerRegistration?.remove()
        fallbackTask?.cancel()
        fallbackTask = nil
        hasLoadedFallback = false
        fallbackGeneration = UUID()
        listenerGeneration = UUID()
        let generation = listenerGeneration
        errorMessage = nil
        isLoading = true
        listenerRegistration = db.collection("items").addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
            Task { @MainActor [weak self] in
                guard let self, self.listenerGeneration == generation else { return }
                self.receiveSnapshot(snapshot, error: error)
            }
        }
    }

    private func receiveSnapshot(_ snapshot: QuerySnapshot?, error: Error?) {
        guard error == nil, let snapshot else {
            errorMessage = "Impossible de charger les objets. Vérifiez votre connexion."
            if items.isEmpty && !ConnectivityStore.shared.isOnline {
                loadRiotFallback(cachedOnly: true)
            } else {
                isLoading = false
            }
            return
        }
        if snapshot.documents.isEmpty {
            // Firestore is the source of truth while online. An initial empty
            // cache snapshot is not proof that the server catalog is empty.
            if snapshot.metadata.isFromCache {
                if items.isEmpty && !ConnectivityStore.shared.isOnline {
                    loadRiotFallback(cachedOnly: true)
                } else {
                    isLoading = items.isEmpty && ConnectivityStore.shared.isOnline
                }
            } else {
                fallbackTask?.cancel()
                fallbackTask = nil
                fallbackGeneration = UUID()
                hasLoadedFallback = false
                items = []
                isFromCache = false
                isLoading = false
                errorMessage = "Aucun objet disponible dans Firebase. Vérifiez la collection items."
            }
            return
        }

        fallbackTask?.cancel()
        fallbackTask = nil
        fallbackGeneration = UUID()
        hasLoadedFallback = false
        let fetched = snapshot.documents.compactMap { try? $0.data(as: DBItem.self) }
        if !fetched.isEmpty {
            items = fetched.sorted { $0.totalCost > $1.totalCost }
            isFromCache = snapshot.metadata.isFromCache
        }
        errorMessage = fetched.count == snapshot.documents.count ? nil : "Certains objets sont illisibles dans la base de données."
        isLoading = false
    }

    /// An in-memory fallback never writes to the administrator-owned catalog.
    private func loadRiotFallback(cachedOnly: Bool) {
        // Disk-only fallback is available exclusively without a network path.
        guard !ConnectivityStore.shared.isOnline, cachedOnly else {
            isLoading = false
            return
        }
        if hasLoadedFallback && (cachedOnly || fallbackAllowsNetwork) { isLoading = false; return }
        if fallbackTask != nil {
            guard !cachedOnly, !fallbackAllowsNetwork else { return }
            fallbackTask?.cancel()
        }
        fallbackAllowsNetwork = !cachedOnly
        fallbackGeneration = UUID()
        let generation = fallbackGeneration
        isLoading = items.isEmpty
        fallbackTask = Task { [weak self] in
            do {
                let result = try await DataDragon.fetch(APIItemResponse.self, file: "item.json", cachedOnly: cachedOnly) { response in
                    guard !response.data.isEmpty, response.data.count <= 5_000,
                          response.data.contains(where: { !$0.value.name.isEmpty && $0.value.gold.total > 0 }) else {
                        throw URLError(.cannotParseResponse)
                    }
                }
                try Task.checkCancellation()
                guard let self, self.fallbackGeneration == generation else { return }
                // Zero-cost entries are internal/hidden game objects, as in the legacy import.
                self.items = result.value.data.compactMap { key, item -> DBItem? in
                    guard item.gold.total > 0 else { return nil }
                    return DBItem(
                        id: key, name: item.name, plaintext: item.plaintext, itemDescription: item.description,
                        baseCost: item.gold.base, totalCost: item.gold.total, sellPrice: item.gold.sell
                    )
                }.sorted { $0.totalCost > $1.totalCost }
                self.hasLoadedFallback = true
                self.isFromCache = result.isFromCache
                self.isLoading = false
                self.errorMessage = nil
                self.fallbackTask = nil
            } catch {
                guard !Task.isCancelled, let self, self.fallbackGeneration == generation else { return }
                self.fallbackTask = nil
                self.isLoading = false
                self.errorMessage = "Les objets sont indisponibles. Connectez-vous à Internet puis réessayez."
            }
        }
    }
}
