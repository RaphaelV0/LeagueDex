import Foundation

/// Version intentionally pinned until a catalog migration is explicitly validated.
/// Keeping model image URLs and fallback content on the same patch prevents
/// mixing images for a recent patch with statistics from an older patch.
enum DataDragon {
    static let version = "14.18.1"
    static let locale = "fr_FR"
    static let baseURL = "https://ddragon.leagueoflegends.com"

    struct FetchResult<Value> {
        let value: Value
        let isFromCache: Bool
    }

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        // Cache only responses that have passed HTTP, JSON and payload validation.
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }()

    static func catalogURL(_ file: String) -> URL? {
        guard validCatalogPath(file) else { return nil }
        return URL(string: "\(baseURL)/cdn/\(version)/data/\(locale)/\(file)")
    }

    static func imageURL(_ path: String) -> URL? {
        URL(string: "\(baseURL)/cdn/\(version)/img/\(path)")
    }

    /// Network first, then a previously validated disk response. Pinned version and
    /// locale are part of the cache path, including for champion detail requests.
    /// cachedOnly is used when Firestore has not confirmed an empty server catalog.
    static func fetch<Value: Decodable>(
        _ type: Value.Type,
        file: String,
        cachedOnly: Bool = false,
        validate: (Value) throws -> Void = { _ in }
    ) async throws -> FetchResult<Value> {
        guard let url = catalogURL(file) else { throw URLError(.badURL) }
        try Task.checkCancellation()
        let cacheURL = diskCacheURL(for: file)

        func decode(_ data: Data) throws -> Value {
            guard !data.isEmpty, data.count <= 8 * 1_024 * 1_024 else {
                throw URLError(.cannotParseResponse)
            }
            let value = try JSONDecoder().decode(type, from: data)
            try validate(value)
            return value
        }

        func readCache() throws -> FetchResult<Value> {
            guard let cacheURL, let data = try? Data(contentsOf: cacheURL) else {
                throw URLError(.resourceUnavailable)
            }
            return FetchResult(value: try decode(data), isFromCache: true)
        }

        if cachedOnly { return try readCache() }

        do {
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let (data, response) = try await session.data(for: request)
            try Task.checkCancellation()
            guard let response = response as? HTTPURLResponse,
                  (200...299).contains(response.statusCode) else {
                throw URLError(.badServerResponse)
            }
            if let mimeType = response.mimeType?.lowercased(),
               mimeType != "application/json", !mimeType.hasSuffix("+json") {
                throw URLError(.cannotParseResponse)
            }
            let value = try decode(data)
            if let cacheURL {
                // A full atomic response survives process restarts. The OS may evict
                // Caches data under storage pressure; failure to cache is not a fetch error.
                do {
                    try FileManager.default.createDirectory(
                        at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true
                    )
                    try data.write(to: cacheURL, options: .atomic)
                } catch {
                    print("Cache Data Dragon indisponible : \(error.localizedDescription)")
                }
            }
            return FetchResult(value: value, isFromCache: false)
        } catch {
            try Task.checkCancellation()
            if let cached = try? readCache() { return cached }
            throw error
        }
    }

    private static func diskCacheURL(for file: String) -> URL? {
        guard validCatalogPath(file),
              let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        return root.appendingPathComponent("LeagueDex.DataDragon", isDirectory: true)
            .appendingPathComponent(version, isDirectory: true)
            .appendingPathComponent(locale, isDirectory: true)
            .appendingPathComponent(file)
    }

    private static func validCatalogPath(_ file: String) -> Bool {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        guard file.hasSuffix(".json") else { return false }
        let path = String(file.dropLast(5)).split(separator: "/", omittingEmptySubsequences: false)
        return !path.isEmpty && path.allSatisfy { component in
            !component.isEmpty && component.unicodeScalars.allSatisfy(allowed.contains)
        }
    }
}
