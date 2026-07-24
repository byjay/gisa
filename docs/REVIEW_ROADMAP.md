# 수정 우선순위 로드맵 — 전수 검사 결과 (2026 리뷰)

> 원칙: 각 배치는 최대 3~5개 파일, 10개 함수 이내. 배치 완료마다 `flutter analyze && flutter test` 통과 필수.
> 실제 수정은 사용자 승인 후 착수한다.

---

## P0 — 치명적 (사용자 체감 고장 / 크래시 가능)

### 배치 P0-A: 학습 시간 유실 + 튜터 선택 불능
**파일**: `lib/providers/app_provider.dart` (2개 함수)
1. **[B1] 타이머 벽시계 기반 전환** — `startTimer` / `stopTimer` / tick 콜백
   - 현상: `elapsedSeconds++` 틱 카운트 방식 → 백그라운드/화면꺼짐/웹 탭 스로틀 시 학습 시간 과소 기록.
   - 수정: `elapsedSeconds = DateTime.now().difference(timerStart!).inSeconds`로 매 틱 재계산. Timer는 UI 갱신 트리거로만 사용.
   - 회귀 테스트: T4 (fake clock 주입 가능하도록 `now` 함수 파라미터화 — 기본값 `DateTime.now`).
2. **[B2] `setSelectedTutor` 화이트리스트 수정**
   - 현상: `{'soyeon','harin','jiyoon'}`에 `'volt'` 누락 → 기본 튜터로 복귀 불가, UI 무음 실패.
   - 수정: 하드코딩 셋 제거, `kTutorPersonas`(tutor_persona.dart)의 id 목록으로 검증. 단일 진실 원천화.
   - 회귀 테스트: T3.

### 배치 P0-B: 손상 데이터 크래시 방어
**파일**: `lib/providers/app_provider.dart` (4개 getter/함수)
3. **[B9] 비안전 캐스트 제거** — `_load()`의 quizResults 정렬, `todayQuizSolved`, `todayQuizCorrect`, `weekXp`
   - 현상: `r['date'] as String` — 백업 복원 등으로 date 누락 레코드 유입 시 홈 화면 즉시 크래시.
   - 수정: `(r['date'] as String? ?? '')` 패턴 통일. 빈 문자열 레코드는 집계에서 자연 제외됨.
   - 회귀 테스트: T6 (손상 백업 복원 후 `_load()` 무크래시).

---

## P1 — 높음 (정합성 / 미정의 동작)

### 배치 P1-A: 스케줄 레이스 + 위조 일정 방어
**파일**: `lib/providers/app_provider.dart`, `lib/services/qnet_schedule_service.dart` (3개 함수)
4. **[R2] `refreshSchedule` 요청 세대 토큰**
   - 수정: `int _scheduleGen = 0;` 진입 시 `final gen = ++_scheduleGen;`, 응답 반영 직전 `if (gen != _scheduleGen) return;`.
   - 회귀 테스트: T8.
5. **[S2] 파싱 결과 연도 검증** — `_parseScheduleTable`
   - 수정: 추출 날짜가 `현재년도-1 ~ 현재년도+2` 범위 밖이면 해당 회차 폐기. 전체 폐기 시 asset 폴백 경로로 자연 진입.
   - 회귀 테스트: T5.

### 배치 P1-B: dispose 안티패턴 + 채점 로직 추출
**파일**: `lib/screens/study/quiz_play_screen.dart`, 신규 `lib/services/quiz_grader.dart` (3개 함수)
6. **[B7] dispose 내 `context.read` 제거**
   - 수정: `initState`에서 `_app = context.read<AppProvider>();` 필드 캡처, dispose는 필드 사용. try-catch 제거.
7. **[T10] 채점 순수 함수 추출** — `_finish()` 상단 채점 루프 → `QuizGrader.grade(questions, picked)` (입력: 문항+선택, 출력: correct/subjectTotal/subjectCorrect/wrongList 레코드).
   - `_finish()`는 결과를 받아 저장·연출만 담당. 단위 테스트 T10 신설.

---

## P2 — 중간 (원자성 / 신뢰성)

### 배치 P2-A: 백업·방패 원자성
**파일**: `lib/services/backup_service.dart`, `lib/providers/app_provider.dart` (3개 함수)
8. **[B6] `importAll` 복원 전 스냅샷**
   - 수정: 각 박스 clear 전 `box.toMap()` 스냅샷 보관 → put 루프 예외 시 스냅샷 롤백 후 실패 반환.
   - 회귀 테스트: T7.
9. **[B5] `_autoConsumeShield` 원자화**
   - 수정: `await`를 붙이고 두 put을 `_settingsBox.putAll({...})` 1회 호출로 병합 (`init()` 경로에서 async 허용됨 — `_load`를 통해 호출되므로 `_load`를 Future로 승격하거나 unawaited putAll로 최소화). 가장 보수적 선택: `putAll` 병합만 적용(호출 시그니처 불변).

### 배치 P2-B: 보안 하드닝
**파일**: `lib/providers/app_provider.dart`, `lib/services/cerebras_service.dart` + 빌드 스크립트 (2개 함수)
10. **[S3] 관리자 비밀번호 해시 비교** — 평문 상수 대신 SHA-256 해시 상수 저장, `verifyAdminPassword`는 입력 해시 비교 (crypto 패키지 기존 의존성 활용).
11. **[S1] 릴리스 빌드 가드** — 빌드 스크립트/CI에 `--dart-define=CEREBRAS_API_KEY`와 `flutter build apk --release` 동시 사용 시 실패하는 사전 검사 추가. 코드 측: `assert(!kReleaseMode || !_developmentAiEnabled)` 성격의 런타임 가드 1줄.

---

## P3 — 경미 (테스트 부채 / 보류 항목)

### 배치 P3-A: 회귀 테스트 신설
**파일**: `test/app_provider_test.dart`(신규), `test/qnet_schedule_service_test.dart`(신규)
12. T1(streak), T2(XP/레벨), T9(방패 지급 규칙) 단위 테스트.
13. `widget_test.dart` placeholder를 최소 스모크 테스트(온보딩 화면 렌더)로 교체.

### 명시적 보류 (수정하지 않기로 결정)
- **[B3] `_load()` 전량 재로드**: 현 데이터 규모(개인 학습 기록)에서 병목 미증명. 수정 시 캐시 무효화 버그 위험 > 이득. 사용자 데이터가 세션 1만 건을 넘는 시나리오가 확인되면 재검토.
- **God Provider 분할**: 화면 수십 개의 결합 해체 비용 대비 현 시점 이득 없음. 신규 도메인 추가 시 새 Provider로 만드는 "동결-신규분리" 정책으로 대체 (CLAUDE.md 참조).
- **싱글턴 → DI 전환**: 기존 테스트가 실 Hive로 이미 작동 중. 신규 서비스부터 생성자 주입 허용 형태로만 적용.

---

## 실행 순서 요약

| 순서 | 배치 | 파일 수 | 함수 수 | 예상 회귀 위험 |
|---|---|---|---|---|
| 1 | P0-A | 1 | 2 | 낮음 |
| 2 | P0-B | 1 | 4 | 매우 낮음 |
| 3 | P1-A | 2 | 3 | 낮음 |
| 4 | P1-B | 2 | 2+1신규 | 중간 (quiz 화면) |
| 5 | P2-A | 2 | 3 | 낮음 |
| 6 | P2-B | 2 | 2 | 매우 낮음 |
| 7 | P3-A | 2(신규) | — | 없음 |

각 배치 완료 조건: `flutter analyze` 0건 + `flutter test` 전체 통과 + 해당 배치 회귀 테스트 신규 통과.
