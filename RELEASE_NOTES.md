# 릴리즈 노트

## 1.0.9 (build 1)

App Store Connect v1.0.9 에 실제로 올린 문구입니다.
릴리즈노트 규칙(특수기호·이모지 없이, 한 줄 한 문장, 40자 이내)을 따릅니다.

### App Store "이번 버전의 새로운 기능" — 한국어

```
며칠 만에 돌아와도 그 사이의 시간을 담거나 날릴 수 있어요
분포 그래프와 잔불 달력을 재의 흐름 화면에 모았습니다
지난 항아리를 최근 1년까지 무료로 열어볼 수 있어요
아무것도 담기지 않은 항아리가 이제 비어 보입니다
```

### App Store "What's New" — English

⚠️ App Store 페이지에 영어 현지화가 없어 **아직 올릴 자리가 없습니다.**
App Store Connect ▸ 앱 정보 ▸ 현지화에서 영어를 추가하면 그대로 쓸 수 있습니다.

```
Keep or scatter the time you were away
The graph and calendar moved to Ash Flow
Past urns stay open for a year, free
An empty urn now really looks empty
```

## 1.0.8 (build 1)

### App Store "이번 버전의 새로운 기능" — 한국어

```
🏺 월별·주별 항아리
항아리를 직접 만들 필요가 없어졌어요. 재를 담으면 그 날짜의 주 항아리에 저절로 쌓입니다. 선반에서 달을 열면 1주차, 2주차… 그 달의 항아리들이 나와요.

✍️ 의미는 당신이 붙이는 것
항아리 안의 재는 당신이 이름을 붙이기 전까진 그냥 재예요. 열어보면 "이 주는 당신에게 어떤 의미였나요?"라고 물어봅니다. 한 마디를 새기는 순간 잿빛이던 재에 색이 돌아와요.

🔓 프로에서 지난 항아리 열기
무료로도 재는 계속 쌓입니다. 프로를 구매하면 몇 달 전 항아리까지 거슬러 올라가 다시 읽을 수 있어요.

🛠 개선
• 시각 표기가 기기 언어와 지역 설정을 따라갑니다.
• 항아리 속 재의 모양이 열 때마다 달라지던 문제를 고쳤어요.
• 문의 이메일 주소를 정리했습니다.
```

### App Store "What's New" — English

```
🏺 Urns by Month and Week
No more creating urns by hand. Whatever you write settles into that date's weekly urn on its own. Open a month on the shelf and its urns are waiting — week 1, week 2, and so on.

✍️ You Give It Meaning
Ash in an urn stays just ash until you name it. Open one and it asks: what did this week mean to you? Inscribe a word and the color returns to the ash.

🔓 Reach Back with Pro
Ash keeps collecting for free. Pro opens every urn from months past, to read again.

🛠 Improvements
• Times now follow your device's language and region settings.
• Fixed ash rearranging itself inside an urn every time you opened it.
• Cleaned up the contact email address.
```

### 변경 내역 (개발용)

**기능 — 기간 항아리로 전환**
- 사용자 생성 항아리(`Urn`) 폐지. 항아리는 회고의 `date` 에서 파생되는 값(`UrnPeriod`)이 됐다
- 주차는 달력 주가 아니라 날짜 기준으로 끊는다 (1~7일 = 1주차, 8~14일 = 2주차 …) — 한 주가 두 달에 걸치지 않아 모든 재가 정확히 하나의 주 항아리에만 담긴다
- 선반에 달 항아리가 놓이고, 달을 열면 그 달의 주 항아리 그리드가 나온다. 맨 위에는 지금 재가 담기는 이번 주 항아리 바로가기
- 회고 입력에서 항아리 선택기 제거 — 어디에 담기는지만 상단에 표시
- 잔불 달력의 드래그 앤 드랍 이동 제거 (담기는 항아리를 날짜가 정하므로 옮길 대상이 없다)

**기능 — 의미 부여 (`UrnMeaning`)**
- 항아리마다 "새길 한 마디 + 본문"을 남길 수 있다. 주 항아리·달 항아리 모두 대상
- 의미가 없는 항아리는 재가 색을 잃는다 — 입자·카테고리 점·재 목록·선각 문양이 모두 잿빛. 의미를 적는 순간 4색이 돌아온다
- 재는 쌓였는데 아직 이름이 없는 지난 주 항아리가 있으면 목록 맨 위에서 한 번 물어본다
- 의미 작성 화면은 담긴 재를 먼저 보여준 뒤 질문한다

**과금 게이트 변경**
- 항아리가 자동 생성되면서 "개수 한도" 게이트가 무의미해져 **열람 가능한 달 수**로 전환. `BurningParchmentSpec.gate.freeLimits[.urn]` 값을 그대로 개월 수로 읽는다 (1 = 이번 달만)
- 무료에서도 재는 계속 쌓이므로 결제 시 지난 항아리가 그대로 열린다 — 잃는 데이터 없음
- 페이월·설정 문구를 "항아리 무제한" → "지난 항아리 모두 열기"로 교체

**마이그레이션**
- v1 사용자가 지은 항아리 이름은 갈 곳이 없어지므로, 해당 회고의 키워드가 비어 있으면 항아리 이름을 키워드로 옮겨 보존하고 `shared_urns` 만 지운다. 회고 본문·분류·날짜는 그대로 남아 날짜에 따라 담긴다

**버그 수정**
- 항아리 재 입자의 배치 씨앗이 `String.hashValue` 라 실행할 때마다 재 모양이 바뀌던 문제 수정 — FNV-1a 로 고정
- 시각 표기의 하드코딩된 AM/PM·h/m 제거, 로케일 대응 (`TimeFormat`)

**내부**
- `Urn` → `LegacyUrn` (마이그레이션 전용으로만 잔존), `ReflectionManager` 는 회고와 의미 두 가지만 저장
- 신규 한국어 문자열 41건 영어 번역 포함 String Catalog 반영
- 문의 이메일을 `leeo@kakao.com` 으로 통일

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
- PRIVACY.md의 문의 이메일을 `leeo@kakao.com` → `leeo@kakao.com`으로 통일 (지원 페이지·앱 내 문의처와 일치)

**버전 관리 메모**
- 버전의 소스 오브 트루스는 `project.yml`입니다. Info.plist는 XcodeGen이 생성하므로, plist만 고치면 `xcodegen` 재실행 시 되돌아갑니다. 반드시 `project.yml`의 `CFBundleShortVersionString`과 `MARKETING_VERSION`을 함께 올리세요.
