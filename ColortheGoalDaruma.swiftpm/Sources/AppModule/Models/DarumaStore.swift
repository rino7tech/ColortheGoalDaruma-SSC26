import Foundation
import Observation

/// だるまコレクションをUserDefaultsで永続化するストア
@Observable final class DarumaStore {
    /// 保存済みのだるまリスト
    var savedDarumas: [SavedDaruma] = []

    private let storageKey = "savedDarumas_v1"

    init() {
        load()
    }

    /// 新しいだるまを保存する
    func save(_ daruma: SavedDaruma) {
        savedDarumas.append(daruma)
        persist()
    }

    /// 指定IDのだるまに右目データを追加し、願い達成済みにする
    func fulfillWish(id: UUID, rightEyeImageData: Data?) {
        guard let index = savedDarumas.firstIndex(where: { $0.id == id }) else { return }
        savedDarumas[index].rightEyeImageData = rightEyeImageData
        savedDarumas[index].isWishFulfilled = true
        persist()
    }

    // MARK: - 永続化

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        let decoder = JSONDecoder()
        if let decoded = try? decoder.decode([SavedDaruma].self, from: data) {
            savedDarumas = decoded
        }
    }

    private func persist() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(savedDarumas) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
