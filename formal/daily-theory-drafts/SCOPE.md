# 범위: 하루 초안 슬롯 점유와 검토 공개 경계

## 확인할 문제

두 Worker 실행이 같은 날짜/슬롯을 동시에 생성하거나, 오래 지연된 생성 응답이 새로 점유한 결과를 덮거나, 초안이 검토 전에 공개되는 상태 전이.

## 코드 근거

- `backend/cloudflare/src/blog-drafts.js`: `claimSlot`은 `(slot_date, slot)` 고유키 삽입과 D1 `meta.changes`로 단일 소유자를 선택한다.
- `backend/cloudflare/src/blog-drafts.js`: 오래된 `generating` 행은 15분 임계값을 넘을 때 토큰을 재발급하고 `finishClaim`은 현재 토큰만 허용한다.
- `backend/cloudflare/src/blog-drafts.js`: 성공 상태는 `review`이며 검토 API는 `approved`/`rejected`만 기록한다.
- `backend/cloudflare/src/index.js`: 게시 라우트가 없으며 `published` 필드나 공개 초안 API를 추가하지 않았다.

## 가정 및 제외

- 모델은 2개 Worker와 한 날짜의 3개 슬롯만 탐색한다.
- D1의 단일 INSERT/UPDATE가 원자적이며 `meta.changes`가 실제 변경 행 수를 나타낸다고 가정한다.
- 네트워크와 AI 응답은 비결정적이지만 `Complete`/`Fail`로 추상화한다.
- 사용자 인증·자격증 원문·AI 내용 품질·D1 장애 복구 전체는 이 모델 범위가 아니다.
- 15분보다 오래 걸리는 호출은 재점유를 허용한다. 완료 token fencing으로 오래된 결과의 기록을 차단한다.
- `NoPublicPost`는 자동 발행 금지를 뜻하며, 관리자가 외부 서비스에 수동 복사/게시하는 동작은 모델 밖이다.
