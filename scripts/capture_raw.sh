#!/bin/zsh
# 스크린샷 원본(raw-<언어>/) 전부를 시뮬레이터에서 찍는다 — 마케팅 10장 + 헤더용 불 끄기 화면.
#
#   scripts/capture_raw.sh <시뮬레이터 UDID> <ko|en|ja> [Debug 앱 경로]
#
# 6.9" 시뮬레이터(1320x2868, 예: iPhone 17 Pro Max)에 Debug 빌드가 필요하다:
#   xcodebuild -project BurningParchment.xcodeproj -scheme BurningParchment \
#     -destination "id=<UDID>" -derivedDataPath build/dd build
#
# 앱을 지우고 새로 깔아 예시 데이터(-seedDemo, 언어별 예시 글)로 찍는다. 실행 인자는 BurningParchment/Debug/DebugLaunch.swift.
# 처음 안내·새 소식·팁·알림 권한 창은 실행 인자로 끈다(-skipOnboarding · -hideTips · -skipNotifications).
# 시스템 권한 창이 한 번 뜨면 앱을 지워도 남는다 — 그때는 시뮬레이터를 재부팅한다.
# 찍은 뒤: python3 scripts/make_marketing_screenshots.py <언어> · python3 scripts/make_creative_assets.py <언어>
set -e
D=$1; L=$2
ROOT=${0:A:h:h}
APP=${3:-$ROOT/build/dd/Build/Products/Debug-iphonesimulator/BurningParchment.app}
OUT=$ROOT/docs/screenshots/raw-$L
case $L in
  en) LOC=en_US ;;
  ja) LOC=ja_JP ;;
  *)  LOC=ko_KR ;;
esac
mkdir -p $OUT

xcrun simctl uninstall $D com.burningparchment.app 2>/dev/null || true
xcrun simctl install $D $APP
xcrun simctl privacy $D grant microphone com.burningparchment.app
xcrun simctl status_bar $D override --time 9:41 --batteryState discharging --batteryLevel 100 --cellularBars 4 --wifiBars 3

shot() { name=$1; mode=$2; shift 2
  xcrun simctl ui $D appearance $mode
  sleep 2
  xcrun simctl terminate $D com.burningparchment.app 2>/dev/null || true
  xcrun simctl launch $D com.burningparchment.app -skipNotifications YES -skipOnboarding YES -hideTips YES \
    -seedDemo YES -forcePro YES -AppleLanguages "($L)" -AppleLocale $LOC "$@" >/dev/null
  sleep 10
  xcrun simctl io $D screenshot $OUT/$name.png >/dev/null 2>&1
  echo "captured $OUT/$name.png"
}

shot 01-week-dark dark     -demoProgress 0.45 -parchmentStyle classic   # 오늘 페이지 (요일에 따라 한 주가 거의 다 타 보일 수 있어서)
shot 02-month-light light  -period month -demoProgress 0.45 -parchmentStyle classic
shot 03-urn-dark dark      -debugScreen urn
shot 04-flow-light light   -debugScreen insights
shot 05-book-dark dark     -debugScreen book
shot 06-settings-dark dark -debugScreen settings
shot 07-theme-dark dark    -parchmentStyle moonlit -demoProgress 0.45
shot 08-poster-dark dark   -debugScreen poster
shot 09-year-light light   -debugScreen year
shot blowout-dark dark     -debugScreen blowout -demoProgress 0.6 -parchmentStyle classic
shot bookexport light      -debugScreen bookExport -parchmentStyle classic

# 회고 책 PDF 의 앞 세 쪽(표지 + 본문 2쪽)을 10번 장에 쓴다
C=$(xcrun simctl get_app_container $D com.burningparchment.app data)
PDF=$(ls $C/tmp/*.pdf | head -1)
swift - "$PDF" "$OUT" <<'SWIFT'
import PDFKit
import AppKit
let doc = PDFDocument(url: URL(fileURLWithPath: CommandLine.arguments[1]))!
for i in 0..<min(3, doc.pageCount) {
    let img = doc.page(at: i)!.thumbnail(of: NSSize(width: 1260, height: 1785), for: .mediaBox)
    let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
    try! rep.representation(using: .png, properties: [:])!
        .write(to: URL(fileURLWithPath: CommandLine.arguments[2] + "/10-book-p\(i).png"))
}
SWIFT
rm -f $OUT/bookexport.png
echo "done: $OUT"
