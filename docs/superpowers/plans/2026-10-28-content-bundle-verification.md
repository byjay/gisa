# GISACLUB 서버 콘텐츠 번들 검증 구현 계획

> **For agentic workers:** 실행은 단일 작업자가 수행한다. 체크 항목으로 진행을 기록한다.

**Goal:** D1/R2 업로드 전에 현재 GISACLUB 학습 원본과 생성 번들의 일치 및 정답·해설 분리를 확인한다.

**Architecture:** 기존 Python 변환기는 유지한다. 표준 라이브러리만 쓰는 별도 검증 CLI가 카탈로그·회차·문항 projection·복사 파일·R2 객체 목록·SQLite D1 seed를 원본과 대조한다. 격리 fixture 테스트에서 오래된 복사, 카탈로그 누락, private 필드 유출을 검출한다.

**Tech Stack:** Python 3 standard library, `unittest`, `sqlite3`.

**Spec:** `docs/superpowers/specs/2026-10-28-content-bundle-verification.md`

## Global Constraints

- 실제 학습 데이터·정답·해설을 테스트 출력에 남기지 않는다.
- 서버 업로드·원격 migration·Cloudflare 설정은 실행하지 않는다.
- `backend/data` 및 기존 사용자 변경·산출물을 삭제하지 않는다.

## Review Focus

1. 누락/오래된 catalog가 전체 트랙 목록 API를 멈추는지 검증한다.
2. question body 필드 projection과 `qid`가 원본과 같은지 검증한다.
3. R2 JSON에서 정답/해설 키 유출 및 D1 qid mismatch를 검출한다.
4. 학습 JSON/이미지/이론 파일의 누락·오래된 바이트를 검출한다.
5. R2 출력에 예상하지 않은 파일이 포함되지 않는지 검증한다.

---

### Task 1: 검증기 회귀 테스트

**Files:** `backend/scripts/test_verify_r2_bundle.py`, `backend/scripts/verify_r2_bundle.py`

- [x] 임시 fixture를 만드는 테스트에서 정상 번들은 통과하고 catalog 누락, source-copy 불일치, `answer`/`explanation` 유출은 각각 실패함을 검증한다.
- [x] 테스트를 먼저 실행해 검증기 미존재 assertion failure로 RED를 확인했다.

### Task 2: 원본·R2·D1 대조 CLI

**Files:** `backend/scripts/verify_r2_bundle.py`

- [x] 표준 라이브러리만 사용해 원본 카탈로그/문항/정적 복사본/정확한 R2 key inventory/D1 qid 집합을 검사한다.
- [x] 실패 시 콘텐츠 값을 노출하지 않고 경로/불일치 종류만 출력한다.
- [x] 11개 fixture 회귀가 GREEN인지 확인했다.

### Task 3: 현재 번들 재생성 및 증거

**Files:** `backend/scripts/out/**`, `backend/cloudflare/DEPLOY.md`, `formal/data-bundle-readiness/**`, `docs/HANDOFF.md`, `docs/SEPARATION_CHECKLIST.md`

- [x] 현재 원본에서 번들을 재생성한 후 검증기를 실행했다.
- [x] 성공 로그에 트랙/회차/문항/R2 object/복사 파일/D1 row aggregate count를 기록했다.
- [x] Worker 25/25, Flutter 90/90 및 analyze, CodeB 43/43, 검증기 11/11을 실행했다. 최종 문서 수정 뒤 `git diff --check`를 실행해 통과했다. 원격 Cloudflare는 변경하지 않았다.

## 완료 판정

- 로컬 bundle verification 통과는 업로드/서비스 공개/운영 최신성을 뜻하지 않는다.
- 실제 D1/R2 반영, API E2E, 버전 전환 및 롤백은 별도 운영 단계다.

## Final status — 2026-10-28

- Local packaging verification is complete; deployment readiness is not claimed.
- The deploy guide now requires running `verify_r2_bundle.py` before any D1/R2 upload step.
- Latest data counts and known image fallback exceptions are recorded in `formal/data-bundle-readiness/SCOPE.md`.
