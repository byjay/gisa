# 모델 ↔ 코드 대응

| 모델 요소 | 소스 대응 | 추상화 |
|---|---|---|
| `Claim(w,s)` | `backend/cloudflare/src/blog-drafts.js` `claimSlot()`의 `INSERT OR IGNORE` 및 `meta.changes` 분기 | D1의 `(slot_date, slot)` UNIQUE와 INSERT를 한 원자 단계로 표현 |
| `Expire(s)` | `claimSlot()`의 `updated_at <= staleBefore` 조건이 참이 되는 시간 경과 | 시계 대신 만료 boolean으로 추상화 |
| `Reclaim(w,s)` | `claimSlot()`의 조건부 UPDATE와 `generation_token` 교체 | 소유 Worker를 새 token으로 fencing |
| `Complete(w,s)` | `finishClaim()`의 `WHERE status='generating' AND generation_token=?` UPDATE | 기존 owner token 일치 시 review 전이 |
| `Fail(w,s)` | `failClaim()`의 동일 token 조건부 `failed` UPDATE | 실패 행은 비공개 유지 |
| `Review(s,d)` | `reviewBlogDraft()`의 `review` 상태 검사와 조건부 승인/반려 UPDATE | 관리자 인증 자체는 모델 밖 |
| `PublishBug(s)` | 의도적으로 구현하지 않은 공개 게시 전이 | 유일 반례 실험에만 포함; 실제 라우트 없음 |

행 번호는 검증 산출물 `docs/verification/daily-theory-drafts.md`에 최종 소스 기준으로 기록한다.
