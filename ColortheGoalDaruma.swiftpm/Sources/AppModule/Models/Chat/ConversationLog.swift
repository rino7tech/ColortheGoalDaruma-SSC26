import Foundation

struct AnswerRecord: Codable {
    let key: QuestionKey
    let response: String
}

struct ConversationLog: Codable {
    let id: UUID
    let date: Date
    let answers: [AnswerRecord]
    let color: DarumaColor
    let wishSummary: String

    init(
        answers: [AnswerRecord],
        color: DarumaColor,
        wishSummary: String
    ) {
        self.id = UUID()
        self.date = Date()
        self.answers = answers
        self.color = color
        self.wishSummary = wishSummary
    }
}

final class LocalLogStore {
    private let fileURL: URL
    private let queue = DispatchQueue(label: "LocalLogStore")

    init(filename: String = "daruma_logs.json") {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        fileURL = documents?.appendingPathComponent(filename) ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(filename)
    }

    func append(log: ConversationLog) {
        let fileURL = self.fileURL
        queue.async {
            var existing: [ConversationLog] = (try? Self.readLogs(from: fileURL)) ?? []
            existing.append(log)
            if let data = try? JSONEncoder().encode(existing) {
                try? data.write(to: fileURL, options: .atomic)
            }
        }
    }

    private static func readLogs(from fileURL: URL) throws -> [ConversationLog] {
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([ConversationLog].self, from: data)
    }
}
