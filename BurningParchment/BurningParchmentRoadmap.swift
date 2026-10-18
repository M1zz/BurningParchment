//
//  BurningParchmentRoadmap.swift
//  BurningParchment (불타는 내인생)
//
//  **앞으로 만들 것**의 원본. 설정 ▸ 지원 ▸ 앞으로 만들 기능(`LeeoRoadmapView`)이 이 목록을 그대로 보여 준다.
//
//  ⚠️ 개발하다 "이건 다음에" 가 생기면 **여기에 한 줄을 더한다.** 코드의 TODO 주석으로만 남기지 않는다.
//     - 새 항목: `.planned`. 손대기 시작하면 `.building`. 내보내면 `.shipped("1.2.0")`.
//     - id 는 한 번 정하면 바꾸지 않는다(문구는 바꿔도 된다).
//     - 문구는 사용자 말로 쓴다(내부 이름 · 기술 용어 금지). 영어는 BurningParchment/Localizable.xcstrings 에
//       다른 문구처럼 넣는다(빈칸이 있으면 영어 쓰는 사람에게 한국어가 보인다).
//     - 사용자에게 보일 만한 것만 적는다. 리팩터링 · 시험 · 빌드 설정은 `.sprintcommander/tasks.json` 의 몫이다.
//

import SwiftUI
import LeeoKit

extension BurningParchmentSpec {
    static var roadmap: [LeeoRoadmapItem] {[
        // MARK: 다음에 만들어요
        .init(id: "a11y.largetext", status: .shipped("1.2.1"),
              title: String(localized: "큰 글씨에 맞춘 화면", comment: "Roadmap item: layouts for larger text"),
              detail: String(localized: "글자 크기를 아주 키워도 잘리지 않고 보기 좋게 다시 배치돼요.", comment: "Roadmap item detail: layouts for larger text")),
        .init(id: "a11y.contrast", status: .shipped("1.2.1"),
              title: String(localized: "보기 편한 색과 대비", comment: "Roadmap item: better colors and contrast"),
              detail: String(localized: "대비를 높이거나 색을 구별하기 어려워도 타들어 가는 시간을 알아볼 수 있어요.", comment: "Roadmap item detail: better colors and contrast")),
        .init(id: "lang.more", status: .shipped("1.2.1"),
              title: String(localized: "더 많은 언어", comment: "Roadmap item: more languages"),
              detail: String(localized: "한국어와 영어에 이어 이제 일본어로도 쓸 수 있어요.", comment: "Roadmap item detail: more languages (Japanese added)")),
        .init(id: "onboarding", status: .shipped("1.2.1"),
              title: String(localized: "처음 쓰는 분을 위한 안내", comment: "Roadmap item: first-run guide"),
              detail: String(localized: "처음 열었을 때 무엇을 할 수 있는지 짧게 보여 줘요.", comment: "Roadmap item detail: first-run guide")),
        .init(id: "whatsnew", status: .shipped("1.2.1"),
              title: String(localized: "업데이트 소식", comment: "Roadmap item: what's new after an update"),
              detail: String(localized: "업데이트 뒤 처음 열 때 무엇이 새로 생겼는지 알려 줘요.", comment: "Roadmap item detail: what's new after an update")),
        .init(id: "tips", status: .shipped("1.2.1"),
              title: String(localized: "쓰는 요령 알려 주기", comment: "Roadmap item: in-app tips"),
              detail: String(localized: "알아 두면 편한 기능을 알맞은 때에 살짝 알려 줘요.", comment: "Roadmap item detail: in-app tips")),
        .init(id: "shortcuts", status: .planned,
              title: String(localized: "Siri와 단축어", comment: "Roadmap item: Siri and Shortcuts"),
              detail: String(localized: "Siri에게 물어 오늘 남은 시간을 바로 확인해요.", comment: "Roadmap item detail: Siri and Shortcuts")),
        .init(id: "sync.icloud", status: .planned,
              title: String(localized: "기기 간 동기화", comment: "Roadmap item: sync across devices"),
              detail: String(localized: "여러 기기에서 iCloud로 같은 회고와 데드라인을 이어서 봐요.", comment: "Roadmap item detail: sync across devices")),
        .init(id: "backup", status: .planned,
              title: String(localized: "백업과 되살리기", comment: "Roadmap item: backup and restore"),
              detail: String(localized: "회고와 데드라인을 파일로 저장하고 다시 불러올 수 있어요.", comment: "Roadmap item detail: backup and restore")),
        .init(id: "lock.faceid", status: .planned,
              title: String(localized: "Face ID 잠금", comment: "Roadmap item: Face ID lock"),
              detail: String(localized: "Face ID나 Touch ID로 앱을 잠가 내 회고를 지켜요.", comment: "Roadmap item detail: Face ID lock")),
        .init(id: "fold", status: .planned,
              title: String(localized: "펼치는 아이폰 화면", comment: "Roadmap item: foldable iPhone layout"),
              detail: String(localized: "펼치는 아이폰에서 넓은 화면을 두 쪽으로 나눠 써요.", comment: "Roadmap item detail: foldable iPhone layout")),
        .init(id: "data.delete", status: .planned,
              title: String(localized: "내 기록 한 번에 지우기", comment: "Roadmap item: delete all my data"),
              detail: String(localized: "원하면 앱 안에서 회고와 데드라인을 모두 지울 수 있어요.", comment: "Roadmap item detail: delete all my data")),
        .init(id: "autosave", status: .planned,
              title: String(localized: "쓰던 회고 이어 쓰기", comment: "Roadmap item: keep unsaved drafts"),
              detail: String(localized: "회고를 쓰다가 앱이 꺼져도 쓰던 내용이 남아 있어요.", comment: "Roadmap item detail: keep unsaved drafts")),
    ]}
}

// MARK: - 화면

/// 설정 ▸ 지원 ▸ 앞으로 만들 기능. "이런 기능이 있으면 좋겠어요" 는 기능 제안으로 시작하는 피드백 창을 연다.
struct RoadmapScreen: View {
    @State private var showFeedback = false

    var body: some View {
        LeeoRoadmapView<BurningParchmentSpec>(onSuggest: { showFeedback = true })
            .sheet(isPresented: $showFeedback) {
                NavigationStack {
                    LeeoFeedbackView<BurningParchmentSpec>(initialType: .feature)
                }
            }
    }
}
