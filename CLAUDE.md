# CLAUDE.md — Cert Study Tracker (볼트쌤) 프로젝트 룰

> 2026 전수 검사에서 도출된 코딩 컨벤션·금지 패턴·의존성 원칙.
> 이 파일의 규칙은 신규 코드에 즉시 적용하고, 기존 코드는 로드맵(docs/REVIEW_ROADMAP.md) 순서로만 소급 수정한다.

## 0. 환경 (변경 금지)
- Flutter 3.35.4 / Dart 3.9.2 고정. `flutter upgrade` 금지.
- 저장소: Hive(문서형) + shared_preferences(경량 키값). Firebase 미사용 (로컬 우선 앱).
- 상태관리: Provider 단일. 추가 상태관리 라이브러리 도입 금지.

## 1. 상태 관리 원칙
- **AppProvider 동결 정책**: `AppProvider`에 새 도메인(필드 그룹 3개 이상 + 전용 저장 박스)을 추가하지 않는다. 신규 도메인은 별도 `ChangeNotifier` + `MultiProvider` 등록으로 분리한다.
- Provider 메서드에서 데이터 변경 후 뷰 갱신은 `notifyListeners()` 1회로 끝낸다. `_load()` 같은 전량 재로드 함수를 새로 만들지 않는다 (기존 `_load()`는 보류 항목 — 확장 금지).
- 위젯에서는 `context.select`로 필요한 필드만 구독한다. `Consumer<AppProvider>` 전체 구독은 화면 루트에서만 허용.

## 2. 금지 패턴 (발견 즉시 수정 대상)
| # | 금지 | 대체 |
|---|---|---|
| 1 | `dispose()` 안에서 `context.read`/`Provider.of` | `initState`에서 필드로 캡처 후 사용 |
| 2 | 틱 카운트로 경과 시간 측정 (`elapsed++`) | 시작 시각 저장 후 `DateTime.now().difference()` 재계산 |
| 3 | Hive/Map 값의 비안전 캐스트 `x as String` | `x as String? ?? 기본값` 또는 `is` 검사 |
| 4 | `catch (_) {}` 무음 삼킴 (UI 경로) | `OperationResult` 반환 또는 SnackBar로 사용자 통지. 무음 허용은 "폴백이 이미 준비된 비필수 경로"(예: 프록시 순차 시도)에 한하며 주석으로 사유 명기 |
| 5 | ID/키 화이트리스트 하드코딩 중복 | 단일 진실 원천(예: `kTutorPersonas`)에서 파생 |
| 6 | `print()` | `kDebugMode` 가드 + `debugPrint` |
| 7 | `withOpacity()` | `withValues(alpha:)` |
| 8 | async 함수 내 fire-and-forget `box.put(...)` 나열 | `await box.putAll({...})`로 원자화 |
| 9 | 릴리스 빌드에 `--dart-define=CEREBRAS_API_KEY` 전달 | 개발 실행(run) 전용. 릴리스는 키 없이 빌드 |
| 10 | 위조 가능 외부 데이터(크롤링 HTML) 무검증 반영 | 파싱 결과에 범위 검증(날짜 연도 등) 후 반영, 실패 시 번들 asset 폴백 |

## 3. 비동기·동시성 규칙
- 화면 상태 변경 전 `if (!mounted) return;` 필수 (await 이후 모든 setState/Navigator/ScaffoldMessenger).
- 최신 요청만 반영해야 하는 refresh 계열 함수는 **세대 토큰 패턴** 사용:
  ```dart
  int _gen = 0;
  Future<void> refresh() async {
    final gen = ++_gen;
    final data = await fetch();
    if (gen != _gen) return; // 뒤늦은 응답 폐기
    ...
  }
  ```
- `unawaited()`는 실패해도 앱 기능에 영향 없는 백그라운드 작업에만 허용하며, 내부에서 자체 예외 처리를 완결해야 한다.
- `Timer.periodic`을 만드는 모든 State는 `dispose`에서 `cancel()` 필수 (현행 3곳 모두 준수 — 유지).

## 4. 데이터 계층 규칙
- Hive 박스 목록의 단일 진실 원천은 `BackupService._boxNames`. **새 박스를 열면 반드시 이 목록에 추가**한다 (누락 시 백업에서 빠져 데이터 유실).
- 저장 스키마 변경 시 `BackupService.schemaVersion` 증가 + 마이그레이션 분기 작성.
- 복원(import) 계열 작업은 "검증 → 스냅샷 → 쓰기 → 실패 시 롤백" 순서를 지킨다. clear 후 put 도중 실패로 데이터가 반파되는 코드는 금지.
- Hive에 커스텀 TypeAdapter를 도입하지 않는다 (Map 직렬화 유지 — 백업 JSON 호환성).

## 5. 네트워크 규칙
- 모든 HTTP 요청에 `.timeout()` 필수 (현행: 크롤링 12s, AI 90s — 유지).
- 외부 API 오류는 `CerebrasException`처럼 **사용자 언어의 메시지를 가진 도메인 예외**로 변환해 던진다. 원시 예외를 UI까지 흘리지 않는다.
- CORS 프록시는 폴백 체인으로만 사용하고, 최종 폴백은 항상 번들 asset이어야 한다 (오프라인에서도 화면이 비지 않게).
- API 키·시크릿은 `String.fromEnvironment`로만 주입. 소스·Hive·SharedPreferences에 키를 기록하는 코드는 금지.

## 6. 보안 규칙
- 비밀번호·PIN 류는 평문 상수 비교 금지 — 해시 상수 비교 (crypto/sha256).
- `ENABLE_DEV_AI=true`는 개발 실행 전용. 릴리스 아티팩트에 포함 여부를 빌드 전 검사한다.
- 크롤링 파싱 결과는 신뢰 불가 입력으로 취급: 날짜는 연도 범위 검증, 문자열은 길이 상한.

## 7. 테스트 규칙
- 새 서비스/집계 로직은 **순수 함수로 추출 후 단위 테스트 동반** (예: 채점은 `QuizGrader.grade`).
- 시간 의존 로직(streak, SRS, 방패)은 `DateTime Function() now` 주입 가능 시그니처로 작성해 fake clock 테스트를 허용한다.
- 데이터 무결성 테스트(`question_data_integrity_test.dart`)는 종목 추가 시 반드시 갱신. asset 누락 경고가 테스트 로그에 남으면 pubspec/asset 정리 전까지 머지 금지.
- 배치 머지 조건: `flutter analyze` 0건 + `flutter test` 전체 통과.

## 8. UI 규칙
- 화면 루트에 `SafeArea` 필수. `debugShowCheckedModeBanner: false` 유지.
- 실패 시 사용자 피드백 없는 조용한 no-op 금지 — 최소 SnackBar. (예: 선택이 거부되면 거부됐다고 알린다.)
- 애니메이션은 `reduceMotion` 설정을 존중한다 (`MediaQuery.disableAnimations` 경유 — 현행 유지).
- 텍스트는 `textScaleFactor` 배율에서 1.6배까지 오버플로 없이 렌더되어야 한다.

## 9. 의존성 원칙
- 신규 패키지 추가 전 확인: (1) Web 플랫폼 지원, (2) Dart 3.9.2 호환, (3) 유지보수 활성.
- 버전은 caret(^) 대신 고정 버전 우선 (현행 pubspec 스타일 유지).
- `flutter pub outdated`의 메이저 업그레이드는 수행하지 않는다 (환경 버전 락).
- services → providers 방향 의존만 허용. services가 providers를 import하는 역방향 의존 금지.
- screens 간 상호 import 금지. 공유 로직은 services/widgets로 내린다.
