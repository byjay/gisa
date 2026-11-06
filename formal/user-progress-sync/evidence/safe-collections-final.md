# 2026-10-29 안전 컬렉션 동기화 최종 검증

## 범위

기존 사용자별 진도 API에 SRS 카드 상태, 점수 이력, 슬라이드 진도, 응시 등록을 추가했다. 원격 payload는 계정 bearer session의 검증된 사용자 row에만 저장한다. 문제 본문·정답·해설·오답노트 메모 원문은 이 snapshot에 포함하지 않는다. 계정별 학습 진행 메타데이터는 서버에 저장된다.

응시등록 삭제는 `{id: deletedAtMillis}` tombstone이다. `updatedAt <= deletedAt`인 stale 기기 사본은 삭제를 유지한다. 같은 회차를 사용자가 다시 저장하면 저장 시각을 최소 `deletedAt + 1`로 만들고, 병합 결과에서 tombstone을 제거한다. 예전 목록형 tombstone은 읽을 때 현재 로컬 시각을 timestamp map으로 변환한다. 기기 시계가 잘못 설정된 경우 최신순 판정은 절대적이지 않다.

## 최종 실행 결과

| 확인 | 결과 | 증거 |
|---|---|---|
| Flutter 전체 회귀 | PASS 106/106 | `safe-collections/flutter-full-final.log` |
| 계정·snapshot·삭제/재등록 회귀 | PASS 12/12 | `safe-collections/registration-restore-flutter-green.log`, 전체 실행은 위 전체 로그 |
| Cloudflare Worker 전체 회귀 | PASS 40/40 | `safe-collections/worker-full-final.log` |
| Worker progress 회귀 | PASS 11/11 | `safe-collections/registration-restore-worker-green.log` |
| 전체 앱 분석 | `dart analyze lib`: No issues found | `safe-collections/dart-analyze-lib-final.log` |
| 변경 파일 분석 | No issues found | `safe-collections/dart-analyze-changed-final.log` |
| Dart format | 6개 파일, 0 changed | `safe-collections/dart-format-final.log` |
| Worker bundle | `wrangler deploy --dry-run` PASS, 83.55 KiB / gzip 20.44 KiB | `safe-collections/wrangler-dry-run-final.log` |
| 수학 경계 | PASS: 101³ slide max 조합, score milli 100,001 값, 오차 0.0005점 이하, 삭제/재등록 strict boundary | `safe-collections/math-final.log` |

## TLA+ 모델

- 사양: `SafeCollections.tla`; 유한 범위는 두 클라이언트, 단일 대표 페이지 카운터 `0..2`, 응시등록 1개, 등록 버전 `0..2`다.
- 정상 탐색: 729 states generated / 132 distinct / depth 11, invariant violation 없음. `Learn`, `MergeProgress`, `DeleteRegistration`, `RestoreRegistration`, `PushRegistration`이 모두 coverage에 나타났다. SANY 통과.
- Slide mutation: `MC_safe_bug.cfg`에서 `SlideProgressNeverRegresses`가 의도적으로 위반됨 (323 generated / 119 distinct / depth 8).
- Tombstone mutation: `MC_safe_tombstone_bug.cfg`에서 `RegistrationTombstoneWins`가 의도적으로 위반됨 (228 / 89 / depth 7).
- Progress reachability sanity: `MC_safe_sanity.cfg`에서 `NoProgressReached` 반례 (26 / 18 / depth 6).
- Restore reachability sanity: `MC_safe_restore_sanity.cfg`에서 `NoRegistrationRestoreReached` 반례 (304 / 81 / depth 9).
- 현재 실행 로그는 `safe-collections/tlc-final-v3-*/` 아래에 있다. 모델은 시계 오차, 실제 OAuth/Cloudflare/D1, 실기기 네트워크, 전체 레코드 수를 증명하지 않는다. 상세 대응은 `../CORRESPONDENCE.md`.

## 운영 게이트 상태

Wrangler는 dry-run만 했다. 출력에 `GOOGLE_OAUTH_CLIENT_ID`, `ACCESS_TEAM_DOMAIN`, `ACCESS_AUD`용 `REPLACE_WITH_...` placeholder가 남아 있다. 원격 D1 migration, Worker 배포, 두 기기 API 동기화, OAuth refresh/expiry, 전체 endpoint 운영 E2E, APK/Play 검증은 수행하지 않았다. 따라서 이 기록은 로컬 구현 검증이며 출시/배포 봉인이 아니다.
