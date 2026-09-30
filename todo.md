# todo

## 내일의 양피지 · 아침 확인 · 억울한 그을음 방지 (구현 완료, 커밋 전)
원칙: **그을음은 확인된 만큼만.** 건강 앱 기록이나 본인 답변이 없으면 항상 0.
- [x] 취침 이후 하트 대신 "내일의 양피지"가 천천히 탄다 (밤을 다 새우면 기상 시각에 한 장).
      밤사이 모습은 보여주기만 한다 (`BurningParchmentView.tomorrowParchmentView`)
- [x] 취침 이후에도 후 불어 끌 수 있다 → 그 자리에서 멈춤 (`NightManager.markExtinguished`)
- [x] `NightRecord`/`NightManager` — 하룻밤 기록. 앱을 켜 둔 흔적·늦게 끈 시각은
      **아침 질문의 기본값으로만** 쓰고 그것만으로 그을리지 않는다 (새벽에 잠깐 깬 사람 보호)
- [x] `SleepHealth` — 건강 앱 수면 기록(잠든 시각)으로 자동 확정. 워치 없으면 "잠자리에 든" 시각
- [x] `MorningCheckInView` — 기록이 없으면 하룻밤에 한 번 묻는다. 기본 답 "제시간에 잤어요",
      늦었으면 시각 + (선택) 이유·다음 계획 → 기존 변명 기록으로 저장. 건강 기록이 틀리면 직접 고치기
- [x] 안전장치: 답 안 하고 닫으면 0 / 새 밤이 시작되면 미확인 밤은 0 으로 닫음 /
      앱을 며칠 안 열어도 가장 최근 밤만 묻고 나머지는 기록조차 안 됨 / 10분 유예
- [x] 확정된 그을음은 다음 날 양피지 오른쪽 아래에 검게 남고, 낮의 불길이 지나가면 문구와 함께 사라짐
- [x] 제시간에 잠든 게 확인되면 불을 안 껐어도 "저절로 꺼진 조각"(그을린 질감)을 준다
- [x] 조각 뒷면 쓰기를 아침으로 옮김 — 불 끈 직후엔 저장만. 뒤집기 카드(`FragmentFlipCard`),
      모은 조각에서도 언제든 뒷면 쓰기/고쳐 쓰기
- [x] 취침 직후 뜨던 변명 시트(`BedtimeExcuseSheetView`) 제거 → 아침 확인의 "늦게 잤어요"로 합침
- [x] 설정 ▸ 수면 기록 연결, HealthKit entitlement, 권한 문구 ko/en, PRIVACY.md·docs/privacy.html
- [x] String Catalog 신규 60개 en 번역, 쓰이지 않게 된 키 정리
- [x] 시뮬레이터 확인 — 밤 화면, 아침 확인 화면, 그을린 다음 날 화면
- [ ] **실기기 확인** — HealthKit 은 App ID 에 HealthKit capability 가 켜져 있어야 서명된다
      (자동 서명이면 Xcode 가 처리). 워치 유/무 각각 잠든 시각이 제대로 잡히는지
- [ ] 위젯·Live Activity 의 수면 화면은 아직 하트다 — 내일의 양피지로 바꿀지 결정 필요
- [ ] 뒤집기 카드·늦게 잤어요 흐름은 시뮬레이터에서 탭으로 끝까지 눌러 보지 못했다

## 1.1.1 — 후 불어 불 끄기 · 남은 조각 모으기 (구현 완료, 실기기 확인 필요)
- [x] 취침 30분 전 ~ 취침 시각에 메인(오늘) 하단에 "후 불어서 불 끄기" 버튼
      (`BedtimeManager.isInBlowOutWindow`, 창 길이는 `blowOutWindowSeconds`)
- [x] `BlowDetector` — 마이크 음량(dBFS)만 보고 센 입김이 약 0.8초 이어지면 꺼짐.
      녹음·저장 없음. **입김으로만 꺼진다** — 누르기 대체 경로는 일부러 두지 않았다.
      마이크 권한이 없으면 설정 열기 버튼만 보여 준다
- [x] `BlowOutView` — 남은 조각을 크게 띄우고 타는 가장자리에 불꽃, 입김에 불꽃이 눕고 줄어듦,
      꺼지면 연기 + 햅틱 → 조각에 한 줄(비우면 추천 글귀 `FragmentPhrase`) → 모아두기
- [x] `FragmentManager`(App Group `parchment_fragments`) — 하룻밤 한 조각, 취침 시각으로 구분
- [x] 불을 끈 밤은 메인 양피지가 끈 자리에서 멈추고 불꽃·불씨가 사라짐. 취침 후 변명 시트도 띄우지 않음
- [x] `FragmentCollectionView` — 헤더의 조각 아이콘(조각이 있을 때만)에서 열람·삭제
- [x] Info.plist 마이크 사용 설명(ko/en), String Catalog 신규 문구 en, PRIVACY.md·docs/privacy.html 마이크 항목
- [x] 시뮬레이터 확인(ko) — 버튼 → 타는 조각 → 연기 → 한 줄 쓰기 → 멈춘 양피지 → 모은 조각 카드
- [ ] **실기기에서 입김 감도 확인** — 시뮬레이터로는 입김을 넣을 수 없어 임계값
      (`blowThreshold` 0.62, `fillPerSecond` 1.4)을 실제로 불어 보며 맞춰야 한다.
      말소리·주변 소음에 꺼지지 않는지도 같이 볼 것
- [ ] Live Activity·위젯은 불을 꺼도 계속 타는 모습이다 (이번엔 건드리지 않음)
- [x] 1.1.1(빌드 1)로 올리고 `RELEASE_NOTES.md` 1.1.1 절(ko/en) 작성 — `DeployBar --reponotes` 확인

## 라이트 모드 · 스토어 영어 (완료)
- [x] 앱이 `.preferredColorScheme(.dark)` 로 다크를 못박고 있던 것을 설정값으로 바꿈
      (`AppTheme` = 시스템 설정 / 라이트 / 다크, 기본값은 시스템 설정)
- [x] `BurningParchment/Theme/Theme.swift` 추가 — 동적 UIColor 로 만든 색 토큰.
      호출부가 colorScheme 을 읽지 않아도 되고 Canvas·Gradient 안에서도 쓸 수 있다.
      다크 값은 기존 화면의 색을 그대로 옮겨 와서 다크는 한 픽셀도 안 변한다.
      appBackground / appBackgroundWarm / ink / inkMuted / ember / emberDeep /
      emberGlow / emberGlowDeep / onEmber / successInk / appShadow
- [x] 뷰 9개의 UI 크롬 색(≈500곳)을 토큰으로 교체.
      **불꽃·재·그을음·양피지는 실제 물질의 색이라 그대로 뒀다** — 촛불은 낮에도 주황색이다
- [x] `.blendMode(.screen)` → `.fireBlend()`. screen 은 미색 바탕에서 흰색으로 날아가
      라이트 모드에서 불꽃이 통째로 사라졌었다. 라이트에서는 그냥 겹쳐 그린다
- [x] DatePicker 3곳의 `.colorScheme(.dark)` 제거 (라이트 테마에서 검은 판이 떴다)
- [x] AccentColor 에 라이트 변형 추가 (기존 #FF8033 은 미색 위에서 너무 밝다)
- [x] 설정에 "화면 테마" 섹션 + String Catalog 에 신규 5개 ko/en
- [x] 시뮬레이터(라이트/다크 × 한국어/영어) 확인 — 주간 양피지·항아리·회고 입력·
      데드라인 편집(DatePicker)·페이월·설정
- [x] 스토어 영어: `deploy.env` LOCALES=ko,en · `RELEASE_NOTES.md` 1.1.0 절(ko/en)
- [x] `scripts/predeploy.sh` 통과

### 남은 일 (사람이 해야 함)
- App Store Connect ▸ 앱 정보 ▸ 현지화에서 **영어를 추가**해야 en 릴리즈노트가 올라간다.
  앱을 영어로 번역한 것과 스토어 페이지에 영어를 추가한 것은 별개다.
- 위젯·Live Activity 는 지금도 고정 다크다. 위젯은 앱의 테마 설정을 볼 수 없어
  (App Group 에 값을 넣고 뷰마다 colorScheme 을 덮어써야 한다) 앱과 어긋날 수 있어서
  이번엔 건드리지 않았다. 홈 화면 배경 위에 놓이는 물건이라 고정 디자인도 무리는 아니다.
- LeeoKit 의 지원 섹션 문구(지원 페이지·개인정보 처리방침·이용약관·사용 통계)는
  한국어만 있다. 영어 기기에서도 한국어로 뜬다 — LeeoKit 쪽 번역이 필요하다.

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
