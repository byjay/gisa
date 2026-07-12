# MASTER_PLAN.md — Cert Study Tracker 절대 지시서 (바이블)

> **문서 지위: 최우선(1순위) 규범 문서.**
> 이 문서는 본 프로젝트의 모든 작업에 우선하는 **바이블**이다.
> 세션이 끊기거나, 컨텍스트가 초기화되거나, 어떤 인터럽트가 발생하더라도
> **작업 재개 시 반드시 이 문서를 가장 먼저 읽고, 여기 정의된 프로토콜대로만 행동한다.**
> 사용자의 명시적 지시 외에는 이 문서와 충돌하는 어떤 판단도 허용하지 않는다.

- 프로젝트: **Cert Study Tracker** (전기기사 자격증 학습 앱)
- 패키지: `com.certstudytracker.study` / 경로: `/home/user/flutter_app/`
- 문서 버전: **v2.0** (2026-02 자기검증 증보판 — v1.0 갭분석 오류 3건 정정) — 갱신 시 §9 변경이력에 기록

---

## §1. 오케스트레이터 페르소나 헌장 (PERSONA CHARTER)

### 1.1 정체성 선언
작업 주체는 단일 코더가 아니라 **오케스트레이터(Orchestrator)**로서 작동한다.
오케스트레이터는 직접 코드를 쓰기 전에 항상 **역할이 분리된 서브에이전트들을 지휘**하는
사고 구조를 취하며, 각 서브에이전트의 산출물을 검수한 뒤에만 다음 단계로 넘어간다.

### 1.2 서브에이전트 편성표 (매 태스크마다 이 순서로 지휘)

| # | 서브에이전트 | 책임 (Responsibility) | 산출물 | 완료 판정 기준 |
|---|---|---|---|---|
| A0 | **Inspector** (상태점검관) | 세션 시작/재개 시 `git log`, `git status`, 서버 상태, MASTER_PLAN.md §9 최신 항목 확인 | 현재 상태 보고 | 마지막 커밋·미커밋 변경·서버 생존 여부 3가지 확인 |
| A1 | **Researcher** (리서처) | 신규 기능 착수 전 web_search/crawler로 경쟁사·UX 베스트프랙티스 조사 | 리서치 노트(§4에 병합) | 최소 2개 출처, 실행 가능한 시사점 도출 |
| A2 | **Architect** (설계자) | 파일 배치, 데이터 모델, 위젯 분해, Provider 영향도 설계. §5 아키텍처 맵과 일관성 유지 | 구현 스펙(파일 목록+시그니처) | 신규/수정 파일 목록과 공개 API 시그니처 확정 |
| A3 | **Implementer** (구현자) | A2 스펙대로만 코드 작성. 임의 확장 금지. §3 코드 표준 준수 | Dart 코드 | 스펙의 모든 항목 구현, 스펙 외 변경 없음 |
| A4 | **Verifier** (검증관) | `flutter analyze` → `flutter build web --release` → 서빙 바이트 검증 | 빌드 로그 | analyze 0 issue + build 성공 + served size == local size |
| A5 | **Archivist** (기록관) | git commit(의미 있는 메시지) → ProjectBackup → **curl 다운로드 명령 제공** → §9 변경이력 갱신 | 커밋 해시, 백업 URL, curl 명령 | 사용자에게 curl 명령이 전달됨 |

### 1.3 매 턴 실행 프로토콜 (절대 순서 — 생략 금지)
```
[재개/시작] A0 Inspector: MASTER_PLAN.md §9 읽기 → git/서버 상태 확인
   ↓
[기획] A1 Researcher (신규 기능일 때) → A2 Architect: 스펙 작성 (TodoWrite로 태스크 등록)
   ↓
[구현] A3 Implementer: 코드 작성
   ↓
[검증] A4 Verifier: analyze → build → curl -s localhost:5060/main.dart.js | wc -c 대조
   ↓
[기록] A5 Archivist: commit → ProjectBackup → curl 다운로드 명령 제공 → §9 갱신
```

### 1.4 불변 규칙 (HARD RULES)
1. **모든 태스크 종료 시 반드시** 커밋 + ProjectBackup + curl 다운로드 명령 제공 (사용자 상시 요구사항).
2. 검증(A4) 실패 상태로 태스크를 완료 처리하지 않는다.
3. Flutter 3.35.4 / Dart 3.9.2 **버전 고정** — 업그레이드 금지.
4. 스펙에 없는 파일을 임의로 만들지 않는다. 만들 경우 §5 아키텍처 맵에 즉시 반영.
5. `print()` 금지 → `debugPrint` + `kDebugMode`; `withOpacity()` 금지 → `withValues(alpha:)`.
6. 인터럽트로 도구 호출이 끊겼으면, 재실행 전 **실제 파일/커밋 상태를 먼저 확인**한다.
7. 서버가 죽어 있으면 `flutter build web --release` 후 `python3 -m http.server 5060 --directory build/web --bind 0.0.0.0` 백그라운드 재기동.

---

## §2. 제품 비전

**"전기기사 수험생이 매일 열고 싶어지는 마법 학습 앱"**
- 핵심 루프(경쟁 우위 기준): **풀기 → 채점 → 해설 → 오답 자동 축적 → 복습** 이 끊기지 않아야 한다 (오르조 리서치 결론).
- 차별화 축: ① 완전 무료·오프라인(Hive 로컬) ② 게이미피케이션(XP/마법사 레벨/스트릭/배지) ③ 데이터 코칭(히트맵·주간 리포트·합격 예측).

---

## §3. 기술스택 인벤토리 (전량 고정 버전)

| 레이어 | 기술 | 버전 | 용도 |
|---|---|---|---|
| 프레임워크 | Flutter | **3.35.4 (고정)** | Web 프리뷰 + Android 타깃 |
| 언어 | Dart | **3.9.2 (고정)** | |
| 상태관리 | provider | 6.1.5+1 | `AppProvider` 단일 ChangeNotifier |
| 로컬 DB | hive / hive_flutter | 2.2.3 / 1.1.0 | exams·sessions·notes·quizResults 박스 |
| 경량 저장 | shared_preferences | 2.5.3 | 진행도/설정 (ProgressService 등) |
| 네트워크 | http | 1.5.0 | Cerebras AI 서비스 |
| 외부링크 | url_launcher | (설치본) | Qnet 배너 |
| 디자인 | Material 3 | 내장 | AppTheme 디자인 시스템 |
| 프리뷰 서버 | Python http.server | 3.x | 포트 5060, `build/web` 서빙 |
| 백업 | ProjectBackup 툴 | - | tar.gz + curl 다운로드 |

**디자인 토큰**: primary `#4F46E5`, accent `#7C3AED`, electric `#06B6D4`;
그라디언트 hero/electric/time-of-day(새벽·아침·오후·밤); 재사용 위젯 `SectionHeader`, `PremiumCard`, `IconBadge`, `PillBadge`.

**XP 시스템 공식(변경 금지)**: 학습 1분=2XP, 정답 1개=5XP, 레벨 임계 `(n-1)²×120`,
칭호 6단계(견습→수습→정식 Lv5→상급 Lv7→대마법사 Lv10→전설 Lv15).

---

## §4. 딥리서치 결과 (근거 자료)

### 4.1 경쟁사 분석
| 앱 | 강점 | 약점/기회 |
|---|---|---|
| **맞추다** | 프리미엄 전문가 해설, 오답노트 자동 생성, CBT 환경 재현, 45종 자격증 | 해설 유료(~18,000원) → 우리는 무료 해설로 대항 |
| **오르조** | AI 해설, 회차·과목별 풀이 | 3일 무료 후 유료 |
| **전구앱** | 전기기사 특화 기출 | 게이미피케이션 없음 |
| **다산패스** | 강의 연계 | 앱 UX 단순 |

### 4.2 앱 선택 5대 기준 (오르조 블로그 크롤링 결론 — 우리 앱의 채점표)
1. 회차별·과목별 풀이 지원
2. 자동채점 → 해설이 **자연스럽게 연결**
3. 오답노트 **자동 축적**
4. 북마크·단원별 복습·약점 확인
5. 무료/유료 범위·광고 체감

### 4.3 게이미피케이션 데이터 (Duolingo)
- 스트릭 도입으로 익일 리텐션 **12% → 55%**, 14일차 리텐션 +14%p.
- 시사점: 스트릭 시각화·상실 방지(streak freeze류)·일일 미션이 리텐션의 핵심 레버.

### 4.4 복습 알고리즘 (SM-2 / FSRS / Leitner — 2차 리서치)
- Anki계 SM-2: 초기 간격 1일→6일, easiness factor로 간격 증가. FSRS는 동일 기억률에서 복습량 20~30% 절감(GeekNews).
- 본 앱은 Leitner 6박스(0/1/2/4/8/16일)를 `flashcard_srs.dart`에 **이미 구현** — 충분하며 FSRS 전환은 비용 대비 효익 낮음(보류).

### 4.5 전기기사 시험 구조 (2차 리서치 — 나무위키/에듀윅/inup)
- 필기 5과목×20문항=100문항, 4지선다. **합격: 평균 60점 ∧ 과목별 40점(과락)**.
- 권장 학습 순서: 회로이론→제어공학→전력공학→KEC법규→전자기학→전기기기 (에듀윅). 비전공자는 전력공학 먼저(맞추다 블로그).
- → 본 앱의 과락 경보(`pass_prediction.dart` gwarak)는 이미 이 규칙을 반영. CBT 모드는 문항당 90초 페이스 유지.

---

## §5. 현재 아키텍처 맵 (2026-02 전수점검 기준, 46 dart 파일)

```
lib/
├─ main.dart                     # MainShell: 5탭 NavigationBar(홈/학습/시험/타이머/통계), IndexedStack
├─ models/models.dart
├─ providers/app_provider.dart   # 333줄. Hive 박스 4종 + 타이머 + 스트릭 + XP/레벨 게터
├─ theme/app_theme.dart          # 디자인 시스템 + timeGradient()
├─ services/ (1,950줄)
│  ├─ study_data.dart(866)       # 12개 JSON 자산 로더
│  ├─ progress_service.dart(261) # 문항별 진행/오답 (shared_preferences)
│  ├─ pass_prediction.dart(148)  # 합격 예측
│  ├─ cerebras_service.dart(102) # AI 해설 (외부 API)
│  ├─ flashcard_srs.dart(80) / dday_planner.dart(60) / score_history.dart(61) / slide_progress.dart(39)
├─ screens/
│  ├─ home_screen.dart           # timeGradient 헤더+스파클, 레벨 스트립, 일일미션, 오답복습 진입
│  ├─ exams_screen.dart          # Qnet 배너, D-Day 카드
│  ├─ timer_screen.dart          # 프리미엄 원형 타이머, XP 스낵바, 레벨업 팝업
│  ├─ stats_screen.dart          # 마법사 카드→주간리포트→히트맵→배지→목표→차트
│  └─ study/ (16 화면)           # 4탭 허브(기초/문제풀이/모의고사/이력) + quiz_play, smart_review 등
└─ widgets/ (15개)               # magic_effects, daily_mission_card, badge_collection,
                                 # level_up_dialog, study_heatmap, weekly_report_card 등
assets/data/ (12 JSON)           # exams.json(29회차·2,897문항: id/label/year/session/questions),
                                 # topic_freq, lessons, mnemonics, theory_slides, solution_recipes,
                                 # formula_guide, silgi, videos, study_plan, exam_info_2026, repeat_questions
```

**빌드/배포 상태 기준선**: analyze 0 issue, 커밋 `2da231f`, 서버 bash_f88df100(5060) 가동,
프리뷰 https://5060-ie9f8zla5o9s5maa1br5y-d0b9e1e2.sandbox.novita.ai

---

## §6. 갭 분석 v2.0 (자기검증 재채점 — v1.0 오류 정정)

> **Inspector 감사 결과**: v1.0의 ✗/△ 판정 3건이 실제 코드와 불일치했음. 근거 파일을 명기하여 재채점.

| 기준 | 실제 현재 상태 (근거) | 판정 | 대응 |
|---|---|---|---|
| 1. 회차별·과목별 풀이 | 회차 29개 + 과목별 빈출순/난이도순 카드 (study_screen `_freqCard`, kSubjects 5과목 균등 ~580문항) | ○ | 유지 |
| 2. 채점→해설 연결 | **해설 2,897/2,897 (100%) 로컬 보유**, 문항 내 RichSlideBody 해설 + 재회독 배너 | ○ | 유지 |
| 3. 오답노트 자동 축적 | ProgressService record + Leitner SRS(dueReviewQids) + SmartReview | ◎ | 유지 |
| 4. 북마크·약점 확인 | **북마크 이미 구현**(toggleBookmark + 퀴즈 AppBar 별 토글 + SmartReview 연동), 약점은 weakTopics/처방전 | ○ | 유지 |
| 5. 무료/광고 체감 | 완전 무료·무광고·오프라인 | ◎ (우위) | 유지 |
| 6. **스트릭 보호** (Duolingo) | 스트릭 계산만 있고(`streak` getter) 상실 방지 장치 없음 | ✗ **진짜 갭** | **T-4 (이번 턴)** |
| 7. **CBT 문항 그리드 네비게이터** (맞추다) | examMode에 타이머는 있으나 문항 점프 그리드 없음 | ✗ **진짜 갭** | **T-5 (이번 턴)** |
| 8. 온보딩 30분 루틴 (오르조) | 온보딩 전무 | ✗ | T-6 |

---

## §7. 로드맵 v2.0 + 태스크별 초세밀 구현 스펙

> 각 태스크는 §1.3 프로토콜(A0→A5)을 완주해야 완료다. 순서 변경은 사용자 지시로만 가능.
> ~~T-1(북마크·과목필터), T-2(해설루프), T-3(약점분석)~~ → **Inspector 감사 결과 기구현 확인, 폐기.**

### T-4. 스트릭 보호권 "마법 방패" (★★★ — Duolingo §4.3 직접 근거, 리텐션 핵심 레버)
- **A1 Researcher**: 완료. Duolingo streak freeze — 끊길 날 자동 소모로 스트릭 유지, 리텐션 +43%p 문맥.
- **A2 Architect 스펙 (정밀)**:
  - **저장소**: 기존 Hive `settings` 박스 재사용(신규 박스 금지). 키: `shieldCount`(int, 기본 0, 최대 2), `shieldLastEarnDay`(String 'yyyy-MM-dd' — 하루 1회 지급 가드), `shieldUsedDates`(List<String> — 방패로 보호된 날짜들).
  - **AppProvider 신규 API**:
    - `int shieldCount` 필드 + `_load()`에서 복원.
    - `bool get todayMissionsAllDone` — daily_mission_card.dart의 3개 조건(todayMinutes≥30 ∧ todayQuizSolved≥10 ∧ todayQuizCorrect≥5)과 **동일 공식** (단일 진실 원천을 Provider로 이동).
    - `void maybeEarnShield()` — 올클리어 ∧ 오늘 미지급 ∧ shieldCount<2 → +1, notifyListeners. 반환 bool(지급 여부)로 스낵바 트리거.
    - **스트릭 게터 수정**: 빈 날을 만나면 `shieldUsedDates` 포함 여부 확인 → 포함 시 연속으로 간주. `int get effectiveStreak`.
    - `void autoConsumeShield()` — 어제 학습 0분 ∧ 그제까지 스트릭 존재 ∧ shieldCount>0 ∧ 어제가 미보호 → 어제를 shieldUsedDates에 추가, shieldCount-1. `_load()` 말미에서 1회 호출.
  - **UI**: home_screen 스트릭 카드에 `🛡️×N` PillBadge; addQuizResult/stopTimer 직후 maybeEarnShield → 지급 시 "🛡️ 마법 방패 획득!" 스낵바.
- **완료 기준**: 하루 건너뛴 시나리오에서 방패 자동 소모 후 스트릭 유지(수동 데이터 조작 검증).

### T-5. CBT 문항 그리드 네비게이터 (★★★ — 맞추다 CBT 재현 갭)
- **A2 Architect 스펙 (정밀)**:
  - 신규 화면 금지 — **quiz_play_screen.dart의 examMode에 내장**(기존 채점 `_finish()` 파이프라인 100% 재사용).
  - AppBar actions에 그리드 아이콘(`Icons.grid_view_rounded`) → `showModalBottomSheet`로 문항 번호판:
    - GridView 8열, 셀 상태 3색: 답함(primary 채움)/현재(테두리 강조)/안 푼 문항(회색), 북마크 문항 우상단 ⭐ 도트.
    - 셀 탭 → `setState(_idx = i)` + 시트 닫기 + `_syncBookmark()` 재호출.
    - 시트 상단: "푼 문항 N/총 M" + 남은 시간 표시(examMode).
  - 하단 내비 행에 "번호판" 버튼 추가(연습 모드에서도 사용 가능).
- **완료 기준**: 100문항 모의고사에서 임의 문항 점프·복귀 정상, 채점 결과 불변.

### T-6. 온보딩 30분 루틴 (★ — 오르조 시사점, 다음 턴)
- 첫 실행 감지(settings 박스 `onboarded_v1`) → 3페이지(목표 시험일→일일 목표→핵심 루프 안내). PageView + 기존 exam/goal setter 재사용.

### T-7. 백로그 (사용자 승인 후 착수)
- FSRS 전환 검토(§4.4 보류 사유 재평가), 위클리 리그(익명 랭킹), 푸시 리마인더(Android 빌드 시).

---

## §8. 업데이트 전략 & 검증 프로토콜

1. **브랜치 전략**: main 단일 브랜치, 태스크당 1커밋 원칙(메시지: `T-n: <요약>`).
2. **검증 체인(A4 표준)**:
   ```bash
   cd /home/user/flutter_app && flutter analyze          # 0 issue 필수
   flutter build web --release                            # ✓ Built 확인
   curl -s localhost:5060/main.dart.js | wc -c            # == build/web/main.dart.js 크기
   ```
3. **서버 재기동(죽었을 때만)**: `lsof -ti:5060 | xargs -r kill -9; python3 -m http.server 5060 --directory build/web --bind 0.0.0.0 &`
4. **백업 체인(A5 표준)**: commit → ProjectBackup → 사용자에게 `curl -L -o cert_study_tracker.tar.gz "<URL>"` 명령 제공 → §9 갱신.
5. **데이터 마이그레이션**: Hive 박스 스키마 변경 시 반드시 null-safe 읽기(`as T?`)로 하위호환.

---

## §9. 변경이력 (Archivist가 매 태스크 후 갱신 — 재개 시 여기부터 읽기)

| 일자 | 커밋 | 내용 | 백업 |
|---|---|---|---|
| R17 | 6e66783 | 시험 화면 리디자인 (Qnet 배너, D-Day 카드) | cyaEYYvv |
| R18 | 08ea4d1 | UX 전면 개편: 5탭 내비, 학습 4탭 허브, 타이머/통계 리디자인 | - |
| R19 | 367a5a2 | XP/마법사 레벨, 스파클, 일일 미션, 스태거 애니메이션 | - |
| R20 | 0ab0b91 | XP 피드백, 배지 컬렉션(10종) | dIE7s8Mg |
| R21 | a6a983d | 레벨업 파티클 팝업 | a3o8pt1V |
| R22 | 2da231f | 시간대별 그라디언트, 12주 히트맵, 주간 성장 리포트 | E7gTXo6v |
| R23 | b5805e4 | **MASTER_PLAN.md 바이블 제정** — 오케스트레이터 헌장·갭분석·로드맵 | Roas0KcH |
| R24 | 2cdc24c | **바이블 v2.0** (갭분석 자기검증 정정 + 리서치 §4.4/4.5 증보) + **T-4 마법 방패**(streak freeze: 자동소모·미션 올클리어 지급) + **T-5 CBT 문항 번호판**(그리드 점프, 답함/현재/북마크 표시) + **T-6 프리미엄 온보딩**(시험일→목표→루프, 3페이지) | 9PFMBP56 |
| R25 | b290165 | **T-7a 위클리 마법 리그** — 주차 시드 결정적 가상 라이벌 9명, 요일 경과에 따라 라이벌 XP 성장(긴장감 유발), 승급권 Top3 배지, 다음 순위까지 필요 XP 코칭, `weekXp` 게터 신설 | q51NAiZV |
| R26 | c8df58e | **T-7a2 홈 리그 미니 스트립** — 홈 미션 카드 아래 순위/승급권/XP 요약 + 탭 시 통계 탭 이동, `leagueStanding()` 공용 로직 추출, `rivalsFor()` static 화 | P79ErOlT |
| R27 | e4d9bef | **레이아웃 전수감사 1차** — ① 홈 우선순위 재배치(긴급 복습을 목표 스트립 직하로 승격: 망각곡선상 최우선 행동이 미션·리그보다 위) ② DueReviewCard/DueFlashcardCard 디자인 시스템 위반 교정(수제 Material→PremiumCard+IconBadge+PillBadge, 하드코딩 grey→onSurfaceVariant 다크모드 대응) ③ FadeSlideIn 스태거 인덱스 1~7 순차 정렬 | 52UgkiIl |
| R28 | (이번) | **레이아웃 전수감사 2차 (§9.1 전항목 완료)** — ① 레거시 `Card(` 전수 스캔(3건) 후 교정: dday_plan_card 성장그래프→PremiumCard+IconBadge(electric), study_screen _cbtTrendCard→PremiumCard(padding zero)+collapsedShape 보정 ② quiz_play_screen 옵션 타일 Card는 **의도적 예외로 판정**(정답/오답/선택 상태색 동적 변경 인터랙티브 타일, scheme 기반이라 다크모드 안전) ③ stats_screen 리그(경쟁)↔리포트(성찰) 사이 SectionHeader 2종 삽입(⚔️ 이번 주 경쟁 / 📊 나의 성장 기록) ④ 신규 유저 빈 상태 검증: Due 카드 2종 count==0이면 shrink, 예측카드 진단유도 분기, 리그 0XP 안전 — 과밀 없음 | (커밋 후 기입) |

**§9.1 레이아웃 감사 잔여 항목 — R28에서 전항목 완료 ✅**
- [x] exams_screen(744줄)·study_screen(812줄) 배치 감사 — exams 빈상태 OK(L203), study는 _cbtTrendCard 레거시 Card 교정 완료
- [x] quiz_play_screen(903줄) 시각 위계 — 옵션 타일 Card는 상태색(정답녹/오답빨/선택 primary) 의도적 예외로 판정·문서화
- [x] 온보딩→홈 첫 진입 빈 상태 — Due카드 2종 shrink, 예측카드 진단유도 분기, 리그 0XP 안전. 과밀 없음
- [x] stats_screen 리그/리포트 시각 구분 — SectionHeader(⚔️ 경쟁 / 📊 성찰) 삽입 완료
- [x] 레거시 `Card(` 전수 스캔 — 주요 표면(홈/통계/학습허브/DDay카드) 0건. 심층 서브화면 27건은 **전역 CardThemeData(L159, rMd·테두리·elevation0 동일 적용)를 상속하므로 위반 아님으로 판정** — 차이는 softShadow뿐, 시각 일관성 유지됨. quiz 옵션 타일 1건은 상태색 인터랙티브 예외

| R29 | 49209ab | 신규 프로젝트(중·고 교과앱) 작업지시서 NEW_PROJECT_WORKORDER.md 제정 — 별도 세션에서 진행, 본 앱은 전기기사 유지 | WgILqwiZ |
| R30 | (이번) | **안정화 스윕** — ① JSON 12종 파싱+2,897문항 무결성 게이트 통과(answer/옵션/해설 위반 0) ② 위험 패턴 전수 그리프: firstWhere 2건(try-catch/orElse 기보호 확인), 0-분모 나눗셈 14건(전부 가드 확인), `.first` 접근(정적 리스트/isEmpty 선행 확인) ③ 유일 실결함 home_screen `e.name[0]` 빈 문자열 크래시 가능성 → `isEmpty ? '?'` 가드 추가 ④ analyze 0 + release build + 서빙 바이트 일치(3,534,878) | (커밋 후 기입) |

> **다음 착수**: Android APK 릴리즈 빌드 (패키지명 일치 검증 → flutter_signing_tool).
