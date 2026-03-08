import Foundation
import AVFoundation

@MainActor
final class SoundPlayer {
    static let shared = SoundPlayer()

    private var selectPlayer: AVAudioPlayer?

    private init() {
        prepareSelect()
    }

    private func prepareSelect() {
        guard let url = Bundle.main.url(forResource: "select", withExtension: "mp3", subdirectory: "Sound") else {
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            selectPlayer = player
        } catch {
            selectPlayer = nil
        }
    }

    func playSelect() {
        if selectPlayer == nil {
            prepareSelect()
        }
        guard let player = selectPlayer else { return }
        player.currentTime = 0
        player.play()
    }
}
