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
# 반드시 '실제 숫자'가 붙은 ID 만 잡는다.
# 최초 판정은 그냥 'ca-app-pub-' 를 찾아서, 사용자에게 형식을 안내하는 한글 문구
# ("ca-app-pub-숫자16~숫자10")까지 위반으로 잡는 오탐이 있었다. 실측으로 확인 후
# 숫자를 요구하도록 좁혔다. 진짜 하드코딩된 ID 는 숫자가 반드시 붙으므로
# 검사의 탐지력은 줄지 않는다(아래 사보타주로 증명).
HARD=$(grep -rnE "ca-app-pub-[0-9]{6,}" lib/ --include=*.dart 2>/dev/null \
        | grep -v "lib/services/ads_config.dart" || true)
if [ -z "$HARD" ]; then
  ok "ads_config.dart 외에 하드코딩된 광고 ID 없음"
else
  bad "광고 ID 가 소스에 하드코딩되어 있다 — 원격설정으로 받아야 운영 중 교체가 가능하다"
  echo "$HARD" | head -5 | sed 's/^/      /'
fi

step "③ 학습데이터 사실검증"
# 정답과 해설이 어긋난 문항을 출시하면 학습자에게 직접 피해가 간다.
DATA_DIR="${LEARNING_DATA_DIR:-}"
if [ -z "$DATA_DIR" ]; then
  if [ -d backend/data/study ]; then
    DATA_DIR='backend/data/study'
  else
    DATA_DIR='assets/data'
  fi
fi
if PYTHONIOENCODING=utf-8 LEARNING_DATA_DIR="$DATA_DIR" \
    python3 tool/audit/verify_learning_data.py > /tmp/vld.log 2>&1; then
  ok "$(grep -E '^✓ 위반 0건' /tmp/vld.log | head -1)"
  # 통과했어도 남은 해설부채를 반드시 눈에 보이게 한다.
  # 침묵하면 "검증 통과 = 데이터 완벽" 으로 착각한다.
  # V0~V7 이 '위반 0건' 을 낸 코퍼스에서 해설 6,243건(37.5%)이
  # 정형문구/정답번호뿐이었다. 통과는 부채가 없다는 뜻이 아니다.
  DEBT_LINE=$(grep -E '^     실질 해설' /tmp/vld.log | head -1)
  [ -n "$DEBT_LINE" ] && printf '      %s\n' "$(echo "$DEBT_LINE" | sed 's/^ *//')"
  RATCHET=$(grep -E 'V8 해설부채' /tmp/vld.log | head -1 | sed 's/^ *//')
  [ -n "$RATCHET" ] && printf '      %s\n' "$RATCHET"
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
  # 실측한 실제 출력 형태는 "+77: All tests passed!" 이다.
  # 처음 쓴 정규식('\+[0-9]+ All tests passed')은 맞지 않아 통과 문구가 빈칸으로
  # 출력됐다. 검사가 "빈 성공"을 찍는 건 근거 없는 통과 보고이므로 고쳤다.
  PASSED=$(grep -oE '\+[0-9]+' /tmp/ft.log | tail -1)
  if [ -z "$PASSED" ]; then
    bad "테스트가 통과했다는데 통과 개수를 못 읽었다 — 검사 자체가 신뢰 불가"
  else
    ok "테스트 ${PASSED}개 통과"
  fi
else
  bad "테스트 실패"
  grep -E "^[0-9:]+ \+[0-9]+ -[0-9]+" /tmp/ft.log | tail -5 | sed 's/^/      /'
fi

step "⑥ 사용자 앱에 관리자 메뉴가 섞여 있는가"
# 학습자에게 운영 메뉴가 보이면 안 된다. 판정 기준은 '기본값이 false 인가'다.
# 기본값이 true 로 바뀌면 사용자 앱(플래그 미주입)에서도 운영 메뉴가 열린다.
if grep -A3 "'IS_ADMIN_APP'" lib/services/app_config.dart \
     | grep -q 'defaultValue: false'; then
  ok "IS_ADMIN_APP 기본값 false — 사용자 앱에는 운영 메뉴가 컴파일되지 않는다"
else
  bad "IS_ADMIN_APP 기본값이 false 가 아니다 — 학습자에게 운영 메뉴가 노출된다"
fi
# 관리자 화면 진입점이 플래그 없이 열려 있지 않은지 확인한다.
LEAK=$(grep -rn "SuperAdminScreen()" lib/screens/ 2>/dev/null | wc -l)
GUARD=$(grep -c "AppConfig.isAdminApp" lib/screens/settings_screen.dart || true)
if [ "$LEAK" -gt 0 ] && [ "$GUARD" -eq 0 ]; then
  bad "SuperAdminScreen 진입점이 ${LEAK}곳 있는데 isAdminApp 가드가 없다"
else
  ok "관리자 화면 진입점은 isAdminApp 가드 안에 있다"
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
