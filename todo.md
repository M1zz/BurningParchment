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
