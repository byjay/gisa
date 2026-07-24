# 수정 우선순위 로드맵 R2 — 2차 전수 검사 결과

> 1차 로드맵(`REVIEW_ROADMAP.md`)의 P0~P3-A는 구현·검증 완료됨(flutter analyze 0건, flutter test 76/76).
> 본 문서는 2차 검사에서 확정된 신규 항목만 다룬다.
> 원칙: 배치당 최대 3~5개 파일, 10개 함수 이내. 배치 완료마다 `flutter analyze && flutter test` 통과 필수.
> 실제 수정은 사용자 승인 후 착수한다.

---

## P1 — 확정 버그 (실측 확인)

### 배치 R2-P1: mounted 누락 + 무음 실패 사용자 피드백
**파일**: `lib/screens/study/visual_repeat_screen.dart`, `lib/screens/exams_screen.dart` (2개 함수)

1. **[R2-B1] `_markSeen()` mounted 가드 누락**
   - 위치: `visual_repeat_screen.dart:59-70`
   - 현상: `await ProgressService.instance.recordExposure(...)` 완료 후 `setState()` 호출 전 `mounted` 체크 없음. 화면 이탈 직후 예외 발생 가능(`setState() called after dispose()`).
   - 수정: `if (!mounted) return;` 추가 (CLAUDE.md 규칙3 패턴 그대로 적용).
   - 회귀 테스트: 위젯 테스트로 dispose 후 pending Future 완료 시나리오 재현은 비용 대비 낮음 — 코드 리뷰로 대체하고 `flutter analyze` 통과만 확인(정적으로 검증 가능한 단순 가드 추가이므로 별도 유닛 테스트 불필요).

2. **[R2-S1] `_launch()` 무음 실패 → 사용자 피드백**
   - 위치: `exams_screen.dart:180-184`
   - 현상: 큐넷 원문 링크가 안 열려도 사용자에게 아무 신호 없음(CLAUDE.md 규칙4 위반: 사용자 액션 직결 경로의 무음 실패).
   - 수정: `catch (_) {}` → 실패 시 `ScaffoldMessenger`로 "링크를 열 수 없습니다" SnackBar.
   - 회귀 테스트 불필요(순수 UI 피드백 추가, 로직 변경 없음).

---

## P2 — 테스트 부채 (핵심 로직 미검증)

### 배치 R2-P2: SRS 순수 함수 추출 + 단위 테스트
**파일**: `lib/services/progress_service.dart`, 신규 `lib/services/srs_calculator.dart`, 신규 `test/srs_calculator_test.dart` (3개 파일, 2개 함수)

3. **[R2-T1] `record()` 내 SRS box 계산 로직 추출**
   - 현재: `progress_service.dart:34-61`의 `record()`가 Hive I/O와 box 증감·`nextDue` 계산을 한 함수에서 처리.
   - 수정: `QuizGrader` 패턴과 동일하게 순수 함수 추출.
     ```dart
     class SrsCalculator {
       static ({int box, DateTime nextDue}) nextState({
         required int currentBox,
         required bool correct,
         required DateTime now,
       }) { ... }
     }
     ```
   - `record()`는 계산 결과를 받아 Hive에 쓰기만 담당.
   - 단위 테스트: 정답 시 box+1(최대 4), 오답 시 box=0, 각 box별 `nextDue` 간격(0/1/3/7/16일) 정확성, fake `now` 주입으로 날짜 경계 테스트.

---

## P3 — 경미 (문서 정정 + 저위험 정리)

4. **[R2-DOC1] `CLAUDE.md` §3 오기 정정**
   - "Timer.periodic을 만드는 모든 State는 dispose에서 cancel() 필수 (현행 3곳 모두 준수)" → 실측 4곳(app_provider, quiz_play_screen, cbt_simulator_screen, tutor_avatar)으로 정정.

5. **[R2-P3, 보류 권장] `exams_screen.dart` 새로고침 중복 호출 방지**
   - IconButton과 RefreshIndicator 두 진입점 모두 연타 가드 없음. `refreshSchedule`의 세대 토큰이 데이터 정합성은 보장하므로 **기능 결함 아님, 네트워크 낭비만 존재**. 사용자 체감 영향 낮아 이번 배치에서는 보류. 재검토 조건: 큐넷 서버 rate-limit 이슈 실사례 발생 시.

6. **[R2-P3, 보류 권장] 관리자 비밀번호 brute-force 방지 없음**
   - 통제 범위가 로컬 과목 활성화 토글로 한정됨을 실측 확인(`admin_settings_screen.dart`). 오프라인 개인 학습 앱의 위협 모델상 우선순위 낮음. 재검토 조건: 관리자 화면 통제 범위가 향후 확장(예: 결제·계정 정보 포함)될 경우.

---

## 미해결 [Uncertain] 항목 — 후속 조사 필요

- `study_data.dart`(24건), `exam_info_screen.dart`(16건), `exams_screen.dart`(15건), `progress_service.dart`(13건)의 null-assertion(`!`) 개별 안전성 — `formula_calculators.dart`처럼 전수 교차 매칭 미실행. 실제 크래시 가능성 여부 미확정.
- `context.watch`/`Provider.of(listen:true)` 사용 18개 화면이 CLAUDE.md 규칙1("화면 루트에서만 허용")을 실제로 준수하는지 — 위젯 트리 depth 개별 미확인.
- `late` 변수 23개 중 `app_provider.dart`, `cerebras_service.dart`, `persistent_nav.dart`(initState 없는 파일)의 초기화 순서 안전성 — 개별 미검증.

---

## 실행 순서 요약

| 순서 | 배치 | 파일 수 | 함수 수 | 예상 회귀 위험 |
|---|---|---|---|---|
| 1 | R2-P1 | 2 | 2 | 매우 낮음 |
| 2 | R2-P2 | 3(1신규) | 2+1신규 | 낮음 |
| 3 | R2-DOC1 | 1(문서) | — | 없음 |

배치 3(R2-P3 항목 2건)은 보류 권장 — 재검토 조건 충족 전까지 미착수.
각 배치 완료 조건: `flutter analyze` 0건 + `flutter test` 전체 통과 + 해당 배치 회귀 테스트 신규 통과.
