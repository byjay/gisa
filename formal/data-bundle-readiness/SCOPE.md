# GISACLUB 데이터 번들 준비도 검증 범위

기준일: 2026-10-28 (Asia/Seoul)

## 검증 대상

- 소스: `backend/data/study/`, `backend/data/theory/`, `backend/catalog/tracks.json`.
- 생성물: Git ignore 상태의 `backend/scripts/out/d1_seed.sql` 및 `backend/scripts/out/r2/`.
- 검증기: `backend/scripts/verify_r2_bundle.py`; 격리 fixture: `backend/scripts/test_verify_r2_bundle.py`.
- 운영 경계: 검증기는 로컬 파일만 읽는다. Cloudflare 로그인, 원격 D1/R2, secret, 배포, DNS, 공개 URL은 검사하거나 변경하지 않는다.

## 불변식 및 수치 재검산

생성기 출력의 정수 문항 수를 트랙별로 더한다.

```text
architecture 1,872
+ construction_safety 2,145
+ elec_construction 840
+ elec_industrial 1,673
+ electrician 3,017
+ fire_electric 1,444
+ fire_mechanical 1,496
+ hazmat_industrial 1,125
+ industrial_safety 2,252
+ info_processing 789
= 16,653 questions
```

- 생성 후 검증: 트랙 10, 회차 193, 문제 16,653.
- D1 seed를 현재 migrations로 메모리 SQLite에 실행: `questions_meta` 16,653 qid, `answers_private` 16,653 qid. 양쪽 qid 집합이 소스에서 계산한 16,653개 qid 집합과 동일.
- R2: 3,609 objects, 100,595,529 bytes. 범주별 `catalog` 1, `content` 203, `images` 3,233, `study` 124, `theory` 48.
- 학습 JSON·이미지·이론 3,405개는 로컬 소스와 1 MiB 스트리밍 비교로 바이트 일치.
- 문제 이미지 경로 2,436개는 각각 R2 이미지 원본 파일이 존재. `has_image=true`이지만 별도 `image` 경로가 없는 문항 79개는 검증기가 오류로 처리하지 않는다. 앱의 “그림문제·원본PDF 참고” 표시만으로 원본 PDF 내용까지 일치하는지는 증명되지 않았으므로 별도 시각 점검 범위다.
- R2 문제 본문은 재귀 키 검사에서 `answer`/`explanation` 0개. study JSON은 Worker의 파일 허용목록과 같은 이름만 허용. 예상하지 않은 R2 key도 거부.

## 재현 명령

```powershell
Set-Location E:\gisaclub
python backend/scripts/split_content_for_r2.py --data-dir backend/data/study --out backend/scripts/out
python -m unittest discover -s backend/scripts -p 'test_*.py' -v
python backend/scripts/verify_r2_bundle.py
```

## 증거 파일

- `evidence/bundle-regenerated-2026-10-28.log`
- `evidence/bundle-verify-2026-10-28.log`
- `evidence/bundle-tests-2026-10-28.log`
- `evidence/worker-tests-2026-10-28.log`

## 범위 밖 / 미검증

- 생성물의 실제 R2 업로드 및 D1 적용, Worker endpoint E2E, Cron 실실행, 공개 서비스 연결과 rollback 전환은 하지 않았다.
- 코드 검증은 명시한 입력 구조와 현재 migration에 한정된다. 원본 콘텐츠의 저작권·정확성, 운영 R2의 기존 stale object 제거, 실제 사용자 권한은 검증하지 않는다.
- 학습 원본/이론 파일은 APK 밖에 있고 gitignore된 서버 소스 경로에 보관된다. 이전 커밋·원격 저장소 이력에서 완전히 삭제됐는지는 별도 문제다.
- 데이터 변환은 결정적 파일 작업이며 동시 상태 전이가 없으므로 이 검증에는 TLA+ 모델을 적용하지 않았다. 계정/결제/진도 동기화 등 상태 경계의 기존 모델과는 별개다.
