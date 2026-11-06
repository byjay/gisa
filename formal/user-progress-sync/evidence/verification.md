# 사용자 진도 격리·동기화 검증 기록 (2026-10-29)

## 결과

| 검증 | 재현 명령/범위 | 결과 |
|---|---|---|
| Flutter 전체 회귀 | `flutter test --no-pub --reporter compact` (`E:\gisaclub`) | PASS, 100/100. 출력: `flutter-full-suite.log` |
| Flutter 경계 회귀 | `flutter test --no-pub --reporter compact test/user_data_scope_test.dart test/progress_sync_service_test.dart test/backup_service_test.dart` | PASS, 15/15 |
| Worker 전체 회귀 | `node --test` (`E:\gisaclub\backend\cloudflare`) | PASS, 35/35. 출력: `worker-suite.log` |
| Dart 전체 앱 분석 | `dart analyze lib` | PASS, `No issues found!`. 출력: `dart-analyze-lib.log` |
| Dart 변경 범위 분석 | `dart analyze`에 계정 scope/provider/progress/backup 구현 파일 6개와 회귀 파일 3개 지정 | PASS, `No issues found!` |
| Dart 전체 형식 | `dart format --output=none --set-exit-if-changed`에 수정 관련 9개 파일 지정 | PASS, `0 changed` |
| Wrangler 번들 검증 | `npx wrangler deploy --dry-run` (`backend/cloudflare`) | PASS, Worker bundle 75.12 KiB (gzip 18.42 KiB). 출력: `wrangler-dry-run.log` |
| TLA+ 정상 모델 | `SCOPE.md`의 고정 TLC 명령 | PASS, 50,125 generated / 15,118 distinct / depth 18 |
| 결함 토글 | `MC_bug.cfg`, `FixEnabled=FALSE` | 예상 invariant 위반 exit 12: 늦은 A 응답이 B namespace로 기록되는 반례 |
| 도달성 sanity | `MC_sanity.cfg` | 예상 invariant 위반 exit 12: 실제 학습 진도가 local에 도달함을 확인 |

`flutter analyze --no-pub` wrapper는 `Analyzing gisaclub...`에서 유휴 대기해 결과를 내지 않았다. 직접 실행한 `dart analyze lib` 전체 앱 분석은 PASS다. 변경 관련 테스트 3개 파일 분석도 따로 PASS이며, Flutter 전체 테스트가 전체 test suite 실행/컴파일을 통과했다. Flutter wrapper의 유휴 상태만 미해결로 기록한다.

## 분석 요약

- Guest는 기존 Hive box 이름을 유지한다. 인증 사용자 box 이름은 trim된 서버 user ID의 SHA-256 namespace이며, 계정 간 자동 데이터 복사는 하지 않는다.
- GET/POST는 AuthService 사용자 세션 bearer token을 사용한다. Worker D1 owner는 검증된 `session.userId`이며, 요청 body owner를 신뢰하지 않는다.
- 원격 전송은 `questionProgress`, `sessions`, `quizResults`로 제한된다. 문제 원문/정답/해설은 allowlist에서 제외한다. 나머지 학습 기록은 사용자별 로컬 저장만 된다.
- 백업 export는 현재 box namespace만 내보내며, 다른 계정 fingerprint의 import는 저장 전 거부한다.
- Worker 요청 body는 선언 Content-Length 및 실제 스트림 각각 UTF-8 5 MiB 상한을 검사한다. 정확한 경계 수용과 경계 초과 거부 테스트 포함.
- D1 compare-and-swap은 충돌 시 최신 snapshot을 다시 읽어 5회까지 merge 재시도한다. 세션/CBT 삭제 tombstone은 stale-device resurrection을 방지한다.
- TLC 모델은 사용자 2명·기기 2대·기록 4개를 탐색했다. 실제 OAuth/refresh/expiry, 원격 D1/Worker, 네트워크 단절, 시계 오차, 추적 레코드 4개 초과 동작은 모델 범위 밖이다.

## 출시/운영 미통과

- Wrangler dry-run이 성공해도 배포/운영 환경 검증은 아니다. 출력에 `GOOGLE_OAUTH_CLIENT_ID`, `ACCESS_TEAM_DOMAIN`, `ACCESS_AUD`의 `REPLACE_WITH_...` 값이 남아 있다.
- 원격 D1 migration, Worker 배포, 로그인/토큰 refresh·만료 E2E, API endpoint 전체 운영 E2E를 수행하지 않았다.
- `flutter analyze --no-pub` wrapper는 아직 완료되지 않았지만 `dart analyze lib` 전체 앱은 통과했다. Worker dry-run은 bundling만 검증한다.
- 앱 APK를 다시 빌드하거나 Cloudflare/Kakao 설정·로그인·권한·배포·외부 공개를 변경하지 않았다.

## 안전 컬렉션 및 응시등록 재등록 복원 최종 검증 (2026-10-29)

이 섹션은 기존 상태 기록을 대체하지 않고, snapshot에 네 종류 컬렉션을 추가한 최신 소스 결과다. 삭제 후 같은 회차 재등록을 영구 tombstone이 막던 역방향 재검토 버그도 수정했다.

| 검증 | 재현 명령/범위 | 최종 결과 |
|---|---|---|
| Flutter 전체 | `flutter test --no-pub --reporter compact` | PASS 106/106; `safe-collections/flutter-full-final.log` |
| Flutter 계정/동기화 | `flutter test --no-pub test/user_data_scope_test.dart` | PASS 12/12; 등록 삭제→재등록 포함 |
| Worker 전체 | `node --test` (`backend/cloudflare`) | PASS 40/40; `safe-collections/worker-full-final.log` |
| Worker progress | `node --test tests/progress.test.js` | PASS 11/11; stale 삭제 거부·신규 재등록 복원 |
| Dart 분석 | `dart analyze lib`, 수정 구현+회귀 테스트 지정 analyze | 둘 다 `No issues found!` |
| Dart 형식 | 수정 관련 6개 Dart 파일 | PASS, 0 changed |
| Wrangler | `npx wrangler deploy --dry-run` | PASS, 83.55 KiB / gzip 20.44 KiB. dry-run만 실행 |
| 정수 경계 검사 | 수학 검증 스크립트 | PASS: 101³ slide max triples, score milli 100,001 values, 최대 양자화 오차 0.0005점, tombstone strict boundary |
| TLA+ 정상 | `SafeCollections.tla`, 2 clients, slide/version 0..2, coverage 1 | PASS: 729 generated / 132 distinct / depth 11 |
| TLA+ 결함/도달성 | slide mutation, tombstone mutation, progress sanity, restore sanity | 각각 의도된 `SlideProgressNeverRegresses`, `RegistrationTombstoneWins`, `NoProgressReached`, `NoRegistrationRestoreReached` counterexample |

재등록 RED/GREEN 로그와 TLC 출력은 `formal/user-progress-sync/evidence/safe-collections/`; 요약은 `safe-collections-final.md`; JSON finding과 독립 HTML report는 `formal/findings.json`, `formal/reports/2026-10-29-safe-progress-sync.html`이다. Wrangler 로그에서는 관리자 이메일만 `[redacted admin email]`로 가렸다.

## 운영 게이트 미통과

Worker dry-run 결과에는 Google OAuth 및 Cloudflare Access의 `REPLACE_WITH_...` placeholder가 있다. 원격 D1 migration/Worker 배포, 인증 API 전체 E2E, 두 실기기 sync, OAuth refresh/expiry, APK/Play 검증은 수행하지 않았다. 이것은 bounded model 및 로컬 소스 검증이지 운영 상태 보증이나 배포 봉인이 아니다. Cloudflare/Kakao 콘솔과 외부 공개 상태는 변경하지 않았다.
