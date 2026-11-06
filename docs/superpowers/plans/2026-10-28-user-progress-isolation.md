# 사용자별 학습기록 격리 및 동기화 구현 계획

> **실행 방식:** 이 계획은 현재 에이전트가 단일 작업자로 A→E 역할 전환 검토를 적용해 실행한다.

**목표:** 게스트 및 로그인 계정의 학습기록을 기기 안에서 분리하고, 인증된 사용자의 진도만 해당 사용자 서버 저장공간으로 동기화한다.

**구성:** 기존 Hive 데이터는 게스트 박스 이름에 그대로 둬 손실이나 계정 오귀속을 막는다. Google/Kakao 서버 계정은 계정 ID의 SHA-256 이름공간을 사용한다. 앱 기록 변경은 사용자 세션 토큰으로 Worker progress API에 debounce 업로드하며, 계정 전환으로 오래된 응답이 새 계정에 적용되지 않게 한다. 서버는 D1 compare-and-swap와 tombstone 병합으로 동시 갱신 손실과 삭제 데이터의 부활을 막는다.

**기술:** Flutter/Dart, Hive, Cloudflare Worker, D1/SQLite, TLA+/TLC.

**범위:** `docs/DATA_STORAGE_POLICY.md`, `docs/HANDOFF.md`, `docs/SEPARATION_CHECKLIST.md`의 계정별 진도 미완료 항목. 로그인 공급자/OAuth 설정, Cloudflare 배포 및 외부 게시 제외.

## 공통 제약

- 공용/기존 Hive 박스는 삭제하거나 사용자 계정에 자동 귀속하지 않는다.
- API 토큰은 사용자 서버 세션(`AuthService`)에서만 읽고 관리자 토큰을 사용하지 않는다.
- Worker는 검증된 세션 `userId`만으로 사용자 progress row를 조회·갱신한다.
- 서버 미설정·네트워크 오류면 로컬 학습은 계속 가능하고 권한이 변경되지 않는다.
- 운영 D1·R2·Worker와 OAuth 설정은 이 작업에서 수정하지 않는다.

## 검토 중점

1. 게스트→A→B→A 전환에서 다른 사용자의 학습기록이 비치지 않는지 — Flutter Hive 회귀 테스트.
2. 계정 전환 직전 시작한 네트워크 요청이 새 계정 데이터를 덮지 않는지 — 지연 응답 재현 + TLA+.
3. 삭제 기록이 다른 기기의 오래된 복사본으로 되살아나지 않는지 — Worker 병합 테스트 + TLA+.
4. 동시 D1 push가 서로 다른 qid 업데이트를 잃지 않는지 — 가짜 D1 CAS 재현 + TLA+.
5. 로컬 수정 중 응답이 도착해도 더 최신 값이 유지되는지 — 서비스 단위테스트.

## 작업 체크리스트

- [x] A: 저장 박스, 로그인 수명주기, Worker progress API와 실제 호출처를 읽어 소유권 범위를 확정.
- [x] B: 구현 전 race/CAS/tombstone/backup 실패를 재현하고 구현 뒤 회귀 테스트를 통과시킴.
- [x] C: 계정별 Hive 공간, AuthService 전환 훅, 사용자 세션 동기화, 서버 CAS/tombstone과 body 크기 제한을 구현.
- [x] D: A/B 로그인 경계, 느린 GET 응답, tombstone, backup fingerprint, CAS, 바이트 경계를 출력→저장까지 역추적. 코드 대응은 `formal/user-progress-sync/CORRESPONDENCE.md`.
- [x] E: 정상·결함·sanity TLC, Flutter 100/100, Worker 35/35, 관련 테스트 15/15, 변경 파일 분석, `dart analyze lib`, 형식 검사 및 Wrangler dry-run 결과를 `formal/user-progress-sync/evidence/verification.md`에 기록. Flutter wrapper `flutter analyze --no-pub`는 유휴 대기했으나 직접 Dart 전체 앱 분석은 `No issues found!`.
- [ ] 배포 게이트와 외부 운영 E2E는 실제 계정·환경 접근 없이 봉인하지 않는다.
