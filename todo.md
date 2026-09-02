# todo

## 한국어 로케일 표기 정상화 (완료)
- [x] 원인 파악: 앱 로컬라이제이션 설정(developmentRegion/sourceLanguage = ko)은 정상,
      시각 표기에서 "AM"/"PM", "5h 24m" 이 코드에 영어로 하드코딩돼 있었음
- [x] `BurningParchment/Models/TimeFormat.swift` 추가 — 기기 언어·지역을 따르는 시각 포맷터
      (`short(hour:minute:)`, `hourLabel(_:)`), 위젯 타깃에도 공유
- [x] `BedtimeManager.formatTime` → `TimeFormat.short`
- [x] `SettingsView` 시(hour) 피커 라벨 / 추천 취침시간 프리셋 라벨 로케일 대응
- [x] `BedtimeHomeWidget` 취침시각·남은시간 문자열 로케일 대응
- [x] `BedtimeActivityAttributes.shortTimeString` → String(localized:)
- [x] `ReflectionBookView.timeString` 의 ko_KR 고정 로케일 제거
- [x] 위젯 String Catalog 에 "5시간 24분" 키 추가 (en: "5h 24m")
- [x] 시뮬레이터(ko_KR) 빌드·실행 확인 — "오전 7:00 / 오후 11:00" 정상 표시

## 1.0.9 — 공백 회수 · 재의 흐름 · 1년 열람 (완료)
- [x] 앱 버전 1.0.9(1) — pbxproj / Info.plist(앱·위젯) / project.yml
- [x] 무료 열람을 이번 달 → 최근 1년으로. GateKey.urn 값 하나(1 → 12)만 바꾸면 되게
      이미 되어 있었음. 선반 잠긴 줄·페이월 문구도 "1년"으로 맞춤
- [x] 빈 항아리는 정말 비어 보이게 — 담긴 재가 0톨이면 바닥 재 층을 그리지 않음
      (MixedAshUrnVisual.ashLayer 의 max(0.04, fillLevel) 하한 제거)
- [x] 화면 분리 — 선반은 "무엇이 담겼나", 새 AshInsightsView("재의 흐름")가
      "어떻게 흘러왔나"(분포 그래프 + 잔불 달력)
- [x] 기록 공백 회수 — 3일 이상 비었으면 "지난 N일간의 재를 어떻게 할까요?"
      실제로 담았을 때만 정리 처리(그냥 닫으면 다시 물어봄). 담기는 그 날짜로 입력창이 열림
- [x] 날려버리는 애니메이션 — AshPile(Animatable). 입자마다 다른 시점에 떠올라
      바람을 타고 흩어진다. Reduce Motion 이면 건너뛰고 바로 정리
- [x] 시뮬레이터(ko_KR) 확인 — 공백 카드 · 날아가는 재 3프레임 · 빈 항아리 · 재의 흐름
- [x] String Catalog 에 신규 문구 12개 en 번역 추가

### 메모
로컬에서 만들던 "달 항아리 선반" 작업은 원격의 기간 항아리(UrnPeriod, 달+주)와
겹쳐서 원격 쪽을 살리고 위 기능만 재이식했다. 버린 쪽은 backup/month-shelf-local
브랜치에 남아 있다 (나무 선반 UI가 필요해지면 그쪽 참고).
