#!/bin/zsh
# iPad 13" 스토어 스크린샷(2064x2752)을 언어마다 찍는다 — 시뮬레이터 화면 그대로 쓴다.
#
#   scripts/capture_ipad.sh <iPad 13" 시뮬레이터 UDID> <언어 ...>
#
# 미리: Debug 빌드를 그 시뮬레이터용으로 만든다 (데모 인자는 DEBUG 전용)
#   xcodebuild -project BurningParchment.xcodeproj -scheme BurningParchment \
#     -destination "id=<UDID>" -derivedDataPath build/ipad build
#
# 결과: ko·en·ja 는 docs/screenshots/marketing-<언어>/ipad-0N-….png, 나머지는 marketing/<언어>/ipad-0N-….png
#       (DeployBar 는 그림 크기로 iPad 자리를 알아본다)
#
# ⚠️ 창 모드로 바꾼 적 있는 시뮬레이터는 앱이 작은 창으로 열린다 — 새로 만든(지운) 시뮬레이터를 쓴다.
# ⚠️ 상태 막대의 날짜는 SpringBoard 가 시스템 언어로 그린다 — 시스템 언어를 바꾸고 SpringBoard 를 다시 띄운다.
# ⚠️ 시뮬레이터는 이미 있는 파일을 덮어쓰지 못한다(Operation not permitted) — 먼저 지운다.
set -e
D=$1; shift
ROOT=${0:A:h:h}
APP=$ROOT/build/ipad/Build/Products/Debug-iphonesimulator/BurningParchment.app

locale_of() {
  case $1 in
    en) echo en_US;; en-GB) echo en_GB;; ja) echo ja_JP;; ko) echo ko_KR;; zh-Hans) echo zh_CN;; zh-Hant) echo zh_TW;;
    pt-BR) echo pt_BR;; cs) echo cs_CZ;; da) echo da_DK;; el) echo el_GR;; nb) echo nb_NO;; sv) echo sv_SE;;
    vi) echo vi_VN;; *) echo "$1_${(U)1}";;
  esac
}

xcrun simctl uninstall $D com.burningparchment.app 2>/dev/null || true
xcrun simctl install $D $APP
xcrun simctl status_bar $D override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3

for L in "$@"; do
  LOC=$(locale_of $L)
  case $L in ko|en|ja) OUT=$ROOT/docs/screenshots/marketing-$L ;; *) OUT=$ROOT/docs/screenshots/marketing/$L ;; esac
  mkdir -p $OUT
  xcrun simctl spawn $D defaults write -g AppleLanguages -array $L
  xcrun simctl spawn $D defaults write -g AppleLocale $LOC
  xcrun simctl spawn $D launchctl kickstart -k system/com.apple.SpringBoard >/dev/null 2>&1 || true
  sleep 10

  shot() { name=$1; mode=$2; shift 2
    xcrun simctl ui $D appearance $mode
    sleep 2
    xcrun simctl terminate $D com.burningparchment.app 2>/dev/null || true
    perl -e 'alarm 120; exec @ARGV' xcrun simctl launch $D com.burningparchment.app -skipNotifications YES -skipOnboarding YES -hideTips YES \
      -seedDemo YES -forcePro YES -AppleLanguages "($L)" -AppleLocale $LOC "$@" >/dev/null
    sleep 10
    rm -f $OUT/$name.png
    perl -e 'alarm 150; exec @ARGV' xcrun simctl io $D screenshot $OUT/$name.png >/dev/null 2>&1 || echo "⚠️ 캡처 실패: $L $name"
  }

  shot ipad-01-week-dark dark    -demoProgress 0.45 -parchmentStyle classic
  shot ipad-02-flow-light light  -debugScreen insights
  shot ipad-03-theme-dark dark   -parchmentStyle moonlit -demoProgress 0.45
  shot ipad-04-urn-dark dark     -debugScreen urn
  echo "done $L"
done
