#!/usr/bin/env bash
# 생존 점검 — 라운드를 시작하기 전에 반드시 먼저 돌린다.
#
# ## 왜 이 스크립트가 존재하는가 (실측된 사고)
# R86 라운드에서 샌드박스가 초기화되어 R60~R86(27라운드분)이 전부 소실됐다.
# 원인은 단순했다: **커밋하지 않은 채 라운드를 끝내려 했고, 원격 백업이 0이었다.**
# 더 나쁜 것은 그 소실을 확정하고 원인을 진단한 직후에도
# 나는 R1~R59(90커밋)가 여전히 백업 0인 상태를 방치하고 새 기능을 만들고 있었다.
# 방금 배운 교훈을 30초 뒤에 어긴 것이다.
#
# 그래서 "반성"을 문장이 아니라 **실행 가능한 검사**로 바꾼다.
# 이 스크립트가 실패하면 기능 작업을 시작할 자격이 없다.
#
# ## 검사 항목 (모두 실측, 대리지표 금지)
#  ① 로컬 HEAD 가 원격 어딘가에 실제로 존재하는가 (ls-remote 로 확인)
#  ② 커밋되지 않은 변경이 며칠째 방치되고 있지 않은가
#  ③ git 설정이 살아있는가 (GIT_CONFIG_GLOBAL=/dev/null 재발 감지)
#  ④ 내가 믿는 상태 = 실제 디스크 상태인가 (핵심 파일 존재)
#
# 종료코드 0 = 안전. 1 = 작업 시작 금지.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1

FAIL=0
step() { printf '\n\033[1m%s\033[0m\n' "$1"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=1; }

step "① git 설정 생존 (GIT_CONFIG_GLOBAL 오염 감지)"
# 샌드박스는 GIT_CONFIG_GLOBAL=/dev/null 을 환경에 박아둔다. 그러면 credential.helper 가
# 저장되지 않아 푸시가 조용히 실패하고, safe.directory 등록이 안 돼 pub get 이 exit 128 로 죽는다.
GCG="${GIT_CONFIG_GLOBAL:-}"
if [ "$GCG" = "/dev/null" ]; then
  bad "GIT_CONFIG_GLOBAL=/dev/null — 모든 global git 설정이 버려진다. ~/.bashrc 7행을 고쳐라"
elif [ -z "$GCG" ] || [ "$GCG" = "$HOME/.gitconfig" ]; then
  ok "GIT_CONFIG_GLOBAL=${GCG:-(기본값)}"
else
  bad "GIT_CONFIG_GLOBAL=$GCG — 예상치 못한 값"
fi

step "② 원격 백업 존재 — 로컬 HEAD 가 원격에 도달했는가"
# 여기서 '원격이 등록되어 있다'는 것은 증거가 아니다. 실제로 그 커밋이 원격에 있어야 한다.
HEAD_SHA=$(git rev-parse HEAD 2>/dev/null)
FOUND=""
# 「조회 실패(인증/네트워크)」와 「조회 성공했으나 커밋이 없음」을 구분한다.
# 구분하지 않았던 초판은 실측 사고를 냈다: ~/.git-credentials 가 0바이트로
# 비워져 ls-remote 가 인증 실패했는데, 결과가 빈 문자열이라는 이유로
# "어느 원격에도 없다"고 단정했다. 실제로는 푸시가 되어 있었다.
# 즉 검사가 '모름'을 '없음'으로 보고했다 — 거짓 경보이고, 거짓 경보는
# 반복되면 사람이 검사를 무시하게 만들어 진짜 소실을 놓치게 한다.
REACHABLE=0
UNREACHABLE_MSG=""
for R in $(git remote); do
  # ls-remote 는 네트워크를 타므로 실패해도 스크립트를 죽이지 않는다.
  # 단, 실패 사유는 버리지 않고 붙잡아 둔다(위 사고의 원인).
  REFS=$(GIT_TERMINAL_PROMPT=0 timeout 120 git ls-remote "$R" 2>/tmp/lsremote_err.txt)
  if [ -z "$REFS" ]; then
    UNREACHABLE_MSG="${UNREACHABLE_MSG}${R}: $(head -1 /tmp/lsremote_err.txt 2>/dev/null)
"
    continue
  fi
  REACHABLE=1
  # HEAD 자체가 원격에 있는지, 또는 원격 어느 ref 의 조상인지 확인
  while read -r sha ref; do
    [ -z "$sha" ] && continue
    if [ "$sha" = "$HEAD_SHA" ]; then FOUND="$R/$ref (정확히 일치)"; break; fi
    if git merge-base --is-ancestor "$HEAD_SHA" "$sha" 2>/dev/null; then
      FOUND="$R/$ref (HEAD 가 조상으로 포함)"; break
    fi
  done <<< "$REFS"
  [ -n "$FOUND" ] && break
done
if [ -n "$FOUND" ]; then
  ok "HEAD ${HEAD_SHA:0:8} 는 원격에 있다 → $FOUND"
elif [ "$REACHABLE" -eq 0 ]; then
  # 어떤 원격도 조회하지 못했다 → 백업 여부를 '알 수 없다'.
  # 이것도 실패로 처리한다(안전 우선). 다만 원인을 정확히 말해야
  # 사람이 헛되게 재푸시하지 않고 인증부터 복구한다.
  bad "원격을 조회할 수 없어 백업 여부를 확인하지 못했다 (없다는 뜻이 아니다)"
  printf '%s' "$UNREACHABLE_MSG" | sed 's/^/      /'
  printf '      → 인증을 복구한 뒤(setup_github_environment) 다시 확인하라.\n'
  printf '      → ~/.git-credentials 가 0바이트로 비워지는 사례가 있다: wc -c ~/.git-credentials\n'
else
  bad "HEAD ${HEAD_SHA:0:8} 가 어느 원격에도 없다 — 샌드박스가 초기화되면 전부 소실된다. 지금 푸시하라"
fi

step "③ 미커밋 변경 방치 감지"
DIRTY=$(git status --porcelain | wc -l | tr -d ' ')
if [ "$DIRTY" -eq 0 ]; then
  ok "미커밋 변경 없음"
elif [ "$DIRTY" -le 40 ]; then
  # 변경이 있는 것 자체는 정상이다. 다만 이것이 '푸시되지 않은 상태'와 겹치면 위험하다.
  printf '  \033[33m!\033[0m %s\n' "미커밋 ${DIRTY}건 — 라운드를 끝내기 전에 반드시 커밋+푸시하라"
else
  bad "미커밋 ${DIRTY}건 — 너무 많다. 소실 시 피해가 크다. 즉시 커밋하라"
fi

step "④ 상태 착각 감지 — 내가 믿는 파일이 실제로 있는가"
# 라운드 시작 시 '이미 만들었다'고 믿는 파일이 디스크에 없으면 즉시 알아야 한다.
# 소실을 사용자 질문으로 알게 되는 일이 재발하지 않도록 한다.
MISSING=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  case "$f" in \#*) continue ;; esac
  if [ ! -e "$f" ]; then bad "선언된 산출물 없음: $f"; MISSING=$((MISSING+1)); fi
done < <(cat tool/audit/expected_artifacts.txt 2>/dev/null)
[ "$MISSING" -eq 0 ] && ok "선언된 산출물 전부 존재 ($(grep -cvE '^\s*(#|$)' tool/audit/expected_artifacts.txt 2>/dev/null || echo 0)건 확인)"

printf '\n'
if [ "$FAIL" -eq 0 ]; then
  printf '\033[32m생존 점검 통과 — 작업을 시작해도 된다\033[0m\n'
else
  printf '\033[31m생존 점검 실패 — 기능 작업을 시작하지 말고 위 항목을 먼저 해결하라\033[0m\n'
fi
exit "$FAIL"
