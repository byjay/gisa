# REA 재분석 및 GUI/백엔드·데이터 분리 체크리스트

**작업 기준일:** 2026-10-28 (Asia/Seoul)
**대상 저장소:** `E:\gisaclub`
**참조 보관본:** `E:\gisaclub\OLD\flutter_app`
**사용자 목표:** REA로 APK를 다시 분석하고, 빌드되는 GUI/클라이언트 앱과 백엔드·학습 데이터를 분리한 뒤 검증된 형태로 빌드한다.
**배포 대상 추가:** Cloudflare Pages 웹 빌드 및 `gisaclub.codeb.app` 연결.

## 완료 기준

1. 배포 APK에는 Flutter 실행 엔진, 앱 UI/통신 코드, 일반 UI 에셋만 있고 시험 문제·정답·해설·시험 인덱스·교재·자격증 학습자료·seed 데이터가 없어야 한다.
2. APK를 만들지 않고도 Worker를 별도 빌드/배포할 수 있어야 하며, Worker 코드/비밀값/배포 설정이 Android 패키지에 들어가면 안 된다.
3. 앱의 학습 데이터 읽기와 채점이 모두 원격 API를 통하며, 운영 화면/상태 관리 경로에 로컬 학습데이터 fallback이나 숨겨진 중복 사본이 없어야 한다.
4. APK가 공개해도 되는 설정만 포함해야 한다. OAuth 공개 client ID와 API URL은 비밀로 취급하지 않으며 signing key, Worker secrets, admin tokens는 APK와 저장소에 없어야 한다.
5. API별 요청·응답·권한, 백엔드 D1/R2 데이터·이미지 경로가 일치하고, 실제 서비스 연동이 막힌 설정은 명시되어야 한다.
6. 수정 후 Analyzer/포맷/Worker 구문 검사/빌드·서명/패키지 인벤토리/REA 분석을 실행해 결과를 저장한다. 실통합 불가면 그 구간을 미검증 처리하고 “완전 분리·운영 가능”이라고 봉인하지 않는다.
7. Cloudflare Pages 산출물에는 앱의 웹 UI만 포함하고, API 주소·OAuth 공개 client ID를 빌드 설정으로 주입하며 학습 데이터·Worker 비밀값을 포함하지 않는다.
8. `gisaclub.codeb.app` 연결은 Pages 배포, Cloudflare zone 소유/활성 상태, Google OAuth 허용 origin, Worker CORS/인증을 검증한 뒤 운영 도메인으로 공개한다.
9. Kakao 로그인은 공개 앱 키와 서버 비밀값을 분리하고 Worker가 Kakao 사용자를 검증한 뒤 Gisaclub 세션을 발급해야 한다.

## 실행 체크리스트

### A. 계획·기준선

- [x] 사용자 요청과 이전 인수인계 기록 읽기
- [x] 저장소 작업 위치·기준 커밋·미커밋 변경 파악
- [x] 분리 완료 기준 정의
- [x] 앱 및 백엔드 병렬 코드 감사 결과 수렴

### B. REA 재분석

- [x] 새 arm64 APK를 REA `inspect_artifact`로 인벤토리 분석
- [x] Flutter 빌드 식별 및 SHA-256 고정
- [x] 이번 REA occurrence 전체 페이지에서 Flutter `assets/data`, `assets/theory` 항목이 없는지 확인
- [ ] APK 전체 R2-style resource path와 앱 메타데이터/권한 검토
- [ ] 기존 APK와 비교해 데이터 제거 여부·비의도 차이 확인
- [ ] REA 결과의 제한점과 미확인 런타임 동작 기록

### C. 클라이언트/백엔드 경계 감사

- [ ] Flutter 에셋 선언과 소스의 asset/local file fallback 전체 검색
- [ ] 로그인 전·후 시작 흐름과 모든 화면의 서버 요구 조건 확인
- [ ] API 계약(경로/메서드/요청·응답/인증/권한)과 Worker 라우트 대조
- [ ] D1/R2 seed·업로드/정합성 및 업데이트·삭제 동작 확인
- [ ] APK/Worker 환경설정과 signing/deploy secret 노출 점검
- [ ] 오프라인/네트워크 실패 시 화면·데이터 누출 동작 점검

## 감사에서 확인한 남은 분리 결함

- **REA APK 인벤토리 (observed):** APK SHA-256은 `c916d7f4fa6438685505cbc9dc93d1a4b834113495355d2444fcdc3a95bb39d3`. REA artifact graph는 노드 620, 파일 occurrence 680, integrity contradictions 0이며 소스 커버리지 complete. 해당 APK의 Flutter ARM64 식별도 통과했다. 아직 occurrence 경로 쿼리로 학습 에셋 0개를 이번 패스에서 재입증하지 않았다.
- **트랙 카탈로그 (source-observed):** `lib/services/exam_track.dart`의 `kExamTracks`가 트랙 이름·별칭·과목·이론 파일 경로·문제/토픽/반복 문항 수·시험 크기를 앱 코드에 포함한다. `track_select_screen.dart`, `home_screen.dart`, `app_provider.dart`, `study_data.dart`, `admin_settings_screen.dart`, `cerebras_service.dart`가 이 모델을 소비한다. 새 API에서 이 메타데이터를 원격 제공하고 기존 소비부를 바꾸기 전에는 완전 분리가 아니다.
- **로컬 데이터 fallback (source-observed; 수정 중):** 기존 코드에서 문제·이론·Q-Net 데이터를 `rootBundle`로 읽는 fallback이 있었다. 현재 변경으로 Flutter 데이터 경로와 Q-Net 직접 크롤링을 제거했고, 콘텐츠·Q-Net 자료를 Worker API/R2에서 받도록 바꿨다. 정적 검색과 컴파일로 경로 폐기를 확인한다.
- **로컬 사용자 진도 (source-observed):** Hive를 오프라인 write-through 저장소로 사용한다. ProgressSyncService는 사용자 bearer session으로 Worker progress API에 연결된다. 문제 진도·세션·CBT 결과와 SRS·일별 점수·슬라이드·응시등록의 allowlist 필드만 전송하며, 오답노트의 문제·정답·해설·개인 메모는 로컬 암호화 box에 남긴다. 실제 원격 배포/E2E는 별도 미검증이다.
- **D1 재수입 (source-observed):** `split_content_for_r2.py`는 upsert만 만든다. 소스에 빠진 예전 qid를 운영 D1에서 안전하게 제거하거나 버전 원자 전환하는 프로토콜이 없다. 아직 이를 변경하지 않았다.
- **운영 설정 (source-observed):** OAuth client 및 Access 값이 placeholder/empty로 기록돼 있어 로그인과 전체 운영 API E2E는 막혀 있다.

### 사용자 진도 격리·동기화 체크포인트 (2026-10-28, 작업 중)

- [x] 기존 소스에서 `ProgressSyncService`가 `AdminService.serverToken`을 읽고, 실제 진도 변경 호출처에는 sync 연결이 없음을 확인했다.
- [x] 기존 Hive 개인기록 상자(`sessions`, `wrongNotes`, `quizResults`, `questionProgress`, SRS/점수/슬라이드/응시 기록)가 계정 이름공간 없이 열리는 것을 확인했다.
- [x] 계정별 상자 이름과 Worker 삭제 tombstone·최신값·D1 CAS 동작을 기대하는 Flutter/Worker 테스트를 먼저 작성했다.
- [x] 게스트/계정 상자 분리, 로그인 전환, 사용자 세션 sync, 서버 CAS·삭제 전파를 코드 전후 테스트로 검증한다.
- [x] 백업/복원 경로가 현재 계정 이름공간을 사용하고 다른 계정 백업을 섞지 않는지 구현·검증한다.
- [x] `formal/user-progress-sync/` TLA+ 정상/결함/도달성 모델과 코드 대응표를 작성·실행했다. 안전 컬렉션 모델과 로그는 2026-10-29 후속 기록 참조.
- [x] Flutter 경계 테스트·Worker 전체 tests·대상 Dart 분석·산술 검사 및 Worker dry-run을 실행하고 핸드오프에 기록했다.
- [ ] 운영 Worker/D1/OAuth, Cloudflare 계정 변경 및 외부 배포는 운영 설정과 사용자 판단 없이는 실행하지 않는다.

#### 2026-10-29 안전한 추가 학습기록 동기화

- [x] SRS·점수이력·슬라이드 진행·응시등록을 사용자별 snapshot으로 추가하고, 쓰기 뒤 동기화를 예약한다.
- [x] 점수는 `scoreMilli` 정수(0..100000, 0.001점 단위)로 직렬화하고 100,001개 표현값 round-trip 및 양자화 오차 경계를 재검산했다.
- [x] 슬라이드 페이지 수를 max 병합하고, 응시등록 삭제 tombstone이 오래된 장치의 업로드보다 우선하도록 구현했다.
- [x] `wrongNotes`는 문제/정답/해설/사용자 메모가 있으므로 snapshot 생성·Worker 저장 allowlist 모두에서 제외함을 테스트했다.
- [x] 계정 전환의 SRS/점수 namespace, planned registration의 null 점수 처리, 원격 merge allowlist를 회귀 테스트했다.
- [ ] 운영 Worker/D1에 반영 및 두 계정/두 기기 실 API 동기화 E2E는 환경 변수 placeholder/미배포 때문에 미검증.

### D. 수정·빌드

- [ ] 발견한 G1/G2부터 수정하고 핸드오프에 파일·라인 기록
- [ ] 수정 전/후 데이터 소유권 경계와 의존 경로 재검토
- [ ] `flutter analyze`, 포맷 검증, Worker `node --check`, `git diff --check`
- [ ] ABI별 release APK 빌드와 서명 검사
- [x] REA 최종 APK 재인벤토리: 2026-10-28 빌드의 2,003/2,003 항목 검사; study/theory 자료 0개
- [x] APK SHA-256 및 최종 빌드 옵션 기록 (2026-10-28 재검증 기록 참조)
- [x] Flutter Web release 빌드 및 정적 출력 검사 (2026-10-28 재검증 기록 참조)
- [ ] Pages 프로젝트/preview 배포 확인; `gisaclub.codeb.app` 운영 연결은 UI/API 검증 전 보류

### E. 통합/출시 게이트

- [ ] OAuth/Cloudflare Access 설정 실값 유효성 확인(비밀값은 기록하지 않음)
- [ ] Kakao REST/Native/JavaScript app key 구분·Web domain·redirect URI·Android package/hash 설정 확인
- [ ] Kakao client secret은 Worker secret으로만 보관하고 앱/APK/Pages에 없는지 확인
- [ ] Google·Kakao 로그인 모두 서버 세션 발급·인증·만료·로그아웃을 E2E 확인
- [ ] 새 Worker API의 운영 또는 격리된 실제 통합 전체 경로 확인
- [ ] 인증 발급→전송→검증→갱신/재로그인→만료/폐기 흐름 확인
- [ ] APK signer와 Play Console 업로드 인증서 호환성 확인
- [ ] D1/R2 object 개수·파일 해시·질문/정답 매칭 수 검증
- [ ] 기존 Worker version/commit을 롤백 기준으로 기록
- [ ] 5개 배포 게이트가 모두 통과한 경우에만 배포·봉인
- [ ] Pages custom domain `gisaclub.codeb.app` 연결 및 TLS/리디렉션 실응답 확인
- [ ] Pages origin이 Google OAuth 허용 origin에 등록됐는지 확인

## 현재 REA 증거 및 기준선

- arm64 APK: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- APK SHA-256: `c916d7f4fa6438685505cbc9dc93d1a4b834113495355d2444fcdc3a95bb39d3`
- REA `inspect_artifact` Evidence: `ev_4e5cb38efbd5e0387e2cec4c634a31fdde6b1f5ab7d1617afb8f225508832abb`
- REA inventory Evidence: `ev_fd27080393120de204d4b42d31fdb44ee03f0aed2de87b2648528b225df2c22e`
- REA compact summary Evidence: `ev_e420008a2e96418eb67f0af73f11c2460d9ffae3312fe9baf18d565905810184`
- REA Flutter identification Evidence: `ev_12378e07aa6c99117b068e4f58bdd2fbf927df8fead61304c2c9003e5af1f4b7`
- 확인된 APK SHA/Flutter 식별은 shipped artifact 관찰이다. ZIP 인벤토리는 중앙 디렉터리 기준이고 실행 행태·전체 앱 동작을 입증하지 않는다.

## 병렬 감사 요약

- 서버 감사 완료: importer는 기존 D1 row를 upsert하지만 소스에서 빠진 stale qid를 삭제/전환하지 않는다. 사용자 운영 D1/R2는 변경하지 않고 코드 계약·seed 경로만 확인했다.
- Flutter 감사 완료: 새 catalog API 소비부와 local course-data fallback 제거를 반영했다. Hive에 사용자 개인 진도는 남아 있고 Flutter↔Worker sync service 호출은 연결되지 않았다.

## Cloudflare Pages 분리 및 도메인 배포 체크

- [ ] Flutter Web production 빌드 및 `_redirects`/`_headers` 생성물 검사
- [ ] 배포 디렉터리에 시험 문제·정답·해설·교재·D1 seed/Worker 코드가 없는지 검사
- [ ] API_BASE_URL이 HTTPS Worker 주소인지 확인
- [ ] `GOOGLE_OAUTH_CLIENT_ID`가 빌드와 Worker 양쪽에서 같은 공개 OAuth client를 참조하는지 확인
- [ ] Cloudflare Pages project 생성/preview 배포 상태 확인
- [ ] Cloudflare 계정에 `codeb.app` zone이 연결되어 있는지 대시보드에서 확인
- [ ] Google OAuth web origin 및 Worker CORS에 `https://gisaclub.codeb.app` 반영
- [ ] Custom domain `gisaclub.codeb.app` 연결, 인증서 발급, 실제 HTTPS 로딩 확인
- [ ] 로그인 발급→API 요청→세션 만료/재로그인 end-to-end 확인

### 2026-10-28 배포 준비 관찰

- 사용자가 Cloudflare Pages 빌드 및 `gisaclub.codeb.app` 운영 호스트 연결을 요청했다. 로그인·계정 권한을 변경하지 말고 백그라운드 진행하도록 요청했다.
- `npx wrangler whoami`는 인증 성공했다. `wrangler pages project list`에는 `gisaclub` 이름 프로젝트가 없었다.
- 공개 DNS `codeb.app`은 Cloudflare 주소로 해석되며 `gisaclub.codeb.app`은 아직 응답 레코드가 없다. 공개 DNS 결과만으로 이 계정의 Zone 소유권이나 custom domain 설정 권한은 증명되지 않는다.
- Ego 프로세스는 실행 중이고 Cloudflare 대시보드 탭 제목이 확인됐지만, CUA `getApp({windowId:133776})`에서 window minimized 오류를 반환해 대시보드 DOM/UI 확인을 완료하지 못했다. 권한 설정은 변경하지 않았다.
- 소스 `backend/cloudflare/wrangler.toml`의 `GOOGLE_OAUTH_CLIENT_ID`는 placeholder이며 local `.env`/OAuth config 파일이 확인되지 않았다. 소스 `lib/services/auth_service.dart`는 이 값이 비어 있으면 Google 로그인 전에 예외를 던진다. 따라서 OAuth가 해결되기 전 운영 custom domain 공개는 보류한다.
- 최종 프로젝트 작업 경로는 `E:\gisaclub`으로 변경했다. 기존 참조 파일은 `OLD\reference-files`로 이동했고, 참조 프로젝트는 `OLD\flutter_app`에 보존했다. 새 루트에 복사한 문제/학습 자료는 `backend\data\study` 3,367개 파일, 이론 자료는 `backend\data\theory` 48개 파일이다.
- 사용자 요청: Kakao 로그인 추가 및 `developers.kakao.com`에서 Ego로 설정. 코드에는 Kakao SDK/연동이 없고 공식 Flutter 문서는 Android Native key와 Web JavaScript key, 웹 redirect 설정을 요구한다. Kakao console UI는 Ego minimized로 읽지 못했으며 앱 키/동의/플랫폼 설정은 미확인이다.

### 2026-10-28 학습 자료/메인 루트 검증

- [x] `backend\data\study` 문제·실기·이미지 원본 3,367개가 활성 루트 `E:\gisaclub`에 있음
- [x] `backend\data\theory` 이론 Markdown 48개가 활성 루트에 있음
- [x] 10개 track 폴더 확인
- [x] `OLD\flutter_app`와 상대경로 비교: 앱/서버 소스 및 학습 데이터 중 OLD에만 있는 파일 없음
- [x] OLD-only 두 파일은 `.wrangler\cache` 생성 캐시로 분류, 원본 코드/학습 자료 복사 대상 아님
- [x] 활성 루트에서 analyzer·테스트·Web/APK 빌드·최종 산출물 검증 재실행 (2026-10-28 재검증 기록 참조)

### 2026-10-28 현재 산출물 재검증

- [x] `flutter analyze --no-pub` 성공, 이슈 없음
- [x] `flutter test --no-pub` 성공, 77개 통과
- [x] `flutter build apk --release --no-pub` 성공: `build\app\outputs\flutter-apk\app-release.apk`, SHA-256 `992fff9c45ce067b43d50568ed46e93d7e38ddfd3fc82539ccc49ac3c69ea05b`
- [x] REA `open_binary` APK 정적 분석: 2,003/2,003 뷰 항목 검사, 무결성 모순 0; APK ZIP에서 study 에셋 0개, AdMob 클래스 0개. 정적 분석은 실행 동작 증거가 아님.
- [x] `flutter build web --release --no-pub` 성공: 236개 파일, 65.81 MiB. study/theory 파일 및 구형 CBT 데이터 받기 코드 미포함.
- [ ] 실제 OAuth 값 없는 검증용 APK/Web 빌드이므로 로그인 가능한 운영 산출물 또는 Cloudflare 배포로 간주하지 않음.

### AdSense·광고 수익화 점검 (2026-10-28)

- [x] 사용자 화면에서 AdSense 계정 심사 진행 중, 본인 확인 완료 상태 확인. 은행/세금 정보는 미완료로 표시됨.
- [x] 사이트 목록 캡처에서 `blog.secms.tech` 미등록 확인. 공개 사이트는 홈페이지 HTTP 200이며 `/ads.txt`도 200이지만 응답 본문은 `text/html` 홈페이지로, 유효한 ads.txt가 공개된 상태가 아님.
- [x] `E:\code-project\secms-blog\ads.txt` 로컬 초안 생성 및 1줄 형식 검증. 실제 사이트에 게시되지는 않음.
- [ ] `blog.secms.tech` AdSense 사이트 등록, 사이트 소유권 확인, 사이트 심사 요청/Ready 상태 확인.
- [ ] AdSense 광고 스크립트를 승인된 검증 방식에 맞게 전 페이지에 반영하고, 루트 `/ads.txt`가 평문으로 제공되는지 공개 응답 확인.
- [ ] 사이트 승인 후 Auto ads 미리보기/실험 적용 및 페이지별 광고 부하·이탈률·수익 측정.
- [ ] 검색 노출 측정용 Search Console 색인/사이트맵 및 페이지별 canonical/구조화 데이터 확인. 본 점검에서 SEO 설정은 수정하지 않음.
- [ ] GISACLUB 앱 광고 SDK/테스트 광고/동의 흐름을 구현하고 출시 전 실 광고 단위로 검증. 현재 APK에는 AdMob 클래스가 없음.
- [ ] 유료 기능 출시 전 Google Play 결제 검증·서버 entitlement 부여 구현. 현재 premium UI는 안내 모달이며 Worker billing 검증은 503 fail-closed.
- [ ] 계정/사이트 설정, 광고 게재, 서버/Pages 배포는 이번 점검에서 변경하지 않음. `secms-blog`의 라이브 반영은 저장소 승인 Worker 경로 및 배포 담당 절차를 따라야 함.

### CODEB.APP 심사·하위 도메인 설정 (2026-10-28)

- [x] AdSense 캡처에서 부모 `codeb.app`이 이미 등록되어 “검토 필요”, ads.txt “찾을 수 없음” 확인
- [x] Cloudflare Pages 읽기 확인: `codeb.app`, `www.codeb.app`, `todak.codeb.app`; `gisaclub.codeb.app` DNS 응답 없음
- [x] 현재 CODEB 홈에 광고 태그 없음. 로컬 광고 코드가 root 홈 페이지에 삽입되지 않았는지 빌드 출력 확인
- [x] CodeB `ads.txt` 소스 추가 및 빌더 복사 로직 추가. 별도 산출물에서 4필드 형식과 루트 출력 존재 확인
- [x] 격리 빌드 성공: `E:\code-project\codeb\_verify\adsense-ready-20261028-01`; 31개 페이지·31개 sitemap URL
- [x] 로컬 검토용 심사 준비/원문 콘텐츠 초안 작성: `E:\code-project\codeb\research\ADSENSE_READINESS_DRAFT_20261028.md`
- [x] 사실 기반 실무 콘텐츠 3편 추가 초안(케이블 데이터 이관, 도면 배포 기록, 자격증별 학습데이터 구조) 작성: `E:\code-project\codeb\research\CONTENT_STRENGTHENING_DRAFT_20261028.md`; 제품 단계/기능 과장·미확인 실적 주장은 제외
- [x] Agent 소유 Ego 세션의 Google 계정으로 Search Console `codeb.app` 도메인 속성 접근 확인
- [x] `https://codeb.app/sitemap.xml`을 Search Console에 제출, 상태 “성공”, 발견 URL 31개 확인
- [x] 공개 SEO 응답 확인: `/robots.txt` 200 text/plain(전체 허용, `/admin`, `/api/admin` 차단, sitemap 선언), `/sitemap.xml` 200 XML(31 URL, 호스트 혼합/중복 없음), `/rss.xml` 200 XML; 홈페이지 title/description(98자)/canonical 정상, noindex 없음
- [x] Search Console 현재 스냅샷: 색인 3개, “크롤링됨 - 현재 색인이 생성되지 않음” 1개, 현재 기간 검색 클릭 0회, Core Web Vitals 데이터 없음. 직접 홈 URL 검사는 “발견됨 - 현재 색인이 생성되지 않음”, 최근 크롤링 없음으로 표시(보고서 시점 차이 가능)
- [x] Ego에 로그인된 Naver 계정으로 Search Advisor 진입. `https://codeb.app`과 `https://todak.codeb.app` 등록(2026-10-28); 두 사이트 모두 소유확인 대기
- [x] 공개 `site:codeb.app` 검색 결과 없음 확인. Search Advisor 간단체크는 CAPTCHA에서 멈춰 완료하지 않았고 일일 조회 사용량은 0/10
- [x] Search Console 직접 조치 및 보안 문제 보고서 모두 “감지된 문제 없음” 확인
- [x] 매일 10:00 KST CODEB Google/Naver/AdSense 상태를 점검하는 thread heartbeat를 만들고, 변경 없으면 조용히 종료하도록 설정
- [x] `todak.codeb.app/robots.txt`, `/sitemap.xml`, `/rss.xml`은 200이지만 `text/html` 홈페이지 fallback. 유효한 robots/sitemap/RSS가 아니므로 호스트 피드 수정 필요
- [ ] Naver 소유확인용 HTML 파일/메타 태그를 Codeb 및 Todak 배포 원본에 반영, 확인 완료 후 각 사이트 sitemap 제출과 URL/SEO 진단
- [ ] Todak 배포 원본의 `robots.txt`, `sitemap.xml`, `rss.xml` 정적 응답을 구현하고 승인된 build/deploy 절차로 공개 후 상태·형식을 재검증
- [ ] 홈페이지 색인 요청을 눌렀을 때 Search Console이 실제 URL 검사 중으로 바뀌었으나 요청 제출 완료 확인을 얻지 못함. 후속 점검에서 처리 상태 재확인
- [ ] AdSense 페이지는 현재 Ego Google 계정에 해당 publisher 접근 권한이 없다고 표시. Auto ads 및 홈 URL 제외 설정은 미변경
- [ ] `codeb.app/ads.txt` live 응답을 평문으로 전환하고 AdSense ads.txt 상태 갱신 확인
- [ ] 개인정보처리방침·이용약관 실제 내용/푸터 링크 보강, 공식 연락 채널과 공개 가능한 사업자 정보 소유자 확인
- [ ] AdSense root 사이트가 Ready 된 후 Auto ads 설정. 홈 제외: `https://codeb.app/`, `https://www.codeb.app/`; 수동 광고 코드도 두 홈페이지에 삽입 금지
- [ ] 기존 도메인에 속한 subdomain을 AdSense Sites에 중복 등록하지 않음. 부모 `codeb.app` 승인 후 광고를 보일 호스트만 각 프로젝트에 광고 코드를 반영
- [ ] `todak.codeb.app`에 광고를 적용할 경우 건강정보 기반 개인화/리타게팅 금지, 개인정보 고지·동의와 Google 정책 재검토
- [ ] AdSense account access를 확인하고 만료 짧은 `draft-write` 및 Cloudflare Access 자격증명을 안전한 로컬 환경에 공급. 소유자 재인증/게시 이전에는 Cloudflare 라이브 배포 금지
- [ ] 이번 범위에서 AdSense 계정 설정, 사이트 등록, Auto ads, 제외 설정, Cloudflare 배포는 수행하지 않음

### 전략 진행상태 대조 — 2026-10-28

- [x] `E:\code-project\codeb` GISACLUB 제품 페이지 로컬 상세 초안: 현 구현 기능/개발 단계/학습 목표/수익화 목표를 구분하고 4단계 학습 흐름을 추가했다. 실제 앱 화면 캡처·전용 시연 영상은 확보되지 않아 게시하지 않았으며 도식은 설명용으로 표시했다.
- [x] 제공된 영상 2개는 제품 방향 참고 링크로만 표시했다. 기사클럽 자체 데모·성능 근거로 오인되지 않는 안내문을 추가했다.
- [x] 로그인 화면에 기존 브랜드 로고와 기사클럽 워드마크를 적용하고, 제공 설정이 있는 경우 Kakao/Google 버튼과 취소·실패용 사용자 안내를 간결하게 구성했다. `flutter analyze --no-pub` 이슈 없음, `flutter test --no-pub` 80 tests passed.
- [ ] ARM64 release APK 재빌드 및 REA 패키지 점검. 첫 빌드는 Kotlin incremental cache가 C:/Pub Cache와 E:/workspace의 경로 루트를 혼합해 실패했다. 증분 컴파일 비활성화 재시도 진행 중; 결과 확정 후 APK SHA-256 및 패키지 정보 기록.
- [ ] 전체 데이터/API 분리 및 동기화 E2E. 현재 학습 이력의 로컬 저장 부분이 남아 있다. 서버 세션/API 게이트 운영 구성은 확인하지 않았으며 완전 분리로 판정하지 않는다.
- [ ] 생산용 OAuth: 소스에 Kakao 인증 경로가 있으나 운영 키/도메인/redirect/Worker 구성은 확인 또는 변경하지 않았다. Kakao Web 로그인이 준비됐다고 주장하지 않는다.
- [ ] AdMob 및 Google Play 결제·서버 entitlement는 미구현 상태. 매출화는 목표이며 현재 동작 기능으로 소개하지 않는다.
- [ ] CodeB 상세 페이지 라이브 게시/Cloudflare 배포는 미수행. 검토용 초안·정적 빌드만 준비했고 소유자 재인증 게시 절차가 남아 있다.
- [ ] 진행상황 정기 보고의 누락을 기록한다. 이번 점검부터 실제 소스·검증·빌드 결과를 이 핸드오프와 체크리스트에 맞춰 대조하고, 의미 있는 변경/실패/차단 때 사용자에게 보고한다.

#### 2026-10-28 빌드/REA 결과로 상태 갱신

- 위의 “ARM64 release APK 재빌드 및 REA 패키지 점검” 진행중 표기는 아래 결과로 대체한다.
- [x] `flutter build apk --release --no-pub --target-platform android-arm64` 성공. APK 69,909,553 bytes, SHA-256 `6123FBD252A9638B905AE02F32C9C735A6BFE81CBE74A2B197511502705F4DFF`. 이전 APK 백업 SHA-256 `C26597D153CE3B03BDE2A02F86576E020BEF1A418C75FDDA296B6A23508EBFCB`.
- [x] REA archive 인벤토리: 파일 완전 커버리지, 627 nodes/687 occurrences/686 edges, integrity contradictions 0; APK SHA-256가 결과 파일과 일치.
- [ ] JADX 기반 Android manifest/package 해석은 `REA_JADX_MCP_JAR` 미설정으로 미수행. REA 제공자 설치/다운로드 없이 남은 제약으로 기록한다. 앱 런타임 동작을 정적 archive inventory로 확인했다고 보지 않는다.
- [ ] 14개의 대소문자 접기 경로 쌍을 확인했다(`res/` 항목). APK 오류로 단정하지 않으며 패키지 의미 분석이 가능한 환경에서 조사할 항목으로 둔다.

### 2026-10-28 본업 복귀 — 소스·APK·검증 대조

- 사용자 요청: “본업복귀해”. 활성 작업 루트 `E:\gisaclub`, 기준 HEAD `c22faadbdaed9a040a11e582d36a05a301f51e45`. 기존 미커밋 변경은 보존했다.
- 검증: `flutter analyze --no-pub` 통과(이슈 0, 78.1초); Worker `src/*.js` `node --check` 및 `git diff --check` 통과. `dart format --output=none --set-exit-if-changed lib test`는 기존 13개 파일 미포맷으로 exit 1; `--output=none` 실행이라 파일 변경은 없었다. 이번 턴에는 테스트 스위트를 실행하지 않았다. 가장 최근 기록된 테스트는 80/80 통과다.
- APK 비교: 현재 APK의 arm64 네이티브 라이브러리 4개와 Android manifest/DEX를 확인했다. 이전 사용자 APK에는 Flutter `assets/data` 2,990개와 `assets/theory` 48개가 있었고, 현재 APK에는 둘 다 0개다. 현재 APK SHA-256은 체크리스트 상단 REA 기준선 참조.
- G2 동기화 결함: `lib/services/progress_sync_service.dart:36,40`은 관리자 `AdminService.serverToken`을 사용자 진도 API bearer로 사용한다. `lib/services/auth_service.dart:65`의 실제 일반 사용자 세션 토큰과 다르며, `rg`로 확인한 `ProgressSyncService` 호출부는 클래스 자체와 주석뿐이라 동기화는 현재 앱 흐름에 연결되지 않았다. Worker `backend/cloudflare/src/index.js:162-166`은 표준 사용자 세션을 요구한다.
- 안전 경계: `lib/services/progress_service.dart:18`의 `questionProgress` 및 `lib/providers/app_provider.dart:92-96`의 학습 세션/오답/퀴즈 박스는 기기 전역 Hive 이름으로 열리고 사용자 ID 공간이 없다. 따라서 로그인 후 이 상자를 그대로 서버에 밀어 넣으면 동일 기기의 다른 계정 기록이 섞일 수 있다. 이 위험 때문에 동기화 연결/서버 쓰기는 하지 않았다. 다음 구현은 사용자별 로컬 데이터 공간과 이전 앱의 기기 전역 데이터 이관 정책을 먼저 정한 뒤 진행한다.
- 앱 진입: `lib/main.dart:158-162`는 API URL과 API 세션이 모두 없으면 로그인 화면으로 보낸다. 현재 APK는 검증용 서명 산출물이며 OAuth/API 설정 및 Play 인증서 호환성을 증명하지 않는다.
- 외부 상태: Cloudflare/Kakao 계정 권한·콘솔 설정·로그인, 배포 및 외부 공개는 이 점검에서 변경하지 않았다. 실제 OAuth/API E2E, D1/R2 운영 동기화, AdMob/Play 결제는 계속 미완료다.
- REA snapshot: archive-only inventory는 provider analysis profile이 없어 `close_binary(snapshot_path)`가 거부되었고, `close_binary({})`로 세션을 정상 종료했다. Evidence ID와 요약은 본 문서에 기록했다.

### 광고+유료 수익화 목표 (2026-10-28)

- [x] 무료 일일 기본 이용 + 명시적 선택형 보상 광고의 앱 내 추가 이용 + 유료 이용자 광고 전부 제거를 제품 목표로 기록.
- [x] 월 ₩1,000,000 목표 산식과 가정/제한을 `docs/MARKETING_REVENUE_PLAN_1M.md`에 기록.
- [x] 오래된 Play Store 문안의 확인되지 않은 기능·수치·Data Safety 주장을 제거하고 등록 금지 초안으로 재작성.
- [x] CodeB GISACLUB 로컬 제품 fact를 수익화 목표/미구현 사실로 맞추고, 42페이지 격리 빌드 및 SEO/단위 테스트 통과.
- [ ] 일일 무료량·보상량·상한·가격 결정 및 사용자별 계정/진도 저장 안정화.
- [ ] AdMob SDK·동의/개인정보·보상 무결성·정책 검증.
- [ ] Play Billing·서버 구매 토큰 검증·복원/취소/환불/만료·유료 광고 제거 테스트.
- [x] 전체 시각/인터랙션 검증 완료: 44 public + 3 admin, console/overflow 0, broken link 0, banned claims 0. 샷: E:\code-project\codeb\_verify\gisaclub-monetization-draft-20261028-shots.
- [ ] 사용자 재인증 및 명시적인 게시 절차 전까지 외부 공개/배포 금지.



### 수학 검증 규칙과 도구 (2026-10-28)

- [x] proof-skills 네 스킬을 사용자 Codex 스킬 폴더에 설치하고 저장소 main commit 기록.
- [x] GISACLUB AGENTS.md에 금액/쿼터/권한/점수/동시성 검증 게이트와 증명 한계를 추가.
- [x] 월 100만 원 산식에 정수원·기저점 수수료·ceil division 검증기를 추가하고 재실행 PASS.
- [ ] AdMob 보상·Play 구매/복원·사용량 쿼터를 구현할 때 TLA+로 중복/경쟁/만료 상태를 검증하고 실제 코드 재현.
- [ ] 무한 입력 크기 알고리즘/불변식이 도입될 경우 Lean 증명과 trust audit 수행.

### 2026-10-28 — CODEB Google/Naver 검색 노출 후속

- [x] 공개 사이트 응답 비교: 라이브 sitemap 31 URL/latest lastmod 2026-10-09; root·robots·sitemap·GISACLUB 제품 페이지 200; ads.txt·privacy·terms·Naver 확인 HTML 404.
- [x] Search Console read-only: sitemap 성공/마지막 읽음 2026-10-28/발견 31, 개요 색인 3·미색인 1·클릭 0.
- [x] CODEB 원본의 GISACLUB 자격증 안내 10개와 색인 페이지 1개, GISACLUB 카탈로그 10개 일치 확인.
- [x] sitemap `lastmod`가 실제 페이지/제품 수정일 및 관련 업데이트만 사용하도록 CODEB renderer 수정. 개별 날짜가 없으면 생략.
- [x] SEO 회귀 테스트 42/42, 가이드 동기화, 42페이지/42 URL 로컬 검토 빌드 및 SEO 검사 통과.
- [ ] 브라우저 시각 검증 종료 결과를 핸드오프에 추가.
- [ ] 사용자 재인증 및 승인된 CODEB 게시 절차로 라이브 반영 후 Naver 확인 HTML과 ads.txt/robots/sitemap 응답 확인.
- [ ] 라이브 반영 후 Google sitemap 새로고침/색인 상태와 Naver sitemap·RSS 수집을 읽기 전용으로 재확인. Search Advisor 현 Agent 세션은 로그인 화면.
- [ ] 개인정보처리방침·이용약관·연락처·사업자 공개 항목은 실제 운영 내용과 소유자 확인 후 완성. 현재 공개 경로 404.
- 참고: `E:\code-project\codeb\research\SEARCH_VISIBILITY_DRAFT_20261028.md`. 검색 순위나 색인을 보장하지 않는다.


### 학습 데이터 보호·증명 규칙 최종 점검 (2026-10-28)

- [x] proof-skills 네 개가 사용자 전역 스킬 디렉터리에 설치되어 있고, 전역 `C:\Users\FREE\.codex\AGENTS.md`와 GISACLUB/CodeB 프로젝트 규칙이 핵심 경계 검증을 지정한다.
- [x] `/backend/data/` Git ignore 적용 및 study API 비인증 회귀 검사 확장: 자격증/회차/문제/이미지/해설/채점/AI/entitlement/billing/progress GET·POST 총 17개 경로 조합이 인증 없이 401이다. `/v1/health`, `/v1/app/version`, 로그인 경로, 관리자 경로는 공개 사용자 자료 엔드포인트와 구별한다.
- [x] study file allowlist가 `answers_private.json`과 경로 traversal을 R2 조회 전에 차단한다. 인증된 question image 응답은 `Cache-Control: no-store`.
- [x] AuthService 로그아웃·만료·계정 전환 때 세션 콘텐츠 캐시를 제거하고, RemoteContentApi 및 StudyData가 늦은 응답을 세션/캐시에 재삽입하지 않도록 generation guard를 적용한다.
- [x] Flutter analyze 통과, Flutter 전체 82/82, race 회귀 2/2, Worker 보안 및 Kakao 인증 8/8.
- [x] TLC 고정 모델 111 distinct states·depth 7에서 불변식 통과; 의도적 결함과 도달성 sanity 설정이 각각 의도대로 invariant failure를 검출. 상세 모델, 코드 대응, 로그: `formal/session-content-boundary/`.
- [x] 새 arm64 release APK 69,975,089 bytes, SHA-256 `89A31BBB7549A92E1AE3B2B9A87127E08D7965719B3885C52A9AF0CE47F3970C`; APK ZIP에서 `assets/data`, `assets/theory`, study-plan/answer/question 원본 경로 0.
- [x] REA APK archive inventory에서 SHA 일치, 627 nodes/687 occurrences/686 edges, integrity contradictions 0. `apksigner verify --verbose` v2 서명 PASS, 로컬 인증서 SHA-1은 이전 로컬 빌드와 일치. Play Console 키 일치와 실행 동작은 미검증; 매니페스트 의미분석은 JADX jar 부재.
- [ ] 이전 커밋에 포함됐던 학습 데이터가 Git 과거 이력에 남을 가능성은 해소되지 않았다. 현재 origin 공개 상태는 확인 불가. 이력 재작성/force push와 원격 공개 상태 변경은 아직 수행하지 않음.
- [ ] Strix 검사는 `strix --version` 자체가 uv trampoline 오류로 exit 1, Docker Engine 파이프 미연결, `STRIX_LLM`/`LLM_API_KEY` 미설정으로 실행하지 않았다. 실제 운영 OAuth 세션 수명주기, Worker/R2 배포 E2E, 영구 학습기록 사용자 분리 및 동기화도 미검증.
- [ ] Cloudflare/외부 공개 승인 및 CodeB draft-write 초안 저장/소유자 휴대폰 재인증 게시 미완료.
- [x] CodeB 최신 로컬 소개 초안 42페이지/42 URL SEO pass; 시각 검증 public44+admin3, 2 themes/2 widths PASS, console/overflow 0, broken links 0, banned claims 0.
- [ ] 실 앱 동작 캡처·GISACLUB 전용 데모 영상이 없어 홍보용 미디어는 게시하지 않음. 로컬 설명 도식은 실제 앱 화면이 아님.

## 2026-10-28 최신 대조 — 분리·검색 노출·운영 자동화

이 절은 앞선 체크리스트의 시점별 기록을 덮어쓰지 않고, 현재 산출물로 다시 확인한 결과다. `docs/HANDOFF.md`의 “이전 요청 전수 상태”가 전체 요청 매트릭스다.

### 이번 차례 확인 완료

- [x] 현재 arm64 APK를 REA로 다시 열고 digest를 APK 파일 해시와 대조했다: `89a31bbb7549a92e1ae3b2b9a87127e08d7965719b3885c52a9af0ce47f3970c`.
- [x] REA 정적 인벤토리는 627 nodes/687 occurrences/686 edges, integrity contradictions 0. 정확한 Flutter study/theory asset prefix와 후보 학습 파일은 0건. 결과는 `formal/daily-theory-drafts/evidence/gisaclub-release-apk-20261028.rae.json`.
- [x] Worker 서버 이론 초안 생성은 KST 매일 08:00, 세 개 서로 다른 자격증 과목, private D1 검토 큐로 구현. 문제/정답/해설/이론 원문을 AI에 보내지 않고 Naver 자동 공개 경로를 두지 않음.
- [x] D1 schema unique slot + generator claim token + 15분 lease fencing + 제한 길이/상태 전이 검사; 날짜/슬롯당 중복 및 지연 응답 차단 회귀가 통과했다.
- [x] Worker full suite 25/25, draft-specific 8/8, Wrangler dry-run 번들링, migration SQLite 실행 및 Node 구문 검사를 확인했다.
- [x] TLA+ 정상 유한 탐색 9,261 states/depth 13; slot/owner/no-public invariants 통과. `PublishBug` 결함 및 `NoReviewReached` sanity 모델은 의도한 반례를 찾음. 대응표/가정은 `formal/daily-theory-drafts/`.
- [x] CodeB 격리 build 42페이지/42 sitemap URL; `products/gisaclub/#problem` 안에 캡션·alt가 있는 실제 Android 개발 화면 2장. CodeB tests 43/43.
- [x] CODEB 제품 사이트의 루트 ads.txt 및 Naver 확인 파일은 Naver가 내려준 원본과 바이트 일치; 격리 build 루트 정적 파일의 존재와 복사 일치 확인.
- [x] CODEB 검토 산출물의 루트 정적 파일만 검사; `_verify` 디렉터리 자체는 배포 산출물에 복사되지 않음. `file:///.../_verify/` 디렉터리 화면은 로컬 폴더 보기다.
- [x] Naver Search Advisor 기존 계정의 CODEB 제품 사이트 속성(codeb.app, todak.codeb.app)을 읽기 전용 확인: 소유확인 대기. 파일은 준비했지만 “소유확인” 버튼은 클릭하지 않음.
- [x] 데이터 번들 검증에서 `catalog/tracks.json` 누락과 `electrician/repeat_questions.json` stale copy를 재현했다. 최신 원본에서 다시 생성해 검증기 통과.
- [x] `backend/cloudflare/DEPLOY.md`에 D1/R2 업로드 전 데이터 번들 검증 단계를 추가했다.
- [x] 현재 번들: 10 tracks/193 exams/16,653 questions, 3,609 R2 objects, 3,405 byte-identical study/image/theory files, D1 meta/private 각 16,653 qids; R2 body의 answer/explanation key 0개.
- [x] 번들 validator 11/11, Worker 25/25, Flutter 90/90 및 analyze, CODEB 43/43 회귀 확인.

### 배포 불가/미검증 — 그대로 미완료

- [ ] Cloudflare 실 OAuth·Access 설정과 `CEREBRAS_API_KEY` 존재/정합성: 미확인. `wrangler.toml`의 Google OAuth/Access placeholder가 남아 있다.
- [ ] 신규 D1 migration의 원격 적용, Worker 배포, Cron 실실행, AI 공급자 통합, 전체 endpoint E2E: 미실행.
- [ ] 최신 D1/R2 패키지는 로컬 gitignored 산출물이다. Cloudflare remote에 업로드/seed 적용되지 않았으며 운영 객체 최신성은 미검증.
- [ ] 사용자 세션 refresh·만료 전체 E2E, Kakao 실 console/redirect/hash, Play 서명키 일치: 미검증.
- [x] 2026-10-29 로컬 계정별 Hive namespace·백업 fingerprint 경계 및 세션 기반 progress sync 구현/회귀 완료. 단 게스트 데이터 자동 이관은 하지 않음.
- [ ] AdMob SDK, 광고 동의/보상 검증, Play Billing verify/restore/refund/expiry 및 광고 전면 제거: 미구현. 월 ₩1M은 목표이지 실적/보장이 아니다.
- [ ] CODEB 라이브 `/ads.txt`와 Naver 파일 반영 및 공개 배포: 미완료. `codeb.app` 확인 URL은 기존 검사에서 404였다.
- [ ] Search Console/Naver sitemap 재수집·인덱스 변화, AdSense 심사/Auto ads, 사업자/개인정보/약관 공개 내용 확정: 공개/소유자 상태가 필요.
- [ ] 기존 Naver/Tistory 임시저장 글 발행, 카페 가입/홍보글: 미완료. 자격증별 반복 대량 게시 자동화는 적용하지 않는다.

**현재 판정:** 앱 설치 패키지의 학습 자료 분리는 확인했고 로컬 D1/R2 번들을 최신 원본과 대조했다. 계정별 학습기록, 운영 인증/데이터 설정, 실제 원격 D1/R2 반영, 구매/광고와 공개 운영은 완료되지 않았다. CODEB 로컬 검토 build는 운영 공개를 뜻하지 않는다. SEASTAR/seastar.work/SGW는 별도 프로젝트로 이 체크리스트에서 제외한다.

## 2026-11-06 — 원격 서비스 제어와 차단 경계 재검증

- [x] 서비스 OFF 예외 목록을 명세대로 한정했다. 관리자 블로그 초안 조회/검토는 더 이상 control-plane 예외가 아니며, 인증 전 `503 service_disabled`를 받는다.
- [x] 예약 초안 생성은 시작 시 서비스 상태를 확인하고, 카탈로그/D1 대기 뒤 모델 호출 직전과 모델 응답 뒤에도 상태를 재확인한다. 저장 전 검사에서 OFF/오류면 검토용 콘텐츠 최종화를 시작하지 않는다. OFF 감지 후 `failClaim`은 생성 콘텐츠 없이 실패 상태만 D1에 기록해 진행 중인 claim을 정리할 수 있다. 최종화 쓰기 시작 뒤 OFF면 취소되지 않을 수 있고, OFF 동안 초안 API는 계속 차단된다. 이 경계는 `MC_boundary.cfg` 반례로 문서화했다.
- [x] 수정 전 회귀 재현 5건(예약 상태 무시 3개 경로, OFF 중 초안 저장, 관리자 초안 API 403 우회)을 기록하고, 수정 뒤 Worker 전체 44/44 통과.
- [x] TLA+ bounded safety: TLC 2026.11.03.180953, 정상 탐색의 마지막 실행은 1,345 generated / 336 distinct / depth 12; `TypeOK`와 7개 action property 통과. 버그 토글 `ScheduledStartGuard`, 보호 응답 sanity `SanityNeverAccepted`, 이미 시작된 검토용 콘텐츠 최종화 경계 `NoReviewFinalizeAfterShutdown`에서 각각 예상 반례 확인. 실패 상태 전용 `failClaim` 업데이트는 generated content가 없는 별도 `blocking` phase로 모델링했다. 상태 범위·코드 대응은 `formal/remote-service-control/`에 보관.
- [x] Flutter 전체 119/119, `dart analyze lib` 이슈 없음, R2 verifier tests 11/11 및 현 번들 검증 PASS (10 tracks, 193 exams, 16,653 questions, 3,609 R2 objects).
- [ ] 원격 Worker/D1 배포, 실제 Cron/OAuth/Access/refresh·만료 E2E, Play Billing 검증은 아직 미실행/미구현. 로컬 테스트와 TLC 결과는 운영 배포 증명이 아니다.

## 2026-10-29 — 사용자별 학습기록 격리·동기화 최신 검증

### 로컬 구현 및 검증

- [x] guest legacy box 보존, 인증 계정 ID SHA-256 namespace 분리, 계정 전환 때 화면 데이터 초기화와 generation guard 적용.
- [x] 세션 bearer token만 사용해 progress 동기화. Worker 저장 소유자는 검증한 session user ID이며 요청 본문의 소유자 값을 받지 않음.
- [x] 백업 export는 현재 namespace만 포함하며 다른 계정/게스트 fingerprint 복원을 거부.
- [x] 서버 전송은 `questionProgress`, `sessions`, `quizResults`만 포함. 문제 본문·정답·해설은 payload allowlist에서 제외. 기타 사용자 학습 데이터는 현재 계정별 로컬 저장만 됨.
- [x] Worker 요청은 실제 Content-Length와 chunked stream 모두 UTF-8 5 MiB로 제한. 정확히 5 MiB와 초과 입력 경계 회귀 포함.
- [x] TLA+ 정상 50,125 generated / 15,118 distinct / depth 18; 결함 토글과 도달성 sanity가 예상된 invariant counterexample을 반환. 세부 범위/코드 라인은 `formal/user-progress-sync/`.
- [x] Flutter 전체 테스트 100/100, 동기화/백업 집중 테스트 15/15, Worker 전체 테스트 35/35, 수정 관련 Dart 9개 파일 `dart analyze` 0 issues, 포맷 0 changed, Wrangler dry-run 성공. 출력과 범위 한계: `formal/user-progress-sync/evidence/verification.md`.
- [ ] `flutter analyze --no-pub` wrapper는 `Analyzing ...` 뒤 유휴 대기해 완료되지 않음. 직접 실행 `dart analyze lib` 전체 앱은 `No issues found!`; 관련 테스트 9개 파일과 여러 하위 디렉터리도 별도 분석 통과. Wrapper 미완료는 남기되 Dart 앱 전체 분석은 통과로 기록한다.

### 미완료 — 출시·운영 게이트

- [ ] 실제 Google OAuth/Cloudflare Access 환경 변수에 `REPLACE_WITH_...` placeholder가 남아 있다. Wrangler dry-run은 번들만 검증하며 원격 설정 검증은 아니다.
- [ ] 원격 D1 migration/Worker 배포 및 로그인·refresh·만료·계정 전환 실제 API E2E 미검증.
- [x] 원격 동기화에 SRS, score history, slide progress, exam registrations의 최소 필드가 포함된다. `wrongNotes`는 문제·정답·해설·개인 메모 때문에 원격 제외 상태를 유지한다.
- [ ] D1/R2 원격 자료 적용, 전체 endpoint 운영 검사, APK 빌드·Play 검증을 수행하지 않았다.
- [ ] 배포 게이트 5항목과 외부 공개는 미통과. Cloudflare/Kakao 로그인·권한·콘솔 설정·배포·외부 공개 변경 없음.



## 2026-10-29 — CODEB 검색·AdSense 경로 재점검

### 공개 응답 확인 (현재 측정)

| 호스트/경로 | 결과 | 메모 |
|---|---:|---|
| codeb.app/ | 200 HTML | 홈페이지 응답 |
| codeb.app/sitemap.xml | 200 XML | 31 URL, 최신 lastmod 2026-10-09; local source/build는 이후 42 URL |
| codeb.app/rss.xml | 200 XML | 2 items |
| codeb.app/robots.txt | 200 text/plain | 응답 정상 |
| codeb.app/ads.txt | 404 | 로컬 파일만 있고 라이브에 없음 |
| codeb.app/privacy/, /terms/ | 404 | AdSense/방문자 정보 공개 준비 미완료 |
| Naver 확인 HTML (codeb.app) | 404 | 소유확인 버튼 진행 전에 라이브 배포 필요 |
| todak.codeb.app/sitemap.xml, rss.xml, robots.txt | 200 text/html | sitemap/feed/robots 파일이 아닌 HTML fallback |
| todak.codeb.app/ads.txt, privacy/, terms/ | 200 | 해당 하위 도메인 공개 응답 |
| Naver 확인 후보 경로 (todak) | 200 text/html 일반 페이지 | 소유확인 콘텐츠를 제공하지 않는 fallback |

- [x] 공개 HTTP에서 root sitemap/RSS 및 두 호스트의 ads/legal 응답을 다시 읽었다.
- [x] 공개 검색 도구의 site 검색은 양 도메인 모두 결과 없음. 검색 인덱스의 확정 증거로 사용하지 않는다.
- [ ] Search Console/Naver Search Advisor 콘솔은 사용자 소유 브라우저 세션을 열지 않아 오늘 새로 확인하지 않음. 마지막 기록(2026-10-28): GSC sitemap 성공 31개, index 3/not-indexed 1/클릭 0; Naver codeb.app·todak.codeb.app 확인 대기.
- [ ] todak.codeb.app용 실제 sitemap/RSS/robots 및 Naver 확인 HTML이 루트에서 유효한 content-type/body로 응답하도록 별도 빌드/라우팅 정비.
- [ ] CODEB root ads.txt, privacy, terms, Naver verification HTML을 승인된 공개 배포로 반영하고 200/본문 검증. 현재 소유자 게시/재인증 게이트 전이므로 배포는 하지 않았다.
- [ ] Google/Naver 콘솔을 소유자 세션에서 다시 읽기 전용 확인한 후 sitemap 재수집 상태와 홈 색인 수를 기록.

범위: 공개 URL 조회와 로컬 소스 읽기만 했다. Search Console/Naver 로그인·권한·버튼, Cloudflare 설정/배포, 게시, 브라우저 세션 소유권은 변경하지 않았다. 상세 근거는 docs/HANDOFF.md의 같은 날짜 절과 E:\code-project\codeb\PROGRESS.md를 참조.

## 2026-10-29 — 안전한 진행도 동기화 최종 대조

- [x] 계정별 SRS, 정수 milli-point 점수 이력, 슬라이드 진행, 응시 등록/삭제를 snapshot과 Worker 저장 경계에 구현했다. `wrongNotes`의 문제/정답/해설/메모 원문은 계속 원격 제외다.
- [x] 응시등록 tombstone은 `{id: deletedAtMillis}` 버전으로 바꿨다. 삭제 시각 이하의 오래된 기기 사본은 막고, 같은 회차 재등록은 `updatedAt > deletedAt`일 때만 복원된다. 로컬 list tombstone은 읽을 때 현재 시각의 map으로 한 번 변환한다.
- [x] Flutter 전체 106/106, 동기화 관련 경계 12/12, Worker 전체 40/40 및 progress 단위 11/11, 전체 `dart analyze lib`·변경 파일 analyze 0 issues, 포맷 6 files/0 changed, Wrangler dry-run PASS, 정수 경계 검사 PASS.
- [x] `SafeCollections.tla` 정상 729 generated / 132 distinct / depth 11. slide/tombstone 결함 토글과 progress/registration restore 도달성 sanity가 각각 의도한 invariant 반례를 검출했다. 증거: `formal/user-progress-sync/evidence/safe-collections/`.
- [ ] dry-run 출력에는 OAuth/Access placeholder가 남아 있다. 원격 D1, Worker 배포, 실제 OAuth·2기기 sync·전체 API E2E, APK/Play 검증은 미실행이다. 따라서 배포 게이트/출시 봉인은 통과하지 않았다.

범위: 소스·로컬 회귀·정적 Worker 번들만 검증했다. Cloudflare/Kakao 로그인·권한·콘솔·배포·외부 공개는 바꾸지 않았으며 SEASTAR는 수정하지 않았다. 상세 범위/가정은 `formal/user-progress-sync/SCOPE.md`와 `CORRESPONDENCE.md`를 참조.

## 2026-10-29 — 모바일 실행 화면 및 CODEB 제품 페이지 반영

- [x] 2026-11-02 새 GISACLUB debug APK를 Android 14 AVD에서 실행해 1080×2400 화면 5장을 실제 저장했다. 사용자 데스크톱/브라우저/마우스는 제어하지 않았다.
- [x] 캡처 픽셀·크기·화면 내용과 WebP 변환의 픽셀 일치, CodeB alt/caption, 렌더 이미지를 대조했다. 사용자 데이터와 문제 원문은 노출하지 않았다.
- [x] CodeB 전체 테스트와 격리 build를 통과시키고 생성된 기사클럽 페이지/5개 이미지 참조를 확인했다.
- [ ] 라이브 게시·Cloudflare 설정·배포는 소유자 발급 draft-write/Access 자격증명과 휴대폰 재인증 게이트를 통과하기 전까지 미수행.
- [x] 결과·제약을 이 체크리스트, `docs/HANDOFF.md`, CodeB `PROGRESS.md`에 기록했다.

### 실행 증거 (2026-11-02)

- AVD: Android 14 / 1080×2400 physical / density 420; ADB는 별도 가상 기기에만 연결. AVD 네트워크 인터페이스가 내려가 있어 ADB reverse `tcp:8787`로 localhost Wrangler를 연결했다.
- 캡처 원본 PNG: `E:\gisaclub\_verify\mobile-capture-20261102\{onboarding,teacher-selection,exam-date,daily-goal,sign-in-setup}.png`. 각 1080×2400이며 CodeB WebP 5개와 RGB 픽셀 단위로 일치한다.
- APK: `flutter build apk --debug --no-pub --dart-define=API_BASE_URL=http://127.0.0.1:8787` 성공, SHA-256 `AB176C59C3D3412BDA45F70B4F09A29C563933E14CFD9C0133E9ADBCFE53A755`. HTTP 허용은 debug source set에만 있고 release/main에는 없다. `test/debug_network_policy_test.dart` 1/1 통과.
- 캡처: 학습 흐름 소개, 강사 선택, 시험일 설정, 하루 목표, 로그인 연결 준비. 운영 OAuth 로그인이 검증되지 않아 인증 뒤의 학습/문제 화면은 캡처하지 않았다. 서비스 상태 `200 enabled=true`는 로컬 Wrangler 검증값이며 운영 상태의 증거가 아니다.
- 운영자 복구 토큰 입력란이 있는 이전 `gisaclub-connection-state.webp`는 CodeB `manifest.json`에서 `rejected`, `usage.json`에서 `blocked` 처리했다. 새 build에 해당 화면이 포함되지 않은 것을 확인했다.
- CodeB `npm test` 43/43; `node --test tests/pages-round2.test.mjs` 8/8; 격리 build `_verify/gisaclub-mobile-capture-20261102-v2` 42 pages/42 sitemap URLs. 출력 검사에서 5개 이미지의 참조·파일·고지 문구를 확인했고, 운영자 복구 화면 및 로컬 소스 경로 노출은 0.
- 배포 판정 미통과: 원본과 `_verify`만 수정했다. `AGENT_GUIDE.md`의 소유자 draft-write/Cloudflare Access 자격증명과 휴대폰 재인증 없이 게시/배포하지 않았다.

- 결정 기록: 운영 Worker의 공개 상태 GET이 401이라 최신 앱은 fail-closed 점검 화면에 표시된다. 소스의 public control-plane route와 local Wrangler Worker는 정상(`200`, `enabled:true`)이다. 운영 배포 없이 local Worker를 연결한 최신 Android debug app에서 화면을 캡처하고 캡션에 개발 환경임을 명확히 한다. HTTP 허용은 `src/debug/AndroidManifest.xml`에만 적용하고 release/main manifest에는 적용하지 않는다. live Worker 및 CODEB 공개 배포는 변경하지 않는다.

### 2026-11-03 — 공개 검색·수익화 경로 재점검 (읽기 전용)

- [x] `codeb.app/sitemap.xml` HTTP 200 / XML / 31 URL 확인; 최신 `lastmod` 2026-10-09로 이전 기록과 동일.
- [x] `codeb.app/robots.txt` HTTP 200 / text/plain 확인; `/admin`, `/api/admin` 차단과 사이트맵 선언 확인.
- [x] `codeb.app/ads.txt`, `/privacy/`, `/terms/`, Naver 확인 HTML URL이 여전히 HTTP 404임을 확인.
- [x] `todak.codeb.app/sitemap.xml`과 `/robots.txt`가 HTTP 200이어도 `text/html`이며 루트 앱 HTML과 동일한 fallback 응답임을 확인. 유효한 수집 피드로 판정하지 않는다.
- [ ] 소유자 검토 필요: `todak` 호스트에서 실제 XML 사이트맵과 robots 텍스트를 제공하고 CODEB의 ads.txt·개인정보·약관·확인 파일 경로를 공개 원본에 반영할지 결정.
- [ ] Google Search Console / Naver Search Advisor의 현재 인증 상태·사이트맵 처리·홈 색인은 소유자 인증 콘솔에서 확인해야 한다. 사용자 브라우저 세션을 가져오거나 인증 절차를 우회하지 않아 이번에는 미확인.
- 외부 공개와 Cloudflare 설정은 변경하지 않았다. 배포 전에는 기존 draft-write/Cloudflare Access 자격증명 및 소유자 휴대폰 재인증 게이트를 통과해야 한다.

### 2026-11-04 — 상태 재확인

- [x] GISACLUB 핵심 소스는 10/29 이후 변경 없음; debug APK hash는 11/2 기록과 일치.
- [x] CodeB 회귀 43/43, GISACLUB debug network policy focused test 통과. Flutter 전체 suite는 미실행.
- [x] 공개 URL: main sitemap 200 XML/31 URLs; robots 200 text; ads.txt·privacy·terms·Naver verification HTML 404. todak sitemap/robots는 200 HTML fallback.
- [ ] 운영 `/v1/app/service-status` 401은 최신 기록상 유지되어 앱이 fail-closed 점검 화면을 표시한다. 실제 운영 OAuth·sync·스토어 릴리스는 미검증.
- [ ] 현재 Search Console/Naver 인증 콘솔의 색인·소유확인 데이터 미확인. 마지막 Search Console 숫자는 2026-10-28 스냅샷.
- [ ] 로컬 GISACLUB 소개 페이지 공개, Cloudflare 배포, ads/legal/verification 경로 게시 대기: draft-write/Access 및 휴대폰 재인증 게이트 필요.

### 2026-11-04 — CodeB 격리 검색 준비 빌드

- [x] CodeB 정적 빌드 `_verify/search-ads-readiness-20261104`: 42 pages/42 sitemap URLs.
- [x] SEO 검사 `seo_check.py`: 42 unique titles/descriptions, 15 dated URLs, RSS 2; `ALL PASS`.
- [x] 빌드 루트에 ads.txt·Naver 검증 HTML·XML sitemap·plain text robots 파일 존재를 확인.
- [ ] 라이브에서 해당 파일은 이전 점검상 404. [추정] 원인은 배포본 또는 호스트 라우팅일 수 있으며, 로컬 빌드만으로 확정하지 않았다.
- [ ] privacy/terms page 미생성. 회사·개인정보 담당자 연락처 및 약관 조건이 소유자 확인 대기라 추정 작성하지 않음.
- [ ] todak.codeb.app은 별도 호스트 소스/라우팅이 이 CodeB checkout에서 확인되지 않아 피드 라우팅 미수정.
- [ ] 콘솔 최신 확인과 라이브 배포는 미수행; `AGENT_GUIDE.md` 소유자 draft-write/Access + 휴대폰 재인증 게이트 적용.

### 2026-11-04 — 이전 빌드 대비 측정 개선

- [x] 비교 기록: 10/28 AdSense 검토 build 31 sitemap URLs/12 media/기사클럽 이미지 0 → 11/4 build 42 URLs/17 media/기사클럽 이미지 7. 공개 URL +11(+35.5%), 총 media +5(+41.7%); 10/28 42-URL media-review 대비 기사클럽 이미지는 2→7.
- [x] 최신 로컬 SEO 검사: 고유 제목 42/42, 설명 42/42, sitemap 42 URLs, validator ALL PASS.
- [ ] 홍보 페이지에 동영상 없음. 실제 화면은 가입 전 온보딩/준비 단계 5장과 문제 예시 2장뿐이며, OAuth 뒤 학습 화면·전체 이론/문제 풀이 기능을 증명하지 않는다.
- [ ] 라이브 노출/색인/수익 성과는 로컬 산출물 개선 수치로 추정하지 않는다. 운영 앱·결제·광고 보상·Play 출시 상태 미검증.

### 2026-11-06 — 공개 R62 대조 및 분리/병합 보류

- [x] 공개 `gisa/backup-r59` HEAD `3e1a2ad666b9334998efc872de6985e9764c7103` 확인; 로컬 `main` `c22faad`보다 9커밋 앞섬(로컬 전용 0).
- [x] 로컬 worktree 일반 상태 3,509 porcelain 항목, 미추적 파일을 펼친 상태 3,918 항목; `git diff --check` 통과.
- [x] upstream 변경과 로컬 변경이 겹치는 10개 경로를 식별했다. 관리자 flavor/AdMob/Remote Config와 로컬 Kakao/서비스제어/원격콘텐츠 변경의 통합은 별도 파일별 검토가 필요하다.
- [x] 기존 데이터 대조 기록의 설명 차이: 전기공사 14건, 전기산업 22건. 학습자료 본문은 열람/기록하지 않음.
- [ ] 데이터 정정의 권위 있는 원본과 서버 자료 갱신 방법 결정 전까지 `assets/data` 삭제/이동을 원격에 적용하지 않는다.
- [x] 관리자 진입 UI 노출 문제는 2026-11-06 최신 대조에서 해결된 상태로 확인했다: `lib/screens/settings_screen.dart:60-63`이 `AppConfig.isAdminApp` 조건으로 메뉴를 제한한다. 이전 항목은 당시 관찰 기록이다. 관리자 flavor 동작은 debug 산출물 생성으로 확인했지만 서버 권한 우회는 시험하지 않았다.
- [ ] Kakao native key는 `android/app/kakao.properties`가 없고 Gradle/Dart 기본값이 빈 문자열이다. 공개 앱키 입력 경로와 누락 시 release 차단을 정한 뒤 로그인 설정/콜백을 검증한다.
- [ ] 11/2 debug APK와 11/4 집중 테스트 기록은 기존 로컬 상태 기준이다. R62 병합본 전체 분석·테스트·빌드는 미실행.
- [ ] 이번 점검은 읽기 전용으로 종료: 커밋·푸시·배포 미수행. 구체적인 병합 결과와 데이터 보존 검증 전에는 완료/출시 판정하지 않는다.

### 2026-11-06 17:25 KST — 최신 로컬 구현/검증 상태

- [x] 설정 화면의 관리자 진입은 `lib/screens/settings_screen.dart:60-63`에서 `AppConfig.isAdminApp`일 때만 표시. `lib/services/app_config.dart:97-100`의 기본값은 `false`; 관리자 APK 빌드에는 `--dart-define=IS_ADMIN_APP=true`가 필요하다. UI 격리 확인이며 서버 권한 검증과는 별개다.
- [x] 사용자/관리자 debug APK 각각 생성: `app-user-debug.apk` SHA-256 `62B2245D0119D072E40890A7A21CB386AD00B6732BE6A8A91D0E5A8089619CC0`, `app-admin-debug.apk` SHA-256 `B3A67E758E88E1CE42838F144FD5B4A9CAB10A58DAC9A9EC29A4205865518A2F`.
- [x] APK archive path-name scan: `study/question/exam/assets/data` 패턴 파일 경로 0개. 사용자는 215,592,502 bytes debug APK이며 내부 미압축 합계 294,879,563 bytes; debug kernel 74,807,232 bytes 및 3 ABI native libraries 142,549,416 bytes가 큰 비중이다. 경로 이름 검사만으로 데이터 비포함을 증명하지 않으므로 REA/semantic inspection 및 release AAB 측정은 남아 있다.
- [x] Flutter 테스트 119/119, Dart 분석(`lib test`) 이슈 없음, Worker Node 테스트 42/42, format 검사 clean, `git diff --check` 통과. Wrangler dry-run만 성공; 라이브 배포 확인 아님.
- [ ] 마켓 릴리스는 미완료: 두 APK 모두 debug이고 release 서명/AAB·스토어 구매/복원·운영 OAuth/실 API E2E를 검증하지 않았다.
- [ ] Kakao 설정 파일 없음 및 key 기본값 공란. Worker의 Google OAuth/Cloudflare Access 값은 placeholder이므로 운영 인증 미완료.
- [ ] REA APK 역분석은 `REA_JADX_MCP_JAR` 누락으로 실행되지 않았다. 현재 APK hash는 파일 동일성 증거일 뿐 바이너리/Manifest 안전 검토 증거가 아니다.
- [ ] 현재 브랜치 `codex/gisaclub-r62-push`, HEAD `88fe28b`, 추적 변경 24개(이 체크리스트 수정 포함); `HANDOFF.md`는 미추적 파일이다. 이번 실행에서 원격 푸시나 배포는 하지 않았다. 기존 R62 데이터 차이와 원본 권한 판단은 계속 대기.

### 2026-11-10 11:58 KST — 최종 TLA 모델/증거 정합성 재점검

- [x] 11/6 18:06 KST에 추가된 `blocking`/`FinishBlockedStatus` 모델이 그보다 이른 정상 TLC 로그에 포함되지 않았던 증거 경로 불일치를 확인하고 현재 최종 model을 다시 체크했다.
- [x] 정상 `MC.cfg`: exit 0; `TypeOK` + 7 action properties 통과; 1,345 generated / 336 distinct / depth 12; `-coverage 1`.
- [x] 의도적 음성/도달성 구성: mutation `MC_bug.cfg` exit 13 (ScheduledStartGuard 반례); `MC_sanity.cfg` exit 12 (healthy protected response 도달); `MC_boundary.cfg` exit 12 (이미 시작된 콘텐츠 최종화의 취소 불가 경계); `MC_blockedstatus.cfg` exit 12 (ControlUnavailable 이후 SkipProvider가 status-only blocking phase에 도달). 각 TLC 로그는 `formal/remote-service-control/evidence/tlc-final-*/`에 저장했다. 네 trace Markdown은 Windows cp949 인코딩 문제를 우회해 UTF-8로 다시 생성했고 모두 비어 있지 않다.
- [x] `findings.json`가 최종 정상/action-property 로그와 각 최종 반례 로그를 참조하도록 갱신, `MC_blockedstatus` 예상 반례/재현 구성 추가. JSON Schema 2020-12 검증 통과. 대응검사 25 pointers / 3 files / 0 broken. 로컬 HTML 보고서도 최신 모델 검사 시각·경로와 일치시켰다.
- [x] 코드 테스트/빌드 로그와 소스 시각 대조: Worker 소스 17:32 KST 뒤 `green-tests.log` 17:39에 44/44; Flutter 소스 17:20와 17:22 user/admin debug APK 뒤 119/119 test 및 Dart 분석 clean 기록. R2 fixture 11/11/bundle PASS. 해당 제품 파일은 이번 검토 이후 변경 시각이 없으므로 테스트/빌드를 재실행하지 않았다.
- [ ] 모델은 한 요청/한 예약 슬롯, revision 0..2, DO 선형성 가정의 bounded safety다. 실제 DO/D1·다중 지역·제공자 호출 취소/영구 제거를 보증하지 않는다. TLA 통과를 운영 안전성 절대 보장으로 해석하지 않는다.
- [ ] 릴리스·운영 게이트는 그대로: Kakao/Google OAuth·Access placeholder 및 자격증명, 실제 OAuth/refresh/expiry E2E, release 서명/AAB·Play Billing, 원격 D1/R2·Worker 배포 미완료. 이번 실행은 로컬 formal evidence와 문서만 갱신했고 계정/설정/로그인/배포/푸시를 변경하지 않았다.
- [x] 예약 초안 OFF 경계 리뷰 후속: `backend/cloudflare/tests/service-control.test.js:115`의 `/v1/auth/google` 사례를 실제 핸들러 메서드(`POST`, `backend/cloudflare/src/index.js:156`)로 정정했다. `cd backend/cloudflare; node --test tests/service-control.test.js` — 9/9 통과. 전체 Worker/Flutter/APK 빌드는 이 후속 변경에서 다시 실행하지 않았다.

### 2026-11-10 16:08 KST — 로컬 Release 후보 빌드 및 출고 게이트

- [x] 사용자 범위 확인: 로컬 AAB/APK 후보까지만 생성한다. Play Console 업로드·제출, Cloudflare 운영 배포, 운영 계정/설정 변경 없음.
- [x] AAB `build/app/outputs/bundle/userRelease/app-user-release.aab`, 88,090,929 bytes, SHA-256 `6ABC3A6654C358BCCFADB996CA8342D8DA6B0A1DB77A81E6068221222B52AF3A`; arm64 APK `build/app/outputs/flutter-apk/app-user-release.apk`, 71,740,347 bytes, SHA-256 `553494CCE5EBC58BEA9CD38DB350FA5EF35DC32DA62E589C4D78B575A6A6E6A4`. `jarsigner`와 `apksigner` 서명검증 통과; 두 산출물 모두 로컬 keystore 인증서와 일치한다. Play 업로드 인증서와의 일치는 확인하지 않았다.
- [x] APK 메타데이터: `com.certstudytracker.study`, `versionName=1.0.0`, `versionCode=1`, minSdk 24 / targetSdk 36. 스토어 기존 versionCode와 설치·업데이트 경로는 확인되지 않았다.
- [x] 두 APK/AAB 아카이브 경로명에서 학습 데이터로 보이는 경로 0개. 경로명 검사만으로 비문자열 페이로드/실행 동작까지 증명하지 않는다.
- [x] `tool/audit/verify_learning_data.py`에 `LEARNING_DATA_DIR` 지원과 기존 `assets/data` 기본값 호환을 추가하고, `tool/audit/test_verify_learning_data.py`에 override/default 테스트 2개를 추가했다. 출시 점검은 분리된 `backend/data/study`를 자동 선택하고 Python UTF-8 출력을 고정한다. unittest 2/2, py_compile, diff 검증 통과.
- [x] 실제 로컬 분리 데이터 10 트랙/16,653문항의 V0–V7 위반 0건, 해설↔정답 대조 16,653/16,653. V8 실질 해설 10,432/16,653 (62.6%), 기존 해설부채 기준선 6,221건 유지. 원문 문항은 출력·기록하지 않았다.
- [x] 전체 `tool/audit/verify_release_ready.sh` 실행에서 데이터 검사, Dart 분석, Flutter 테스트 119/119, 사용자 앱 관리자 메뉴 분리 검사는 통과했다. 출시 차단은 단 하나: `android/app/src/main/AndroidManifest.xml:71`의 Google 공식 AdMob 테스트 앱 ID. 그러므로 현재 서명 산출물을 출고 승인으로 간주하지 않는다.
- [ ] Android 빌드 당시 `API_BASE_URL`, Google OAuth client ID 및 Kakao native/JavaScript 키 Dart define은 설정되지 않았다. 앱은 운영 백엔드/로그인을 검증하지 않은 로컬 서명 후보다. Cloudflare dry-run(88.21 KiB, gzip 22.21 KiB)은 통과했으나 `wrangler.toml`의 Google OAuth/Access 값은 placeholder이며 실제 배포는 하지 않았다.
- [ ] 게이트 1 환경 일치 FAIL. 게이트 2 전체 API 엔드포인트 목록·검증 범위 미완료. 게이트 3 OAuth 발급→전송→검증→갱신→만료 E2E 미검증. 게이트 4 프론트↔백 전체 필드 계약 미검증. 게이트 5 롤백 소스 후보 `gisa/backup-r59@3e1a2ad666b9334998efc872de6985e9764c7103` 확인; 운영 배포 ID는 없음.
- [ ] Play Billing은 `backend/cloudflare/src/billing.js:13`에서 503을 반환하는 미구현 상태다. Play listing/Data Safety·개인정보·광고 실설정·구매/복원·실기기 QA도 미완료. 스토어 등록 준비 완료/상용 출시로 판정하지 않는다.
- [x] 이전 중복 Gradle 시도에서 JVM native-memory mmap 부족(1.5 GB) 오류 로그가 생성됐으나 해당 임시 파일을 제거했다. 성공한 AAB/APK 해시와 서명은 별도 재확인했다.
- [x] 사용자 승인된 코드 푸시: 커밋 `c61cf8620a7e09c2a5a856ef574de45ac1266bca`를 `gisa/backup-r59`에 non-force fast-forward로 반영하고 푸시 후 원격 HEAD 일치 확인. 로컬 전용 HANDOFF/백업/소유 자료는 제외했다.
- [ ] 이 체크포인트의 라이브 운영 배포·스토어 업로드/제출은 하지 않았다. 로컬 후보의 재빌드·설치 QA 또는 운영 자격증명 기반 인증 검증은 별도 승인/환경 준비 후 수행한다.
