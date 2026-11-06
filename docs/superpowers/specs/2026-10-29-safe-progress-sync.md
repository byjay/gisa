# 안전한 학습기록 동기화 설계

**일자:** 2026-10-29
**대상:** `E:\gisaclub`
**관련 코드:** `lib/services/progress_snapshot_store.dart`, `lib/services/progress_sync_service.dart`, `backend/cloudflare/src/progress.js`

## 목표

로그인 사용자의 SRS 복습 상태, 일별 점수 추이, 슬라이드 진행도, 자격증 응시 계획/결과를 기존 사용자별 progress API에 동기화한다. 로컬 학습은 오프라인에서도 계속되어야 하며 계정 namespace는 기존 규칙을 유지한다.

## 경계

- 동기화 허용: `flashcardSrs`, `scoreHistory`, `slideProgress`, `exam_registrations`의 최소 상태 필드.
- 동기화 금지: `wrongNotes`의 문제 본문, 정답, 해설, 사용자 메모. 이 박스는 계속 계정별 로컬 저장/백업만 허용한다.
- 동기화 금지: 시험 원문, 카탈로그·교재 데이터, 인증/관리자/구독 권한.
- Worker는 클라이언트가 보낸 소유자 대신 인증 세션의 사용자 ID로 행을 선택한다.
- 서버가 미설정되거나 통신이 실패하면 로컬 기록을 보존한다.

## 계약

- `flashcards`: `{id, box, seen, known, nextDue?, updatedAt}`. `id`는 카드 키이며 문제 본문이 아니다. 레코드 전체는 `updatedAt` 최신값 병합; 같은 시각이면 정렬된 JSON 문자열 순서가 더 큰 레코드를 고른다.
- `scores`: `{id, scoreMilli, attempts, updatedAt}`. `id`는 `YYYY-MM-DD`, `scoreMilli` 단위는 점수의 1/1000점, 유효 범위는 0..100000 (0..100점), `attempts`는 정수 횟수다. 기존 `double score`는 전송 전에 `round(score * 1000)`으로 양자화하고 수신 시 `scoreMilli / 1000`으로 복원한다.
- `slides`: 키별 수치 진도는 `max(local, remote)`로 병합해 늦은 기기 응답으로 본 페이지 수를 줄이지 않는다. `lastDay`와 난이도 `level`은 해당 값의 timestamp가 더 최신인 레코드를 선택한다. 난이도는 `baby|standard|fast`만 허용한다.
- `registrations`: 응시 식별자, 종목/회차/단계/상태, 사용자 점수만 허용하며 `updatedAt`으로 병합하고 동률은 정렬 JSON 문자열 순서로 결정한다. `deleted.registrations`는 `{id: deletedAtMillis}` 맵이다. `updatedAt <= deletedAt`인 오래된 사본은 삭제를 유지하고, 명시적 재등록이 더 큰 시각으로 저장되면 레코드를 복원하고 tombstone을 제거한다.
- 서버 스키마는 Worker `normalizeSnapshot` allowlist에서 강제하며 허용되지 않은 필드는 저장 전 제거한다. 원문 필드를 거부/제거하는 회귀 테스트를 둔다.
- 기존 `GET /v1/progress`, `POST /v1/progress`를 유지한다. D1 테이블 형식 변경은 필요하지 않다.

## 병합 속성

1. 계정 A의 응답/기록이 계정 B의 box에 쓰이지 않는다.
2. 삭제 시각과 같거나 오래된 응시 등록 사본은 부활하지 않는다. 새 저장은 삭제 시각보다 큰 `updatedAt`을 가지며 정상 복원된다.
3. 슬라이드 완료 수의 `max` 병합은 교환·결합·멱등이며, 이미 본 페이지 수를 감소시키지 않는다.
4. 점수 직렬화는 0..100 점에서 0.001점 단위로 반올림하며 최대 절대 양자화 오차는 0.0005점이다. 이 값은 표시/추이 데이터 전용이고 자격 판정·결제 권한에는 쓰지 않는다.
5. 서버 payload는 유한 크기와 레코드 개수 제한을 지키고 문자열 원문/알 수 없는 필드는 보존하지 않는다.

## 제외/한계

- `wrongNotes`는 문제/정답/메모 원문을 포함하므로 이 구현의 스냅샷에서 영구 제외한다.
- 로컬 기기 간 시계가 잘못 설정된 경우 timestamp 기반 레코드의 최신순 판정은 절대적인 시간순을 보장하지 않는다.
- 이전 목록형 응시등록 tombstone은 현재 기기 시각으로 맵에 한 번 변환한다. 신뢰할 수 없는 미래 시계의 오프라인 기기는 재등록 우선순위를 지연시킬 수 있다.
- 운영 배포, D1 변경, OAuth 환경설정, 실기기/다중 사용자 운영 E2E는 이 로컬 변경 범위가 아니다.
