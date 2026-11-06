# Gisaclub 데이터 저장 정책 (SSOT · R58)

> 목적: "무엇을 서버가 최종 판정/보관(Single Source of Truth)하고, 무엇을 로컬에
> 캐시해도 되는가"를 코드·리뷰·배포 전 과정에서 흔들리지 않게 못박는다.

---

## 1. 대원칙

1. **서버(Cloudflare D1/KV)가 SSOT**인 데이터는 앱에 **판정 근거로 영속화하지 않는다.**
   - 로컬에 잔상이 남더라도, 앱은 그 값을 **신뢰하지 않는다.** 판정은 항상 서버 응답만.
2. **최소 권한 시작**: 앱은 항상 가장 낮은 권한(무료·비관리자)으로 시작하고,
   **서버 응답이 확인(server-confirmed)된 경우에만** 권한을 상향한다.
3. **오프라인/서버다운 = 안전 기본값**: 서버를 확인할 수 없으면 무료·비관리자로 동작.

---

## 2. 데이터 분류표

| 데이터 | SSOT | 로컬 저장 | 로컬을 판정 근거로? | 담당 코드 |
|---|---|---|---|---|
| 계정 정보(이메일/식별자) | **서버** | 표시용 캐시만 | ❌ | AdminService(표시용 email), 서버 users |
| 사용자 권한(관리자 여부) | **서버** | ❌ (세션 UX 게이트만) | ❌ | AdminService (`/v1/admin/verify`) |
| 요금제/구독 상태 | **서버** | ❌ (영속화 안 함) | ❌ | EntitlementService (`refreshFromServer`) |
| 문제별 진도·공부세션·CBT 결과 | **서버 동기화 범위** | ✅ 계정별 오프라인 write-through | ❌ | ProgressSnapshotStore + **ProgressSyncService** |
| SRS 카드 상태·일별 점수 이력·슬라이드 진도·응시 등록 | **최소 필드만 서버 동기화** | ✅ 계정별 Hive write-through | ❌ | ProgressSnapshotStore + feature services |
| 오답노트(문제·정답·해설·개인 메모) | **원격 동기화 금지** | ✅ 계정별 암호화 Hive/백업 | ❌ | AppProvider + SecureBoxService |
| 관리자 권한 판정 | **서버** | ❌ | ❌ | Worker `requireAdmin` (Access JWT/앱토큰) |
| 문제 데이터·학습 콘텐츠 | 서버/자산 | ✅ **캐시 허용(핵심)** | 판정 아님 | RemoteContentApi, assets, StudyData |
| 이미지/오디오 리소스 | 서버/자산 | ✅ 캐시 허용 | 판정 아님 | assets, RemoteContentApi |
| 앱 설정(테마/알림) | 로컬 | ✅ 로컬 소유 | — | AppProvider settings |

---

## 3. 권한·구독·관리자 — "로컬 판정 금지"를 어떻게 지켰나

### 3-1. 구독/요금제 (EntitlementService, R58)
- 앱 시작 시 **무조건 `free`** 로 시작한다(`init()`).
- 과거 로컬에 저장돼 있던 요금제 캐시 키(`ent_plan_tier`, `ent_expiry_iso`)는
  시작 시 **삭제(purge)** 한다 — 로컬 잔상으로 유료가 열리는 일을 원천 차단.
- `refreshFromServer()` 가 서버(`/v1/billing/verify` 등) 응답을 받았을 때만
  메모리에서 요금제를 상향하고 `_serverConfirmed=true` 로 표시한다.
- **로컬에 요금제를 영속화하지 않는다.** 재실행하면 다시 무료→서버확인 순.

### 3-2. 관리자 (AdminService, R57)
- 앱 안에 이메일·PIN·비교 로직 **없음**. Cloudflare Access가 대시보드 앞단에서
  Google 로그인을 걸고, 지정 이메일만 통과 → Worker가 앱 토큰(HMAC) 발급.
- 앱은 토큰을 `/v1/admin/verify` 로 **서버 재검증**받아야만 관리자 UX가 열린다.
- 저장된 세션은 "본인 기기의 UX 게이트"일 뿐, 서버가 토큰을 폐기하면 즉시 해제.

---

## 4. 학습 진도·점수 — 오프라인 우선 + 계정 분리 동기화

### 왜 로컬에 두는가 (정직한 트레이드오프)
이 앱의 **핵심 가치가 "오프라인 학습(지하철·비행기·시험장 근처)"** 이다. 진도/점수를
서버 전용으로 즉시 옮기면 (1) 서버 미배포 상태에서 앱이 동작 불능, (2) 오프라인에서
문제풀이·오답노트·간격반복이 전부 막힌다. 따라서 진도/점수는:

- **로컬을 write-through 저장소**로 사용한다(문제 풀이를 즉시 기록해 오프라인에서도 이어서 학습).
- 게스트는 기존 Hive 이름을 유지한다. 로그인 계정은 사용자 ID의 SHA-256 namespace를 사용해
  `exams`, `sessions`, `wrongNotes`, `settings`, `quizResults`, `questionProgress`,
  `flashcardSrs`, `scoreHistory`, `slideProgress`, `exam_registrations`를 분리한다.
- 과거 게스트 기록을 첫 로그인 계정으로 자동 복사하지 않는다. 백업은 현재 namespace만
  내보내고 계정 fingerprint가 다른 백업은 복원 전에 거부한다.
- `ProgressSyncService`는 사용자 세션 bearer token으로 동기화한다. Worker는 인증 세션에서
  소유자를 정하며 질문 본문·정답·해설·오답노트·개인 메모는 스냅샷 allowlist에서 제외한다.
  동기화 대상은 `questionProgress`, `sessions`, `quizResults`, `flashcards`, `scores`,
  `slides`, `registrations`다. sessions 전송 필드는 `id/examId/date/minutes/updatedAt`만,
  quiz 결과는 시험 제목·문항 수·정답 수·과목별 집계만 보낸다.
- SRS는 카드 식별자와 간격/횟수만 보낸다. 점수는 `scoreMilli` 정수로 전송하며 단위는
  0.001점, 허용 범위는 0..100000 (0..100점)이다. 로컬 표시값은 `scoreMilli / 1000`이다.
  이 수치는 성적 추이 표시만을 위한 것이며 요금제·합격 권한 판정에 사용하지 않는다.
- 슬라이드 `seen_*` 페이지 수는 `max(local, remote)`로 병합해 완료량이 줄지 않게 한다.
  `lastDay`와 `level`은 timestamp를 비교하고 timestamp 동률은 각각 큰 day/문자열을 택해
  기기 처리 순서와 무관한 tie-break를 둔다. 등록/응시 삭제는 `{id: deletedAtMillis}` 형식의
  `registrations` tombstone으로 동기화한다. `updatedAt <= deletedAt`인 오래된 기기 사본은
  삭제 상태를 유지하고, 같은 시험을 명시적으로 다시 저장해 `updatedAt > deletedAt`가 되면
  등록을 복원하며 병합된 tombstone을 제거한다. 이전 목록형 tombstone은 읽을 때 현재 로컬
  시각으로 한 번 변환한다.
- 서버 레코드는 `updatedAt` 병합과 D1 compare-and-swap 재시도를 사용한다. 세션·CBT 결과
  삭제는 tombstone으로 동기화한다. 문제별 진도는 시각이 더 최신인 레코드를 선택하므로
  기기 시계 오차를 보정하지 않는다. 동기화 레코드의 timestamp가 같으면 정렬한 JSON 값의
  문자열 순서로 양쪽 구현이 같은 레코드를 선택한다. 이 규칙은 동률 결과를 결정적으로
  만들지만 실제 수정 시각을 복원하거나 기기 시계 오차를 보정하지 않는다.
- **중요**: 진도/점수는 "권한·구독·관리자 판정"과 **무관**하다. 즉 로컬 진도를 보고
  유료 기능을 열거나 관리자로 승격하는 일은 **절대 없다**(그 판정은 §3에서 서버 전담).

### 동기화 규약 (ProgressSyncService)
```
로컬 기록(즉시)  ──push──▶  서버 progress 저장(사용자별)
              ◀──pull───   서버가 최신 → 로컬 병합(서버 우선)
```
- 서버 미설정(`AppConfig.hasApi == false`)이면 동기화는 **no-op**, 로컬만으로 동작.
- 서버 배포 후 `API_BASE_URL` 이 주입되면 자동으로 동기화가 활성화된다(코드 수정 불필요).
- 엔드포인트 계약(Worker 코드 구현, 운영 배포·E2E 미검증):
  - `GET  /v1/progress` — 현재 검증 세션의 진도 스냅샷 조회(pull)
  - `POST /v1/progress` — 세션 소유자 행에 스냅샷 병합(push), 요청 본문에서 소유자를 받지 않음

> 현재 상태(2026-10-29): 로컬 구현과 Worker 계약 회귀 테스트는 완료했다. API URL/세션이
> 없으면 동기화는 no-op이고 로컬 학습을 유지한다. `wrongNotes`는 원문 보호를 위해 계속
> 미동기화한다. Worker/D1 원격 migration·배포, OAuth 세션 전체 수명주기, 운영 E2E는
> 실행하지 않았으므로 서버 백업 사용 가능으로 홍보하지 않는다.

---

## 5. 리뷰 체크리스트 (PR마다 확인)
- [ ] 요금제/구독을 로컬에 **영속화**하지 않았는가?
- [ ] 관리자 여부를 로컬 값만으로 판단하지 않았는가? (서버 verify 필수)
- [ ] 새 기능이 유료/관리자 게이트를 **로컬 캐시**로 열지 않는가?
- [ ] 진도/점수 캐시를 권한 판정에 전용(轉用)하지 않았는가?
- [ ] 서버 미설정 시 안전 기본값(무료·비관리자·no-op sync)으로 동작하는가?
