import Foundation
import SwiftUI
import Observation

/// だるま詳細画面を管理するViewModel
@Observable
final class DarumaDetailViewModel {
    // MARK: - 表示データ

    /// だるまの結果データ
    let result: DarumaResult

    /// だるまのタイトル（例: "RedDaruma"）
    var darumaTitle: String

    /// サブタイトル（だるまの言葉）
    var subtitle: String

    /// 現在の状況の説明
    var currentStageText: String

    /// 次のステップの説明
    var nextStepText: String

    var dontdoingText: String

    /// キーワード
    var keyword: String

    // MARK: - 3Dシーン用ViewModel
    var sceneViewModel = DarumaSceneViewModel()

    // MARK: - 初期化

    /// DarumaResultから初期化
    init(result: DarumaResult) {
        self.result = result
        self.darumaTitle = result.color.title.replacingOccurrences(of: " ", with: "")
        self.subtitle = result.darumaWord
        self.currentStageText = result.currentAnalysis
        self.nextStepText = result.nextStep
        self.keyword = result.color.focusKeyword
        self.dontdoingText = result.stopDoing
    }

    /// 3Dシーンにだるまの色を反映
    func setupScene() {
        let scores: [DarumaColor: Double] = [result.color: 1.0]
        sceneViewModel.updateScores(scores)
        sceneViewModel.enableAutoRotation = true
        sceneViewModel.wishImage = nil
    }
}
