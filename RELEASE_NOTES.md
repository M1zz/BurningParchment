# 릴리즈 노트

## 1.0.7 (build 1)

### App Store "이번 버전의 새로운 기능" — 한국어

```
🔓 프로 잠금해제
한 번의 구매로 항아리와 데드라인을 무제한으로 만들 수 있어요. 구독 없이 평생 이용합니다.

🔒 잠금 화면 위젯
잠금 화면에서 바로 취침까지 남은 시간을 확인하세요. 원형 게이지, 카운트다운, 한 줄 요약 세 가지 모양을 지원합니다.

🌏 영어 지원
앱 전체가 영어로도 표시됩니다. 기기 언어에 맞춰 자동으로 바뀌어요.

🛠 개선
• 한국어 기기에서 위젯 문구가 영어로 표시되던 문제를 고쳤어요.
• 위젯의 남은 시간 타이머가 왼쪽으로 치우쳐 보이던 문제를 고쳤어요.
• 결제 화면에 이용약관·개인정보처리방침 링크를 추가했습니다.
• 내부 구조를 정리해 앱이 조금 더 가볍고 안정적으로 동작합니다.
```

### App Store "What's New" — English

```
🔓 Pro Unlock
One purchase, unlimited urns and deadlines. No subscription — yours forever.

🔒 Lock Screen Widgets
Check the time left before bed straight from your Lock Screen. Three shapes: circular gauge, live countdown, and a single-line summary.

🌏 English Support
The whole app now speaks English, switching automatically with your device language.

🛠 Improvements
• Fixed widgets showing English text on Korean-language devices.
• Fixed the remaining-time timer in widgets appearing shifted to the left.
• Added Terms of Use and Privacy Policy links to the purchase screen.
• Internal cleanup for a lighter, more stable app.
```

### 변경 내역 (개발용)

**기능**
- 프로 일회성 잠금해제 (StoreKit 2, 비소모성 IAP `com.burningparchment.app.pro`) — 무료는 항아리 1개·데드라인 1개, 초과 시 페이월
- 설정에 프로 섹션 (업그레이드 / 구매 복원 / 이용 상태)
- 잠금 화면 액세서리 위젯 — `.accessoryCircular` / `.accessoryRectangular` / `.accessoryInline`
- 영어 로컬라이제이션 전면 적용 (String Catalog)
- 페이월에 이용약관(Apple 표준 EULA)·개인정보처리방침 링크 추가

**버그 수정**
- 한국어 기기에서 앱·위젯이 영어로 표시되던 문제 수정 — String Catalog 의 `sourceLanguage` 는 `ko` 인데 프로젝트 `developmentRegion` 이 `en` 이었고, 위젯 카탈로그에 명시적 `ko` 항목이 없어 `ko.lproj` 자체가 만들어지지 않아 한국어 기기가 `en.lproj` 로 떨어졌다. `developmentLanguage: ko` + 두 타깃 `CFBundleDevelopmentRegion: ko` 지정, 앱·위젯 카탈로그에 `ko` 항목 명시로 해결
- 누락돼 있던 영어 번역 6건 보강 (`%lld` → `%@` 로 재추출되며 짝을 잃은 항목들), 설정의 "지원" 섹션 라벨 영어 번역 추가
- 홈 화면 위젯(Small/Large)의 `Text(_:style:.timer)`가 예약 폭 안에서 leading으로 붙어 왼쪽으로 치우쳐 보이던 문제 수정 — 명시적 `multilineTextAlignment` 지정
- Medium 위젯·잠금 화면 직사각형 위젯 타이머의 좌측 들여쓰기 제거

**내부**
- StoreKit 엔진을 LeeoKit `LeeoStore`로 이관 (기존 `StoreManager`는 파사드로 유지)
- 피드백 허브용 App Group 컨테이너 entitlements 추가 (기존 컨테이너 보존)
- LeeoKit 의존성을 로컬 경로 → 원격 SPM 패키지(3.2.0+)로 전환
- `BurningParchmentSpec`을 LeeoKit 3.x 계약으로 마이그레이션 — `paywall` 직접 선언 대신 `legal` + `monetization`(`.freemium`)에서 유도
- 무료 한도(항아리 1·데드라인 1) 선언을 게이트 정책 한 곳으로 일원화 (`StoreManager`가 이를 읽음)
- `appStoreID`(6758995390)·`capabilities` 선언 추가
- `LeeoKit.bootstrap`으로 사용량 기록·분석 싱크·MetricKit 크래시 진단·사용현황 스냅샷을 한 번에 활성화
- `PrivacyInfo.xcprivacy` 추가 (앱·위젯 각각) — `UserDefaults` required reason(CA92.1)과 수집 데이터 유형 선언
- String Catalog Xcode 포맷 정규화

**개인정보 처리방침 개정 (중요)**
- 익명 사용 통계와 크래시 진단을 켜면서 `PRIVACY.md`·`docs/privacy.html`의 "분석 도구를 사용하지 않습니다 / 수집 데이터 없음" 문구가 사실과 달라져 전면 개정했다.
- 실제 전송 항목: ① 익명 사용 통계(무작위 설치 UUID·앱 버전·플랫폼/OS·로케일·실행 횟수·이벤트 이름) ② 크래시·행 진단(MetricKit) ③ 사용자가 직접 보낸 피드백(본문·기기 정보, 입력한 경우 이름·이메일). 모두 개발자 본인의 CloudKit으로만 전송되며 제3자 SDK·광고·추적은 없다.
- ⚠️ **제출 전 App Store Connect의 앱 개인정보(Privacy Nutrition Label)를 "수집 안 함" → 제품 상호작용·식별자·진단·사용자 콘텐츠 수집으로 갱신해야 한다.**
- PRIVACY.md의 문의 이메일을 `leeo@kakao.com` → `mizzking75@gmail.com`으로 통일 (지원 페이지·앱 내 문의처와 일치)

**버전 관리 메모**
- 버전의 소스 오브 트루스는 `project.yml`입니다. Info.plist는 XcodeGen이 생성하므로, plist만 고치면 `xcodegen` 재실행 시 되돌아갑니다. 반드시 `project.yml`의 `CFBundleShortVersionString`과 `MARKETING_VERSION`을 함께 올리세요.
