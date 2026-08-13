#!/usr/bin/env bash
# 릴리스 출시 차단 검사 — 스토어에 내보내면 안 되는 상태를 빌드 전에 막는다.
#
# ## 왜 필요한가
# 사용자 요청: "빌드할 때 이건 막을 수 있게 하라".
# 광고를 붙이면 **테스트 광고 ID 인 채로 출시**되는 사고가 대표적이다.
# 이 경우 앱은 정상 동작하고 광고도 보이기 때문에 **아무도 눈치채지 못한 채
# 수익이 0원**이 된다. 조용히 실패하는 사고이므로 사람의 주의력에 맡기면 안 되고
# 기계가 막아야 한다.
#
# ## 설계 원칙
# - 디버그/개발 빌드는 막지 않는다. 테스트 ID 는 개발 중에는 **정상**이다.
#   (자기 광고를 클릭하면 AdMob 계정이 정지되므로 개발 중엔 테스트 ID 가 옳다.)
#   따라서 이 검사는 `--release` 출시 빌드에서만 실패로 취급한다.
# - 실패는 실패로 보고한다. 우회 스위치를 만들지 않는다.
#   정말 테스트 ID 로 내보내야 한다면 값을 고치는 것이 정상 경로다.
#
# 사용법:
#   bash tool/audit/verify_release_ready.sh            # 검사만
#   bash tool/audit/verify_release_ready.sh --build-apk # 통과 시 릴리스 APK 빌드
#
# 종료코드 0 = 출시 가능. 1 = 출시 금지.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1

FAIL=0
step() { printf '\n\033[1m%s\033[0m\n' "$1"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=1; }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; }

# 구글 공식 테스트 ID (lib/services/ads_config.dart 와 값이 일치해야 한다)
TEST_APP_ID='ca-app-pub-3940256099942544~3347511713'
TEST_PUB='ca-app-pub-3940256099942544'

step "① AdMob — 테스트 광고 ID 로 출시하려는가"
# 판정 대상은 '실제로 앱에 심기는 값'이다: AndroidManifest 의 APPLICATION_ID.
# 소스 기본값(ads_config.dart)은 관리자가 원격으로 덮어쓰므로 여기서 막지 않는다.
MANIFEST=android/app/src/main/AndroidManifest.xml
if grep -q 'com.google.android.gms.ads.APPLICATION_ID' "$MANIFEST" 2>/dev/null; then
  MANIFEST_ID=$(grep -A2 'APPLICATION_ID' "$MANIFEST" | grep -o 'ca-app-pub-[0-9]*~[0-9]*' | head -1)
  if [ "$MANIFEST_ID" = "$TEST_APP_ID" ]; then
    bad "AndroidManifest 의 AdMob 앱 ID 가 구글 테스트 ID 다 ($MANIFEST_ID)"
    printf '      → 실 ID 로 바꿔라. 테스트 ID 로 출시하면 수익이 0원인데 광고는 정상으로 보여 눈치채지 못한다.\n'
  elif [ -z "$MANIFEST_ID" ]; then
    bad "APPLICATION_ID 메타데이터는 있는데 ca-app-pub-...~... 형식의 값이 없다"
  else
    ok "AdMob 앱 ID 는 실 ID 다 (${MANIFEST_ID})"
  fi
else
  warn "AndroidManifest 에 AdMob APPLICATION_ID 가 없다 — 광고를 쓰지 않는 빌드로 간주한다"
fi

step "② 광고 단위 ID 하드코딩 금지"
# 단위 ID 가 소스에 박히면 운영 중 교체가 불가능하다. 원격설정으로만 받아야 한다.
# ads_config.dart 의 테스트 상수는 예외다(기본값이자 검사 기준값이므로).
HARD=$(grep -rn "ca-app-pub-" lib/ --include=*.dart 2>/dev/null \
        | grep -v "lib/services/ads_config.dart" || true)
if [ -z "$HARD" ]; then
  ok "ads_config.dart 외에 하드코딩된 광고 ID 없음"
else
  bad "광고 ID 가 소스에 하드코딩되어 있다 — 원격설정으로 받아야 운영 중 교체가 가능하다"
  echo "$HARD" | head -5 | sed 's/^/      /'
fi

step "③ 학습데이터 사실검증"
# 정답과 해설이 어긋난 문항을 출시하면 학습자에게 직접 피해가 간다.
if python3 tool/audit/verify_learning_data.py > /tmp/vld.log 2>&1; then
  ok "$(grep -E '^✓ 위반 0건' /tmp/vld.log | head -1)"
else
  bad "학습데이터 검증 실패 — 아래 확인 후 고쳐라"
  grep -E '^  ✗|^✗' /tmp/vld.log | head -8 | sed 's/^/      /'
fi

step "④ 정적 분석"
if flutter analyze > /tmp/an.log 2>&1; then
  ok "analyze 통과"
else
  bad "analyze 실패"
  grep -E "error|warning" /tmp/an.log | head -8 | sed 's/^/      /'
fi

step "⑤ 테스트"
if timeout 900 flutter test > /tmp/ft.log 2>&1; then
  ok "$(grep -oE '\+[0-9]+ All tests passed' /tmp/ft.log | tail -1)"
else
  bad "테스트 실패"
  grep -E "^[0-9:]+ \+[0-9]+ -[0-9]+" /tmp/ft.log | tail -5 | sed 's/^/      /'
fi

printf '\n'
if [ "$FAIL" -ne 0 ]; then
  printf '\033[31m✗ 출시 금지 — 위 항목을 고치기 전에는 릴리스 빌드를 만들지 마라\033[0m\n'
  printf '  (이 검사를 우회하는 스위치는 일부러 만들지 않았다. 값을 고치는 것이 정상 경로다.)\n'
  exit 1
fi

printf '\033[32m✓ 출시 가능 상태\033[0m\n'

if [ "${1:-}" = "--build-apk" ]; then
  step "⑥ 릴리스 APK 빌드"
  flutter build apk --release --flavor user -t lib/main.dart
  exit $?
fi
exit 0
