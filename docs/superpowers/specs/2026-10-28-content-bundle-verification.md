# GISACLUB 서버 콘텐츠 번들 검증 명세

## 목표

APK에서 분리한 학습 원본을 Cloudflare D1/R2에 올리기 전, 현재 원본과 패키지의 콘텐츠·문제 수·카탈로그가 정확히 일치하는지 로컬에서 재현 가능하게 검증한다.

## 범위

- 기존 `backend/scripts/split_content_for_r2.py` 출력인 `d1_seed.sql`과 `r2/`를 검증한다.
- R2에 필요한 `catalog/tracks.json` 누락, stale 복사본, 추가/누락 객체, 문제 본문 정답·해설 키, D1 문제 메타/정답 행의 수와 qid 불일치를 검출한다.
- 테스트는 격리 임시 디렉터리의 최소 fixture만 사용하며 실제 학습 데이터 내용이나 답을 로그에 출력하지 않는다.
- 검증은 로컬 파일만 읽는다. Cloudflare 계정, 원격 D1/R2, 로그인, 배포는 건드리지 않는다.

## 입력과 출력

- 입력: `backend/data/study`, `backend/data/theory`, `backend/catalog/tracks.json`, 생성된 번들 디렉터리, D1 migrations.
- 성공 출력: aggregate counts와 exit code 0.
- 실패 출력: 잘못된 상대 키/개수와 exit code 1. 질문·정답·해설 본문 값은 출력하지 않는다.

## 불변 조건

1. R2 `catalog/tracks.json`은 소스 카탈로그와 자격증별 실제 문항 수를 담는다.
2. 각 회차 `_index.json`과 `paper.json`은 현재 소스와 일치하고 모든 qid가 일대일 대응한다.
3. R2 문제 본문에는 `answer` 또는 `explanation` 필드가 없다.
4. D1 `questions_meta` 및 `answers_private`의 qid 집합과 건수는 소스의 전체 qid 집합과 각각 같다.
5. 학습 JSON·이미지·이론 파일은 소스와 바이트 단위로 같고 R2 객체 집합에 예상 외 파일이 없다.
6. 검증기는 서버 업로드를 수행하지 않는다.

## 현재 재현 결함

2026-10-28 기존 `backend/scripts/out` 점검에서 `catalog/tracks.json`이 없고, `study/electrician/repeat_questions.json`이 현재 소스와 달랐다. 문제 16,653개와 D1 메타/정답 행 수는 각각 일치했고 R2 문제 본문의 `answer`/`explanation` 키는 0개였다. 검증기로 오래된 패키지 상태를 자동 거부하고 재생성된 패키지를 통과시킨다.

## 비목표

원격 업로드·마이그레이션, 소스 데이터 권리 판정, 앱 기능 변경, 문제 본문 암호화, 라이브 캐시/버전 전환은 이번 범위가 아니다. 이 항목은 별도 운영 게이트로 남는다.
