# 앱스토어 스크린샷

## 무엇이 어디에 있나

| 폴더 | 내용 | 크기 |
|---|---|---|
| `raw-ko/`, `raw-en/` | 시뮬레이터 원본 캡처 | 1320×2868 (iPhone 17 Pro Max) |
| `marketing-ko/`, `marketing-en/` | **App Store Connect 에 올리는 것** | 1242×2688 |

마케팅 이미지는 원본을 리사이즈한 게 아니라 캔버스 자체를 1242×2688 로 잡고
렌더링한 것이다. 그래서 헤드라인 글자가 뭉개지지 않는다.

## 다시 만들기

1. 6.9인치 시뮬레이터(iPhone 17 Pro Max)를 켜고 앱을 설치한다.
2. 상태바를 고정한다 — 안 하면 실제 시각과 배터리가 그대로 찍힌다:
   ```
   xcrun simctl status_bar <UDID> override --time "9:41" \
     --batteryState discharging --batteryLevel 100 \
     --cellularBars 4 --cellularMode active --wifiBars 3 --wifiMode active
   ```
3. 언어는 **실행 인자로** 넘긴다. 시뮬레이터 전체 언어를 바꾸는 것보다 확실하다:
   ```
   xcrun simctl launch <UDID> com.burningparchment.app -AppleLanguages "(ko-KR)" -AppleLocale ko_KR
   ```
4. 화면은 `xcrun simctl io <UDID> screenshot raw-ko/01-week-dark.png` 로 저장한다
   (MCP 스크린샷은 확인용이라 해상도가 낮다).
5. 헤드라인·배치를 바꾸려면 `scripts/make_marketing_screenshots.py` 의 `SHOTS` 를
   고치고 `python3 scripts/make_marketing_screenshots.py ko` / `... en` 을 돌린다.

## 화면 고르는 기준

빈 화면은 찍지 않는다. 항아리에 재가 없으면 앱이 텅 비어 보이므로, 캡처 전에
App Group plist 에 회고 데이터를 심어 둔다 (`shared_reflections`, `shared_urn_meanings`).
**시뮬레이터가 꺼져 있을 때** 심어야 한다 — 켜져 있으면 cfprefsd 가 캐시를 들고
있다가 앱 실행 때 옛 값으로 덮어쓴다.

라이트·다크를 번갈아 넣어 두 테마를 다 보여준다 (`xcrun simctl ui <UDID> appearance light|dark`).

## 주의

영어 스크린샷에 **설정 화면 아래쪽(지원 섹션)이 들어가면 안 된다.** 그쪽 문구는
LeeoKit 이 그리는데 아직 한국어뿐이라, 영어 화면에 한국어가 섞여 나온다.
`06-settings` 는 그 위(취침 시간~화면 테마)까지만 담고 있다.
