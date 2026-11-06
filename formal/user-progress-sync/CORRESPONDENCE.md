# 모델 ↔ 코드 대응표

| 모델 액션/속성 | 실제 코드 | 대응 |
|---|---|---|
| `SwitchUser` | `lib/providers/app_provider.dart:124-151` `activateUser`; `lib/services/auth_service.dart:87-96` | 사용자 namespace 변경, sync 세대 무효화, 화면 값 제거, box 준비 완료 후 auth UI 통지. |
| `CompleteOpen` | `lib/providers/app_provider.dart:194-215` `_openScopedBoxes`; `lib/services/exam_registration.dart:134-145` `init` | box 이름과 generation을 먼저 캡처하고 최신 generation일 때만 참조를 바꾼다. |
| `StartRead` | `lib/services/progress_sync_service.dart:88-111` `syncNow` | 소유자·generation·사용자 bearer token을 요청 시작 때 캡처한다. |
| `DeliverRead` | `lib/services/progress_sync_service.dart:113-145`, `:172-175`; `lib/services/progress_snapshot_store.dart:54-75` | 응답 전후 소유자/token/generation을 확인한다. 병합은 box 이름과 generation을 await 전에 캡처하고 다른 계정으로 전환됐으면 쓰기 전에 중단한다. |
| `OwnerSafeLocal` | `lib/services/user_data_scope.dart:20-33`; `lib/services/progress_snapshot_store.dart:15-38,54-75` | 해시 namespace가 사용자 ID에 결정적으로 대응하고 스냅샷은 해당 namespace만 연다. |
| `BoxOwnerMatchesWhenReady` | `lib/providers/app_provider.dart:84,89-151,194-215` | 계정 전환 때 scope를 닫고 화면 값을 비운 뒤 최신 계정 box만 활성화한다. |
| `BeginPush` | `backend/cloudflare/src/index.js:268-279` | `requireSession`에서 얻은 `session.userId`만 `putProgress`에 넘긴다. 요청 본문에서 userId를 받지 않는다. |
| `CommitPush` / `RetryPush` | `backend/cloudflare/src/progress.js:31-65` | D1 `updated_at` CAS와 충돌 시 최신 스냅샷 재조회·병합을 수행한다. |
| `TombstonesWin` | `backend/cloudflare/src/progress.js:68-94`; `lib/services/progress_snapshot_store.dart:42-52,77-95` | 삭제 집합에 있는 세션/CBT 행은 오래된 기기 업로드로 부활하지 않는다. |
| `Learn` / `MergeProgress` / `SlideProgressNeverRegresses` | `lib/services/slide_progress.dart` `markSeen`; `lib/services/progress_snapshot_store.dart` `_mergeSlides`; `backend/cloudflare/src/progress.js` `mergeSlides` | 페이지 수는 local write에서 증가하고 양쪽 snapshot은 `max` 병합한다. 모델은 대표 key 1개, 0..2 값으로 제한한다. |
| `DeleteRegistration` / `RestoreRegistration` / `PushRegistration` / `RegistrationTombstoneWins` | `lib/services/exam_registration.dart:168-200`; `lib/services/progress_snapshot_store.dart:95-147,149-273,429-490`; `backend/cloudflare/src/progress.js:69-100,251-285,378-401` | 삭제 시각을 tombstone map에 저장한다. 오래된 버전은 삭제하고 `updatedAt > deletedAt`인 재등록만 tombstone을 지워 복원한다. 동일/이전 버전 재생성은 Node·Flutter 회귀에서 확인했다. |
| `ReadBodyLimit` | `backend/cloudflare/src/index.js:271-279,306-339` | Content-Length 사전 검사와 실제 reader 스트림 누적 바이트 검사를 각각 적용한다. |
| Backup owner | `lib/services/backup_service.dart:59-88,91-127,202-216` | 현재 namespace만 내보내며 fingerprint가 다른 계정/게스트 백업은 restore 전에 거부한다. |

## 재현 코드 증거

- Flutter namespace·계정 전환·로컬 병합: `test/user_data_scope_test.dart`.
- 로그인 세션 bearer token, 계정 전환 뒤 지연 응답 폐기, in-flight push 뒤 새 로컬 변경 재전송: `test/progress_sync_service_test.dart`.
- export/import 계정 fingerprint 경계: `test/backup_service_test.dart`.
- Worker 사용자별 API 행, 요청 크기, tombstone, payload allowlist, D1 경쟁 CAS: `backend/cloudflare/tests/progress-route.test.js`, `progress.test.js`.
- endpoint 인증 회귀: `backend/cloudflare/tests/study-data-security.test.js`.

## A~E 검토 상태 (2026-10-29)

- A 작성: 구현을 위해 저장소 소유권 경계와 실제 로그인/저장/Worker 호출선을 읽고 새 계정 namespace, 서버 세션 토큰, CAS/tombstone 경계를 반영했다.
- B 반박: A→B→A 사용자 전환, 시작 뒤 계정 변경된 GET, 동기화 중 로컬 쓰기, 교차 계정 백업 복원, 응답 본문 크기 경계, CAS 동시 쓰기를 회귀 테스트로 반증 시도했다. 과거 스냅샷 적용 반례를 RED로 확인 후 generation guard로 해결했다.
- C 판정: 계정 namespace 및 generation 가드가 로컬상태 변경 전에 적용되고 Worker 소유자는 검증 세션에서만 온다. 학습 데이터 원문은 payload allowlist와 별도 콘텐츠 경로에 남는다.
- D 역추적: 로그인 프로필/세션 → AuthService owner change callback → AppProvider box names → snapshot GET/merge → POST → Worker verified `session.userId` → D1 row까지 흐름을 대응표/라인번호에 연결했다. 로컬 backup import도 현재 namespace fingerprint를 검사한다.
- E 서명(초기 동기화): 로컬 검사 결과와 한계는 `evidence/verification.md`에 기록한다. OAuth·D1 migration·Worker 배포와 E2E는 검증 범위 밖이다.
- E 서명(safe collections): `wrongNotes` 원문이 snapshot에 없다는 테스트, client/server allowlist 검증, account-scoped SRS/score/registration tests, slide max/registration tombstone 모델, 정수 milli-point 검사를 수행했다. 최종 수치와 운영 미검증 항목은 `evidence/safe-collections-final.md` 및 `evidence/verification.md`에 기록했다. 원격 설정 placeholder가 남아 운영 게이트는 미통과다.

## A~E 반대 관점 후속 루프 (응시 재등록 복원)

- A 작성: 기존 tombstone이 id 집합이라 삭제 뒤 같은 회차를 다시 저장해도 삭제가 영구 우선되는 경로를 실제 `makeId`의 안정적인 식별자와 `save/delete` 호출 순서로 확인했다.
- B 반박: Worker `mergeSnapshots`와 실제 Hive 저장소에 대해 삭제 후 동일 id 재저장 회귀를 추가했다. Worker는 tombstone 타입에서 거부, Flutter는 목록 tombstone 인덱싱에서 실패해 수정 전 RED가 예상된 원인으로 발생했다.
- C 판정: `deleted.registrations`를 `{id: deletedAtMillis}`로 바꾸고 신규 저장 timestamp를 최소 `deletedAt + 1`로 잡는다. 병합은 `updatedAt <= deletedAt`를 거부하고 그보다 큰 새 버전만 살리며 해당 tombstone을 제거한다. 세션/CBT의 기존 영구 삭제 tombstone은 그대로 둔다.
- D 역추적: `ExamRegistrationStore.save/delete` → 계정별 `progressSyncMeta` → snapshot `read/mergeRemote` → Worker normalize/merge → D1 compare-and-swap row까지 입력과 반환을 다시 추적했다. `wrongNotes`는 이 경로에 들어오지 않는다.
- E 서명: Worker progress tests 11/11, Flutter scope tests 12/12, 전체 Worker 40/40, 전체 Flutter 106/106, `dart analyze lib`와 변경 파일 분석 모두 `No issues found`, 포맷 6개 파일/0 changed, Worker dry-run 및 정수 경계 검산을 확인했다. TLC 정상 729 generated / 132 distinct / depth 11; 각 단일 결함 토글과 2개 도달성 sanity가 예상한 invariant 반례를 냈다. 전체 증거는 `evidence/safe-collections-final.md` 및 `evidence/safe-collections/`에 보관한다. 이 모델은 bounded model이며 기기 시계 오차·실 Cloudflare·원격 E2E는 확인하지 않는다.
