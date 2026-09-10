//
//  MainTabView.swift
//  LeagueDex
//
//  Created by Etudiant on 10/09/2026.
//


import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            ContentView() // Ton écran de champions actuel
                .tabItem {
                    Label("Champions", systemImage: "person.3.fill")
                }
            
            ItemsView() // Le nouvel écran d'armurerie
                .tabItem {
                    Label("Objets", systemImage: "shield.fill") // Icône de bouclier
                }
        }
    }
}