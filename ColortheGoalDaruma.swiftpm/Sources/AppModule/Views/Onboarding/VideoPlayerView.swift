import SwiftUI
import AVFoundation

/// 動画をループ再生するビュー
struct VideoPlayerView: UIViewRepresentable {
    let resourceName: String
    let fileExtension: String

    func makeUIView(context: Context) -> UIView {
        let view = VideoPlayerUIView(resourceName: resourceName, fileExtension: fileExtension)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    static func dismantleUIView(_ uiView: UIView, coordinator: ()) {
        guard let playerView = uiView as? VideoPlayerUIView else { return }
        playerView.cleanup()
    }
}

/// AVPlayerLayerを使って動画を表示するUIView
private class VideoPlayerUIView: UIView {
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var loopObserver: NSObjectProtocol?

    init(resourceName: String, fileExtension: String) {
        super.init(frame: .zero)
        setupPlayer(resourceName: resourceName, fileExtension: fileExtension)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }

    private func setupPlayer(resourceName: String, fileExtension: String) {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: fileExtension, subdirectory: "Movie") ??
              Bundle.main.url(forResource: resourceName, withExtension: fileExtension) else {
            return
        }

        let player = AVPlayer(url: url)
        player.isMuted = true

        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(playerLayer)

        self.player = player
        self.playerLayer = playerLayer

        // ループ再生: 再生終了時に先頭に戻す
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
            player?.play()
        }

        player.play()
    }

    func cleanup() {
        player?.pause()
        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        loopObserver = nil
        player = nil
    }

}
