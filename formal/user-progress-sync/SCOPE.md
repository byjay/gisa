# 사용자별 학습진도 동기화 모델 범위

## 질문

Google/Kakao API 세션을 바꾸는 동안 앱의 Hive 상자, 늦은 GET 응답, 삭제 기록, 두 기기의 동시 D1 쓰기가 계정 경계를 넘거나 최근 기록을 잃는가?

## 코드 계약

- 로컬 상자 이름은 게스트의 기존 이름 또는 사용자 ID의 SHA-256 namespace로 고정한다. 이전 게스트 기록을 첫 계정에 자동 귀속하지 않는다.
- 계정 전환은 세대를 올리고 메모리 화면 값을 비운다. 요청 또는 상자 열기가 시작된 세대가 현재 세대와 다르면 결과를 현재 화면/상자에 적용하지 않는다.
- 서버 소유 키는 요청 본문이 아니라 검증한 세션의 `userId`다.
- 질문 진도, 세션, CBT 결과만 원격 동기화한다. 문제 본문, 정답, 해설은 payload에 넣지 않는다.
- 세션/CBT 삭제 tombstone은 오래된 기기의 이전 레코드보다 우선한다. 응시등록은 삭제 시각보다 같거나 오래된 레코드만 차단한다. 사용자가 다시 저장해 `updatedAt > deletedAt`인 레코드를 만들면 등록을 복원하고 tombstone을 제거한다. D1 CAS 충돌 시 서버 상태를 다시 읽고 병합한다.
- 진도 요청 본문은 UTF-8 기준 5 MiB 이하만 파싱한다. 선언된 길이와 실제 스트림 길이 모두 제한한다.

## 모델과 경계

- 사용자 2명, 같은 계정에서 동시 push를 하는 클라이언트 2대, 추적 레코드 4개로 축약했다.
- 상태에는 현재 로그인 사용자/세대, 열려 있는 로컬 상자 소유자와 준비 상태, 계정별 로컬·서버 레코드, 진행 중 GET, D1 버전/CAS push, tombstone을 둔다.
- `FixEnabled=TRUE`는 응답 세대 가드, 상자 소유자/세대 가드, CAS 재시도와 tombstone 병합을 나타낸다. `FALSE`는 이 가드를 제거한다.
- 정상 불변식: 로컬/서버 소유자 일치, 준비 완료 상자와 현재 계정 일치, tombstone 삭제 우선, CAS 재시도 이후 동시 레코드 보존, 타입 안전성.
- sanity 속성 `NoLocalDataReachable`은 데이터 동기화 성공 상태가 실제 도달하는지 검사하는 의도적 반례다.
- 유한 상태 탐색은 전체 구현 증명이 아니다. 운영 Cloudflare 환경, 실제 OAuth 발급·갱신·만료, 네트워크 단절·앱 강제 종료, 레코드 4개를 넘는 입력, 기기 시계 오차는 이 모델 범위 밖이다.

## 재실행

PowerShell에서 Git Bash를 통해 고정 proof-skills TLC를 실행한다.

```powershell
& 'C:\Program Files\Git\bin\bash.exe' -lc 'bash /c/Users/FREE/.codex/skills/tlaplus-model/scripts/tlc.sh /e/gisaclub/formal/user-progress-sync/UserProgressSync.tla --config MC.cfg --out /e/gisaclub/formal/user-progress-sync/evidence/normal -- -coverage 1'
& 'C:\Program Files\Git\bin\bash.exe' -lc 'bash /c/Users/FREE/.codex/skills/tlaplus-model/scripts/tlc.sh /e/gisaclub/formal/user-progress-sync/UserProgressSync.tla --config MC_bug.cfg --out /e/gisaclub/formal/user-progress-sync/evidence/bug'
& 'C:\Program Files\Git\bin\bash.exe' -lc 'bash /c/Users/FREE/.codex/skills/tlaplus-model/scripts/tlc.sh /e/gisaclub/formal/user-progress-sync/UserProgressSync.tla --config MC_sanity.cfg --out /e/gisaclub/formal/user-progress-sync/evidence/sanity'
```

The normal configuration must exit 0. The bug and sanity configurations must exit 12; those failures are expected and their counterexample JSON is retained beside each TLC log.

## 2026-10-29 result

- SANY parse/semantic check passed.
- Normal: 50,125 states generated, 15,118 distinct, depth 18; all listed invariants passed. TLC action coverage was recorded in `evidence/normal/tlc.log`.
- Bug toggle: expected `OwnerSafeLocal` violation, 447 generated / 327 distinct states, depth 8. The trace starts a GET for A, switches to B, then applies A's response to B's local namespace when the generation guard is disabled. See `evidence/bug/cex.json`.
- Sanity: expected `NoLocalDataReachable` violation, 1,176 generated / 582 distinct states, depth 9. The trace proves a successful A response can become local A progress. See `evidence/sanity/cex.json`.

## 2026-10-29 안전 컬렉션 동기화 후속 범위

- 추가 대상: SRS 카드 상태, 정수 milli-point 일별 점수, 슬라이드 진행도, 응시 등록/삭제.
- 정책: `wrongNotes`는 문제·정답·해설·개인 메모를 포함하므로 요청 snapshot에서도 만들지 않고 Worker allowlist에도 저장하지 않는다.
- 병합: SRS/점수/등록은 `updatedAt` 최신값, 동일 timestamp이면 정렬 JSON의 lexical 비교에서 큰 레코드를 선택한다. 슬라이드 `seen_*`는 정수 max, `lastDay`는 timestamp/정수 day, `level`은 timestamp/lexical level로 결정한다. 응시등록 삭제는 `{id: deletedAtMillis}` 버전 tombstone이며 오래된 기기 사본은 막고 명시적 재등록은 복원한다.
- `SafeCollections.tla`는 동시 학습/푸시 2개 클라이언트, 단일 페이지 카운터 0..2, 응시등록 1개, 삭제/재등록 버전 0..2에 대해 slide high-water, stale-delete, explicit-restore 속성을 검사한다. timestamp 동률 및 점수 표시 변환은 Dart/Worker 테스트와 정수 검증 스크립트로 별도 검사한다.
- 정수 단위: `scoreMilli = round(scorePoints × 1000)`, 허용 점수 0..100, 전송 범위 0..100000. 서버는 부동소수 점수를 받지 않으며 UI는 정수 / 1000으로 복원한다. nearest-milli 절대 오차는 실수 산술 가정에서 0.0005점 이하이며, binary64 계산 결과의 극단적 tie 경계는 모델 밖이다.
- 재실행:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' -lc 'bash /c/Users/FREE/.codex/skills/tlaplus-model/scripts/tlc.sh /e/gisaclub/formal/user-progress-sync/SafeCollections.tla --config MC_safe.cfg --out /e/gisaclub/formal/user-progress-sync/evidence/safe-collections/tlc-normal -- -coverage 1'
& 'C:\Program Files\Git\bin\bash.exe' -lc 'bash /c/Users/FREE/.codex/skills/tlaplus-model/scripts/tlc.sh /e/gisaclub/formal/user-progress-sync/SafeCollections.tla --config MC_safe_bug.cfg --out /e/gisaclub/formal/user-progress-sync/evidence/safe-collections/tlc-slide-bug'
& 'C:\Program Files\Git\bin\bash.exe' -lc 'bash /c/Users/FREE/.codex/skills/tlaplus-model/scripts/tlc.sh /e/gisaclub/formal/user-progress-sync/SafeCollections.tla --config MC_safe_tombstone_bug.cfg --out /e/gisaclub/formal/user-progress-sync/evidence/safe-collections/tlc-tombstone-bug'
& 'C:\Program Files\Git\bin\bash.exe' -lc 'bash /c/Users/FREE/.codex/skills/tlaplus-model/scripts/tlc.sh /e/gisaclub/formal/user-progress-sync/SafeCollections.tla --config MC_safe_sanity.cfg --out /e/gisaclub/formal/user-progress-sync/evidence/safe-collections/tlc-sanity'
& 'C:\Program Files\Git\bin\bash.exe' -lc 'bash /c/Users/FREE/.codex/skills/tlaplus-model/scripts/tlc.sh /e/gisaclub/formal/user-progress-sync/SafeCollections.tla --config MC_safe_restore_sanity.cfg --out /e/gisaclub/formal/user-progress-sync/evidence/safe-collections/tlc-restore-sanity'
python formal/user-progress-sync/verify_safe_progress_math.py
```

- 정상·결함 토글·reachability 결과는 후속 최종 검증 절에 기록한다. slide max와 tombstone mutation은 각각 대상 invariant만 검사하며, 별도 restore sanity는 신규 등록 버전이 서버까지 도달할 수 있는지 검사한다.
- 제한: 단일 계정·단일 대표 페이지·범위 카운터를 모델링한다. 전 원격 API·OAuth·D1 운영 연결·시계 신뢰·실제 두 기기 네트워크는 해당 모델이 증명하지 않는다. 테스트와 출력은 `evidence/safe-collections/`에 둔다.
