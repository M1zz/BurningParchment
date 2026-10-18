// BurningTips.swift
// 화면에 단추가 없어 알아채기 어려운 기능을 알맞은 때 한 번 알려 준다 (TipKit).
//
// - 기간 넘기기: 메인 화면을 좌우로 밀면 오늘 → 이번 주 → 자유시간 → 이번 달 → 올해로 넘어간다.
//   단추가 없어서 모르는 사람이 많다. 한 번이라도 넘기면 팁은 사라진다.
// - 조각 뒷면: 모은 조각을 누르면 뒤집어서 뒷면에 한 줄을 적을 수 있다.
//   뒷면이 빈 조각이 있을 때만 뜬다.

import SwiftUI
import TipKit

enum BurningTips {
    /// App.init 에서 한 번. 실패해도 팁만 안 뜰 뿐 앱은 그대로다.
    static func configure() {
        #if DEBUG
        // 스크린샷·UI 시험에서는 팁이 화면을 가리지 않게 숨긴다 (-hideTips YES)
        if UserDefaults.standard.bool(forKey: "hideTips") { Tips.hideAllTipsForTesting() }
        #endif
        do {
            try Tips.configure([.displayFrequency(.immediate)])
        } catch {
            AppLog.lifecycle.error("TipKit 설정 실패: \(error.localizedDescription, privacy: .public)")
        }
    }
}

struct SwipePeriodsTip: Tip {
    var title: Text {
        Text("옆으로 밀어 보세요", comment: "Tip title: swipe the main screen sideways")
    }
    var message: Text? {
        Text("이번 주, 이번 달, 올해 남은 시간도 같은 양피지로 볼 수 있어요.", comment: "Tip message: swiping shows week, month and year")
    }
    var image: Image? { Image(systemName: "hand.draw") }
}

struct FragmentBackTip: Tip {
    var title: Text {
        Text("조각을 뒤집어 보세요", comment: "Tip title: tap a fragment to flip it")
    }
    var message: Text? {
        Text("조각을 누르면 뒷면에 그날의 한 줄을 적을 수 있어요.", comment: "Tip message: tapping a fragment lets you write on its back")
    }
    var image: Image? { Image(systemName: "arrow.triangle.2.circlepath") }
}
