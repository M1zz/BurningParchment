#!/bin/zsh
# 프로 기능 스크린샷 원본(raw-<언어>/07~10, blowout)을 시뮬레이터에서 찍는다.
#
#   scripts/capture_raw_pro.sh <시뮬레이터 UDID> <ko|en>
#
# 6.9" 시뮬레이터(1320x2868, 예: iPhone 18 Pro Max)에 Debug 빌드가 build/dd 에 있어야 한다:
#   xcodebuild -project BurningParchment.xcodeproj -scheme BurningParchment \
#     -destination "id=<UDID>" -derivedDataPath build/dd build
#
# 앱을 지우고 새로 깔아 예시 데이터(-seedDemo)로 찍는다. 실행 인자는 BurningParchment/Debug/DebugLaunch.swift.
# 시스템 권한 창이 한 번 뜨면 앱을 지워도 남는다 — 그때는 시뮬레이터를 재부팅한다.
# 찍은 뒤: python3 scripts/make_marketing_screenshots.py <언어> <파일> · python3 scripts/make_creative_assets.py
set -e
D=$1; L=$2
ROOT=${0:A:h:h}
APP=$ROOT/build/dd/Build/Products/Debug-iphonesimulator/BurningParchment.app
OUT=$ROOT/docs/screenshots/raw-$L
LOC=$([ $L = en ] && echo en_US || echo ko_KR)

xcrun simctl uninstall $D com.burningparchment.app 2>/dev/null || true
xcrun simctl install $D $APP
xcrun simctl privacy $D grant microphone com.burningparchment.app
xcrun simctl status_bar $D override --time 9:41 --batteryState discharging --batteryLevel 100 --cellularBars 4 --wifiBars 3

shot() { name=$1; mode=$2; shift 2
  xcrun simctl ui $D appearance $mode
  sleep 2
  xcrun simctl terminate $D com.burningparchment.app 2>/dev/null || true
  xcrun simctl launch $D com.burningparchment.app -skipNotifications YES -seedDemo YES -forcePro YES \
    -AppleLanguages "($L)" -AppleLocale $LOC "$@" >/dev/null
  sleep 10
  xcrun simctl io $D screenshot $OUT/$name.png >/dev/null 2>&1
  echo "captured $OUT/$name.png"
}

shot 07-theme-dark dark  -parchmentStyle moonlit -demoProgress 0.45
shot 08-poster-dark dark -debugScreen poster
shot 09-year-light light -debugScreen year
shot blowout-dark dark   -debugScreen blowout -demoProgress 0.6 -parchmentStyle classic
shot bookexport light    -debugScreen bookExport -parchmentStyle classic

# 회고 책 PDF 의 앞 세 쪽(표지 + 본문 2쪽)을 10번 장에 쓴다
C=$(xcrun simctl get_app_container $D com.burningparchment.app data)
PDF=$(ls $C/tmp/*.pdf | head -1)
swift - "$PDF" "$OUT" <<'EOF'
import PDFKit
import AppKit
let doc = PDFDocument(url: URL(fileURLWithPath: CommandLine.arguments[1]))!
for i in 0..<min(3, doc.pageCount) {
    let img = doc.page(at: i)!.thumbnail(of: NSSize(width: 1260, height: 1785), for: .mediaBox)
    let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
    try! rep.representation(using: .png, properties: [:])!
        .write(to: URL(fileURLWithPath: CommandLine.arguments[2] + "/10-book-p\(i).png"))
}
EOF
rm -f $OUT/bookexport.png
echo "done: $OUT"
