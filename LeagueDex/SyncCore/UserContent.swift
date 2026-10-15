import Foundation

struct CustomBuild: Codable, Identifiable, Equatable, Sendable {
    var id = UUID().uuidString
    var name: String
    var championID: String
    var itemIDs: [String]
    var revision = 0
    var deleted = false
    var createdAt = Date()
    var updatedAt = Date()
    var mutationID = UUID().uuidString
    // Local-only ancestor of an edit made while a previous transaction was in flight.
    var predecessorMutationID: String? = nil
}

extension CustomBuild {
    enum CodingKeys: String, CodingKey {
        case id, name, championID, itemIDs, revision, deleted, createdAt, updatedAt, mutationID, predecessorMutationID
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try values.decode(String.self, forKey: .id),
                  name: try values.decode(String.self, forKey: .name),
                  championID: try values.decode(String.self, forKey: .championID),
                  itemIDs: try values.decode([String].self, forKey: .itemIDs),
                  revision: try values.decodeIfPresent(Int.self, forKey: .revision) ?? 0,
                  deleted: try values.decodeIfPresent(Bool.self, forKey: .deleted) ?? false,
                  createdAt: try values.decode(Date.self, forKey: .createdAt),
                  updatedAt: try values.decode(Date.self, forKey: .updatedAt),
                  mutationID: try values.decodeIfPresent(String.self, forKey: .mutationID) ?? UUID().uuidString,
                  predecessorMutationID: try values.decodeIfPresent(String.self, forKey: .predecessorMutationID))
    }
}

struct SavedComparison: Identifiable, Equatable, Sendable {
    let id: String
    let leftID: String
    let rightID: String
    let level: Int
}

struct QuizRun: Identifiable, Equatable, Sendable {
    let id: String
    let category: String
    let difficulty: String
    let score: Int
    let correct: Int
    let total: Int
    let completedAt: Date
    let dayKey: String
}
