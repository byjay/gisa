# 🛡️ Gisaclub 슈퍼 관리자 모드 설정 가이드

## 1. 개요

관리자 모드는 **Google 계정 로그인 + 이메일 일치**로만 진입합니다.
PIN·하드코딩 비밀번호를 사용하지 않습니다.

- **관리자 이메일**: `designssir@gmail.com`
- 앱에는 이메일 평문이 아니라 **SHA-256 해시**만 내장됩니다.
  - 현재 해시: `b530074caab8e9989e1a9cf22bb4ef46b3e385c49e229fc21a2f82221b176c0c`
- 관리자 계정을 바꾸려면 새 해시를 계산해 교체하거나 빌드시 주입합니다.
  ```bash
  # Dart 콘솔:
  #   AdminService.emailHashOf("new-admin@gmail.com")
  # 또는 Python:
  python3 -c "import hashlib; print(hashlib.sha256('new-admin@gmail.com'.encode()).hexdigest())"
  # 빌드 주입:
  flutter build apk --release --dart-define=GISACLUB_ADMIN_EMAIL_HASH=<새해시>
  ```

## 2. 진입 방법

1. 설정 화면 → **관리자 → 슈퍼 관리자 모드**
2. **Google 계정으로 로그인** 버튼 탭
3. `designssir@gmail.com` 로 로그인 (휴대폰 2단계 인증 통과)
4. 이메일이 일치하면 관리자 대시보드가 열리고, **모든 학습 기능이 무제한 해금**됩니다.
   - 다른 계정으로 로그인하면 즉시 거부되고 로그아웃됩니다.

## 3. 보안 설계 (2단계)

### 지금(빠른 버전) — 현재 구현
- Google Sign-In → 앱이 이메일 해시를 비교 → 관리자 오버라이드 활성.
- PIN 추측이 불가능하고, 공격자는 **실제 구글 자격증명 + 휴대폰 2단계 인증**을
  모두 확보해야 합니다. 개인/소규모 앱에는 충분히 안전합니다.
- ⚠️ 한계: 앱 내부의 이메일 비교(`if email == admin`)는 이론상 APK를 변조하면
  우회 가능합니다. 그래서 아래 "제대로 된 버전"을 서버에 준비해 두었습니다.

### 제대로 된 버전(여유 있을 때) — 서버 판정
- Cloudflare Worker `/v1/admin/login` 이 관리자 이메일을 **서버에서** 검증하고
  관리자 토큰을 발급합니다(`backend/cloudflare/src/admin.js`).
- 서버 자원(타 사용자 데이터, 관리자 AI 크레딧)에 접근하려면 이 서버 토큰이
  반드시 필요합니다. 즉 앱을 뜯어고쳐도 서버 승인 없이는 서버 권한이 안 열립니다.
- 로컬 오버라이드 = "운영자 본인 기기 UX 게이트", 서버 토큰 = "진짜 권한".

## 4. ⚠️ Google Sign-In 이 실제로 동작하려면 (필수 설정)

현재 앱 코드는 준비됐지만, **Google 로그인이 실제 기기에서 동작하려면
Google Cloud/Firebase OAuth 설정이 필요**합니다. 미설정 시 로그인 버튼을 누르면
"오류가 발생했습니다"로 안내됩니다(앱은 정상 동작).

### Android 설정
1. [Google Cloud Console](https://console.cloud.google.com/) 또는
   [Firebase Console](https://console.firebase.google.com/) 에서 프로젝트 생성
2. **OAuth 동의 화면** 구성(외부/테스트 → 테스트 사용자에 `designssir@gmail.com` 추가)
3. **Android OAuth 클라이언트 ID** 생성:
   - 패키지명: `com.certstudytracker.study`
   - SHA-1 지문 등록: `keytool -list -v -keystore android/release-key.jks` 로 확인
4. `google-services.json` 다운로드 → `android/app/google-services.json` 에 배치
5. (권장) Firebase 사용 시 `android/build.gradle` + `android/app/build.gradle` 에
   google-services 플러그인 추가

### Web 설정(선택 — 웹 프리뷰에서 관리자 테스트 시)
1. **Web OAuth 클라이언트 ID** 생성
2. `web/index.html` `<head>` 에 메타 태그 추가:
   ```html
   <meta name="google-signin-client_id" content="YOUR_WEB_CLIENT_ID.apps.googleusercontent.com">
   ```

> 참고: 이 설정 없이도 앱 전체(학습·문제풀이·AI BYOK 등)는 정상 동작합니다.
> Google 로그인은 **관리자 진입에만** 쓰이므로, 관리자 기능이 급하지 않다면
> 나중에 설정해도 됩니다.

## 5. 관리자 대시보드에서 할 수 있는 것

| 섹션 | 기능 |
|---|---|
| **운영 요약** | 학습시간·풀이수·정답률·연속학습·레벨·완료세션 통계 |
| **콘텐츠·기능 관리** | 종목/과목 노출, 이론/문제/CBT/암기/AI 기능 토글 |
| **구독·권한** | 프리미엄 30일 부여 / 무료 초기화 (시연·검수용) |
| **AI 튜터 설정** | 관리자 키 상태 확인(오버라이드 시 무제한) |
| **앱 자동 업데이트** | 새 버전 확인 + 원버튼 업데이트 실행 |
| **시스템 진단** | 로컬 오류 로그 조회/복사/삭제 |
| **보안** | 로그인된 관리자 계정, 이메일 해시 교체 방법 |

## 6. AI 튜터 관리자 무제한 (테스트 기간 잠금 해제)

- 일반 사용자: 본인 Cerebras 무료 키(BYOK) 입력 또는 무료 5회/일.
- **관리자**: `--dart-define=CEREBRAS_ADMIN_KEY=<키>` 로 빌드하면, 관리자 세션에서는
  사용자 키 없이도 이 키로 **AI가 무제한** 동작합니다(오버라이드).
  ```bash
  flutter build apk --release \
    --dart-define=CEREBRAS_ADMIN_KEY=<운영자_Cerebras_키> \
    --dart-define=GISACLUB_ADMIN_EMAIL_HASH=<관리자_이메일_해시>
  ```
- 이렇게 하면 "테스트 기간엔 기능이 잠겨 운영자인 내가 못 푼다"는 문제가
  구조적으로 해결됩니다 — 관리자는 로그인만 하면 전 기능이 열립니다.
