import Foundation

struct HighScoreEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let score: Int
    let date: Date
    let timeoutLabel: String

    init(id: UUID = UUID(), name: String, score: Int, date: Date = .now, timeoutLabel: String = "Unlimited") {
        self.id = id
        self.name = name
        self.score = score
        self.date = date
        self.timeoutLabel = timeoutLabel
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

    func save(name: String, score: Int, timeoutLabel: String, date: Date = .now) {
        let sanitizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitizedName.isEmpty else { return }

        var entries = load()
        entries.append(HighScoreEntry(name: sanitizedName, score: score, date: date, timeoutLabel: timeoutLabel))
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
}
