//
//  CachedAsyncImage.swift
//  LeagueDex
//
//  Created by Etudiant on 17/09/2026.
//


import SwiftUI

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @State private var uiImage: UIImage? = nil
    
    init(url: URL?, @ViewBuilder content: @escaping (Image) -> Content, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let uiImage = uiImage {
                content(Image(uiImage: uiImage))
            } else {
                placeholder().task { await loadImage() }
            }
        }
    }
    
    private func loadImage() async {
        guard let url = url else { return }
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let fileURL = cacheDirectory.appendingPathComponent(url.lastPathComponent)
        
        if let data = try? Data(contentsOf: fileURL), let cachedImage = UIImage(data: data) {
            self.uiImage = cachedImage
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let downloadedImage = UIImage(data: data) {
                self.uiImage = downloadedImage
                try? data.write(to: fileURL)
            }
        } catch { }
    }
}
