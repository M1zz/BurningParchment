# 🔥 불타는 양피지 (Burning Parchment)
## 취침시간 카운트다운 앱

밤 9시 이후부터 사용자가 설정한 취침시간까지 남은 시간을 **불타는 양피지** 비주얼로 보여주는 iOS 앱입니다.

---

## 📱 주요 기능

### 🔥 불타는 양피지 메인 화면
- 낡은 양피지가 **위에서부터 타들어가며** 남은 시간을 시각적으로 표현
- 불꽃 파티클, 불씨, 재(ash) 파티클 애니메이션
- 불규칙한 타는 경계선으로 사실적인 효과
- 양피지 가장자리 불규칙 처리 (낡은 느낌)
- 타는 부분 주변 그을림 그라데이션

### ⏱ 타이머
- 밤 9시(21:00) 자동 시작
- 설정한 취침시간까지 실시간 카운트다운
- 시:분:초 세리프체 디스플레이
- 진행률 바 (🔥→🌙)

### 🏝 다이나믹 아일랜드 & Live Activity
- **Dynamic Island (Compact)**: 불꽃 아이콘 + 남은시간
- **Dynamic Island (Expanded)**: 전체 타이머 + 진행바 + 취침시간 정보
- **잠금화면 Live Activity**: 미니 양피지 프리뷰 + 타이머

### ⚙️ 설정
- 취침시간 피커 (시/분)
- 빠른 선택 프리셋 (10PM ~ 1AM)
- UserDefaults 자동 저장

---

## 🏗 프로젝트 구조

```
BurningParchment/
├── BurningParchment/                    # 메인 앱 타겟
│   ├── BurningParchmentApp.swift        # @main 진입점
│   ├── Models/
│   │   ├── BedtimeManager.swift         # 취침시간 관리 ViewModel
│   │   └── BedtimeActivityAttributes.swift  # Live Activity 모델
│   ├── Views/
│   │   ├── ContentView.swift            # 메인 화면
│   │   ├── BurningParchmentView.swift   # 불타는 양피지 뷰 (핵심)
│   │   └── SettingsView.swift           # 설정 화면
│   └── Assets.xcassets/
│
└── BurningParchmentWidgets/             # 위젯 Extension 타겟
    ├── BurningParchmentWidgetsBundle.swift   # 위젯 번들
    └── BedtimeLiveActivity.swift        # 다이나믹 아일랜드 UI
```

---

## 🔧 Xcode 프로젝트 설정 방법

### 1단계: 새 Xcode 프로젝트 생성
1. Xcode > File > New > Project
2. **App** 선택
3. Product Name: `BurningParchment`
4. Interface: **SwiftUI**
5. Language: **Swift**

### 2단계: 소스 파일 추가
1. 기본 생성된 `ContentView.swift` 삭제
2. 이 프로젝트의 `BurningParchment/` 폴더 내 파일들을 모두 프로젝트에 추가

### 3단계: Widget Extension 추가 (다이나믹 아일랜드)
1. File > New > Target
2. **Widget Extension** 선택
3. Product Name: `BurningParchmentWidgets`
4. ✅ **Include Live Activity** 체크
5. 기본 생성된 파일들 삭제
6. `BurningParchmentWidgets/` 폴더의 파일들 추가

### 4단계: 공유 파일 설정
`BedtimeActivityAttributes.swift` 파일을:
- **메인 앱** 타겟과 **Widget Extension** 타겟 양쪽에 모두 포함시켜야 합니다
- File Inspector > Target Membership에서 두 타겟 모두 체크

### 5단계: Info.plist 설정
메인 앱의 Info.plist에 추가:
```xml
<key>NSSupportsLiveActivities</key>
<true/>
```

### 6단계: 배포 타겟
- iOS 16.2 이상 (Live Activity 지원)
- iPhone만 지원 권장

---

## 🎨 디자인 컨셉

| 상태 | 화면 |
|------|------|
| 밤 9시 전 | 온전한 양피지 + "밤 9시에 양피지가 타기 시작합니다" |
| 카운트다운 중 | 위에서부터 타들어가는 양피지 + 타이머 + 파티클 |
| 취침시간 도달 | 완전히 탄 양피지 + "취침 시간입니다" + 달 아이콘 |

### 색상 팔레트
- **양피지**: `#D1B88C` → `#A6853A` (그라데이션)
- **불꽃**: 노랑 → 주황 → 빨강
- **배경**: 순수 검정
- **텍스트**: 갈색 계열 세리프체

---

## ⚡ 핵심 구현 포인트

### ParchmentShape
- `Shape` 프로토콜 구현
- `burnProgress`에 따라 위에서부터 사라지는 형태
- `flamePhase`로 타는 경계선의 불규칙한 애니메이션
- `irregularEdge()`로 낡은 양피지 느낌의 가장자리

### BedtimeManager
- 밤 9시~취침시간 구간의 `progress` 실시간 계산
- 자정 넘어가는 취침시간 처리 (예: 새벽 1시)
- ActivityKit을 통한 Live Activity 관리

### 파티클 시스템
- `EmberParticle`: 불씨 (위로 올라가며 사라짐)
- `AshParticle`: 재 (아래로 떨어지며 사라짐)
- Canvas 기반 불꽃 렌더링

---

## 📋 요구사항

- **iOS**: 16.2+
- **Xcode**: 15.0+
- **Swift**: 5.9+
- **기기**: iPhone (Dynamic Island 지원 기기 권장)

---

## 🚀 향후 개선 아이디어

- [ ] 양피지에 손글씨 느낌의 메시지 표시
- [ ] 취침 직전 알림 (10분, 5분 전)
- [ ] 수면 기록 통계
- [ ] 양피지 텍스쳐 커스터마이징
- [ ] 배경 사운드 (모닥불, 자연소리)
- [ ] watchOS 컴플리케이션
- [ ] 트리거 시간 커스터마이징 (9시 외 다른 시간)
