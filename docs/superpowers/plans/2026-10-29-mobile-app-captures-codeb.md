# 모바일 실행 화면 CodeB 반영 계획

> 실행 방식: 사용자가 “계속해”, “완료해”, “질문 없이”라고 이미 지시했으므로 현재 세션에서 직접 수행한다.

**목표:** 최신 GISACLUB Android 개발 빌드의 실제 AVD 화면을 물리 해상도에 맞춰 새로 캡처하고 CODEB 기사클럽 제품 페이지의 이미지와 로컬 검토 빌드를 갱신한다.

**범위:** `E:\gisaclub` Flutter 개발 빌드, 로컬 Android AVD/ADB, `E:\code-project\codeb` 제품 데이터·이미지·회귀 테스트·격리 build.

**제약:** 사용자 데스크톱/브라우저/마우스는 제어하지 않는다. 개인/시험 원문·정답·해설·개인정보가 보이는 화면은 캡처하지 않는다. CodeB live publish, Cloudflare 설정·배포는 하지 않는다. 제품 페이지에 실제 개발/비공개 상태를 표시한다.

## 작업

1. 실제 GISACLUB source entry, Android package, AVD resolution, CodeB media/render/test contract를 읽는다.
2. 최신 Flutter development APK를 만들고 emulator 전용 AVD에서 실행한다. ADB physical size/density를 읽고 runtime 화면을 이미지로 pull한다.
3. 결과 이미지 해상도와 화면 내용을 확인한 뒤 CodeB `data/products.json`의 경로·captured date·alt/caption을 맞추고 `#problem`/`#screens` 렌더를 검증한다.
4. CodeB 회귀 전체와 분리 출력 build를 실행한다. APK build 실패, emulator 부팅 실패, OCR/시각 검토 실패가 있으면 그대로 기록하며 기존 이미지를 성공으로 가장하지 않는다.
5. A→E 반대 관점 검토 후 `HANDOFF.md`와 `SEPARATION_CHECKLIST.md`에 증거·한계·게시 게이트를 갱신한다.

**완료 기준:** 최신 빌드 실행 증거, 실제 AVD 물리 크기의 새 화면 파일, CodeB 데이터와 생성 HTML의 이미지/alt/caption 일치, 전체 CodeB test/build pass. 라이브 게시 완료는 별도 소유자 재인증 게이트가 열려야만 가능하다.

### 실행 중 결정 기록

- 공개 Worker의 service status `GET` 응답은 401이므로 현재 앱이 점검 화면에 멈춘다. 소스 `isControlPlane`은 해당 경로를 공개로 처리하고 local Wrangler Worker에서는 `200 enabled:true`가 확인됐다.
- 운영 스위치를 우회/변경하지 않기 위해 local Wrangler Worker와 Android debug source-set만 사용한다. `src/main` 및 release에는 cleartext 허용이 없고, 캡션에 로컬 개발 상태를 적는다.

### 실행 결과 (2026-11-02 KST)

- [x] 최신 debug APK를 Android 14 AVD에서 실행하고 1080×2400, density 420에서 실제 화면 5장을 저장했다: onboarding intro, tutor selection, exam date, daily goal, login readiness. PNG 원본은 `E:\gisaclub\_verify\mobile-capture-20261102`에 보존.
- [x] APK `flutter build apk --debug --no-pub --dart-define=API_BASE_URL=http://127.0.0.1:8787` 성공. AVD 네트워크 미연결은 ADB reverse와 local Wrangler로 처리; 운영 Worker를 변경/우회하지 않았다. 이전 APK의 Flutter kernel-load failure는 새 빌드에서 재현되지 않았다.
- [x] 실제 화면을 손대지 않고 lossless WebP로 변환했으며 PNG/WebP 크기와 각 RGB pixel을 대조했다. 캡처 APK SHA-256: `AB176C59C3D3412BDA45F70B4F09A29C563933E14CFD9C0133E9ADBCFE53A755`.
- [x] CodeB 제품 JSON·manifest·usage 정책과 화면 소개 copy, alt/caption, captured date, OG/Twitter/SoftwareApplication preview를 갱신했다. 운영자 복구 폼 캡처는 `rejected`/`blocked`하고 새 output에서 누락됨을 확인했다.
- [x] TDD: 새 5-image/media/rejection/assertion 회귀를 먼저 RED로 확인한 뒤 콘텐츠·렌더를 반영해 통과시켰다. `node --test tests/pages-round2.test.mjs` 8/8, 전체 `npm test` 43/43.
- [x] isolated CodeB build: `node build/build.mjs --out _verify/gisaclub-mobile-capture-20261102-v2` → 42 pages / 42 sitemap URLs. Output URL/asset/alt/caption/login disclosure/SEO date을 확인하고 local source path 및 operator recovery image가 없음을 검사.
- [x] A→E: A source/runtime/build; B skeptical media/security review; C approved screen set/limitations; D reverse trace APK→PNG→lossless WebP→manifest+product data→generated page; E tests/build/static artifact review. 중요한 동시성·수익 산술 변화가 없는 정적 마케팅 자산 작업이므로 TLA+/Lean 모델은 해당 없음.
- [ ] Live CodeB publish/Cloudflare deployment/Search Console resubmit는 미수행. `AGENT_GUIDE.md`에 따른 owner-issued draft-write/Access credentials + owner phone re-auth 필요. OAuth 운영 로그인 확인과 인증된 학습/문제 화면 캡처도 후속 과제.

결과물은 개발 중 앱의 실제 온보딩·로그인 준비 화면을 보여 준다. 일반 공개 앱, 운영 로그인 또는 문제풀이 사용 가능 상태를 주장하지 않는다.
