import Foundation

struct HighScoreEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let score: Int
    let date: Date
    let timeoutLabel: String
    let levelLabel: String

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case score
        case date
        case timeoutLabel
        case levelLabel
    }

    init(
        id: UUID = UUID(),
        name: String,
        score: Int,
        date: Date = .now,
        timeoutLabel: String = "Unlimited",
        levelLabel: String = "Level 1"
    ) {
        self.id = id
        self.name = name
        self.score = score
        self.date = date
        self.timeoutLabel = timeoutLabel
        self.levelLabel = levelLabel
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        score = try container.decode(Int.self, forKey: .score)
        date = try container.decode(Date.self, forKey: .date)
        timeoutLabel = try container.decodeIfPresent(String.self, forKey: .timeoutLabel) ?? "Unlimited"
        levelLabel = try container.decodeIfPresent(String.self, forKey: .levelLabel) ?? "Level 1"
    }
}

final class HighScoreStore {
    static let shared = HighScoreStore()

    private let key = "high_scores"
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() -> [HighScoreEntry] {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let entries = try? decoder.decode([HighScoreEntry].self, from: data)
        else {
            return []
        }

        return entries.sorted {
            if $0.score == $1.score {
                return $0.date > $1.date
            }
            return $0.score > $1.score
        }
    }

    func highestScore() -> Int {
        load().first?.score ?? 0
    }

    func save(name: String, score: Int, timeoutLabel: String, levelLabel: String, date: Date = .now) {
        let sanitizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitizedName.isEmpty else { return }

        var entries = load()
        entries.append(
            HighScoreEntry(
                name: sanitizedName,
                score: score,
                date: date,
                timeoutLabel: timeoutLabel,
                levelLabel: levelLabel
            )
        )
        entries = Array(
            entries.sorted {
                if $0.score == $1.score {
                    return $0.date > $1.date
                }
                return $0.score > $1.score
            }
            .prefix(10)
        )

        guard let data = try? encoder.encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    func reset() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
